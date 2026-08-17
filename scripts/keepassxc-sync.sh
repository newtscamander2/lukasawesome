#!/usr/bin/env bash
# Keep the KeePassXC database in step with Proton Drive, both ways.
#
#   keepassxc-sync.sh init          first time on a machine: seed the baseline
#   keepassxc-sync.sh               one sync run (what the timer calls)
#   keepassxc-sync.sh status        what state the sync is in
#   keepassxc-sync.sh allow-delete  let a refused deletion through, deliberately
#
# Why bisync and not the rclone mount: a mount makes the database a network
# file. Lose the connection and you lose your passwords; a VFS layer that
# fumbles an atomic save corrupts them. Bisync keeps a real file on local disk
# and reconciles it with the remote afterwards, so KeePassXC only ever writes to
# a local file and you can open it on a train.
#
# THE DATABASE MUST NEVER REACH GIT. It lives in ~/KeePassXC, which is outside
# every repository, and *.kdbx is in this repo's .gitignore as a second line of
# defence. Nothing in this script writes into a repository.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

REMOTE_NAME="$(cfg KEEPASS_REMOTE protondrive)"
LOCAL_DIR="$(cfg KEEPASS_LOCAL_DIR "$HOME/KeePassXC")"
REMOTE_DIR="${REMOTE_NAME}:$(cfg KEEPASS_REMOTE_DIR KeePassXC)"
# Overwritten and deleted versions land here rather than vanishing. For a
# password database this is the difference between "a sync went wrong" and "my
# passwords are gone", so it is not optional.
BACKUP_LOCAL="$(cfg KEEPASS_BACKUP_DIR "$HOME/.local/share/keepassxc-backups/replaced")"
BACKUP_REMOTE="${REMOTE_NAME}:KeePassXC-replaced"
FILTERS="${XDG_CONFIG_HOME:-$HOME/.config}/rclone/keepassxc-sync.filters"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/keepassxc-sync.log"
# When the last sync actually succeeded, written by every successful run
# whoever started it. systemd's own timestamps only cover runs it started.
STAMP="${XDG_STATE_HOME:-$HOME/.local/state}/keepassxc-sync.last"

command -v rclone >/dev/null 2>&1 || { err "rclone is not installed."; exit 1; }

# --- flags shared by every run ------------------------------------------------
# --check-access      refuse to sync unless RCLONE_TEST is present on BOTH sides.
#                     If the remote is unreachable or a directory is empty for
#                     the wrong reason, bisync stops instead of "helpfully"
#                     propagating the emptiness.
# --max-delete 0      refuse to delete anything, ever. You do not delete this
#                     file in normal use, so any deletion is a bug or an
#                     accident, and it should stop the sync rather than travel.
# --conflict-resolve none / --conflict-loser num
#                     when both sides changed, keep BOTH, numbered. Never pick a
#                     winner automatically: the loser of an automatic choice is
#                     the password you added on the other machine.
# --compare size,modtime,checksum
#                     Proton Drive's modtimes are not always trustworthy; the
#                     checksum is what settles it.
# --resilient/--recover  survive an interrupted run without demanding --resync.
bisync_flags=(
    --compare size,modtime,checksum
    --slow-hash-sync-only
    --resilient
    --recover
    --conflict-resolve none
    --conflict-loser num
    --conflict-suffix conflict
    --max-delete 0
    --check-access
    --create-empty-src-dirs
    --filters-file "$FILTERS"
    --backup-dir1 "$BACKUP_LOCAL"
    --backup-dir2 "$BACKUP_REMOTE"
    --log-level INFO
    --log-file "$LOG"
)

write_filters() {
    run mkdir -p "$(dirname "$FILTERS")"
    [ "$DRY_RUN" = "1" ] && return 0
    cat > "$FILTERS" <<'FILTERS'
# KeePassXC writes a .lock file next to the database while it is open. Syncing
# it would make the database look "already open by another user" on the other
# machine, which KeePassXC refuses to touch.
- *.lock
- *.kdbx.lock
FILTERS
    ok "filters at $FILTERS"
}

ensure_layout() {
    run mkdir -p "$LOCAL_DIR" "$BACKUP_LOCAL" "$(dirname "$LOG")"
    [ "$DRY_RUN" = "1" ] || chmod 700 "$LOCAL_DIR" "$BACKUP_LOCAL"

    # The marker --check-access looks for, on both sides.
    if [ "$DRY_RUN" != "1" ] && [ ! -f "$LOCAL_DIR/RCLONE_TEST" ]; then
        printf 'marker for rclone bisync --check-access; do not delete\n' \
            > "$LOCAL_DIR/RCLONE_TEST"
    fi
    run rclone mkdir "$REMOTE_DIR"
    if [ "$DRY_RUN" != "1" ] && ! rclone lsf "$REMOTE_DIR/RCLONE_TEST" >/dev/null 2>&1; then
        run rclone copy "$LOCAL_DIR/RCLONE_TEST" "$REMOTE_DIR/"
    fi
}

cmd_init() {
    log "Seeding the sync baseline"
    write_filters
    ensure_layout

    local dbs; dbs=$(find "$LOCAL_DIR" -maxdepth 1 -name '*.kdbx' | wc -l)
    if [ "$dbs" -eq 0 ]; then
        err "No .kdbx in $LOCAL_DIR — move your database there first."
        exit 1
    fi

    log "Dry run first (nothing is changed):"
    if ! rclone bisync "$LOCAL_DIR" "$REMOTE_DIR" "${bisync_flags[@]}" \
            --resync --resync-mode path1 --dry-run; then
        err "The dry run failed — not touching anything. See $LOG"
        exit 1
    fi

    if [ "$(ask_yn 'Seed from the LOCAL copy and overwrite the remote?' y)" != "yes" ]; then
        warn "Stopped. Nothing was changed."
        exit 0
    fi
    # --resync-mode path1: the local copy is the truth for the baseline. Anything
    # the remote had that differs is not deleted -- it goes to --backup-dir2.
    run rclone bisync "$LOCAL_DIR" "$REMOTE_DIR" "${bisync_flags[@]}" \
        --resync --resync-mode path1
    ok "Baseline established. Later runs sync both ways."
}

cmd_sync() {
    write_filters >/dev/null
    ensure_layout >/dev/null
    if rclone bisync "$LOCAL_DIR" "$REMOTE_DIR" "${bisync_flags[@]}"; then
        # Record it ourselves rather than relying on systemd's timestamps: those
        # only move when the TIMER runs the unit, so a sync you started by hand
        # left "last run" showing something older and looked like it had not
        # worked.
        date +%s > "$STAMP"
        # Say so when a human is watching. Silent under the timer, or every
        # fifteen minutes would be journal noise for a non-event.
        [ -t 1 ] && ok "synced at $(date '+%H:%M:%S')"
        return 0
    fi

    # --max-delete 0 does not merely skip a deletion: it aborts, and it keeps
    # aborting on every later run until someone decides. That is the right
    # trade for a password database -- but a sync that has quietly stopped is
    # exactly the failure this whole thing exists to prevent, so it has to be
    # impossible to miss.
    local status="failed"
    if tail -40 "$LOG" 2>/dev/null | grep -q "too many deletes"; then
        status="blocked by a deletion"
        err "The sync is BLOCKED and will stay blocked until you decide."
        err "Something was deleted, and this refuses to propagate a deletion of"
        err "your password database on its own."
        echo >&2
        log "See what it wants to delete:"
        echo "   bash $0 status" >&2
        log "If the deletion is intended (you really did remove a file):"
        echo "   bash $0 allow-delete" >&2
    else
        err "The sync failed. Last lines of $LOG:"
        tail -5 "$LOG" 2>/dev/null | sed 's/^/     /' >&2
    fi

    # A desktop notification too: the journal is not somewhere you look.
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "KeePassXC sync $status" \
            "Your password database is not syncing. Run: keepassxc-sync.sh status" \
            2>/dev/null || true
    fi
    return 1
}

cmd_allow_delete() {
    # The deliberate way past --max-delete 0. Shows what will go, asks, and
    # keeps a copy in the backup directory regardless.
    log "These deletions are currently being refused:"
    rclone bisync "$LOCAL_DIR" "$REMOTE_DIR" "${bisync_flags[@]}" \
        --dry-run --force 2>&1 | grep -iE "delete|would" | sed 's/^/   /' || true
    echo
    warn "Anything deleted is copied to the backup directories first:"
    warn "   local:  $BACKUP_LOCAL"
    warn "   remote: $BACKUP_REMOTE"
    if [ "$(ask_yn 'Allow these deletions to sync?' n)" != "yes" ]; then
        warn "Stopped. The sync stays blocked, and nothing was deleted."
        exit 0
    fi
    run rclone bisync "$LOCAL_DIR" "$REMOTE_DIR" "${bisync_flags[@]}" --force
    ok "Deletions applied. Normal syncing resumes."
}

cmd_status() {
    # The question this is really asked to answer is "is my database safe right
    # now" -- so lead with that, and put the listings underneath for when the
    # answer is no.
    local db name lsize lmod rline rsize rmod
    db="$(find "$LOCAL_DIR" -maxdepth 1 -name '*.kdbx' | head -1)"
    if [ -n "$db" ]; then
        name="$(basename "$db")"
        lsize="$(stat -c %s "$db")"
        lmod="$(stat -c '%y' "$db" | cut -d. -f1)"
        printf '   %-12s %s\n' "database" "$name"
        printf '   %-12s %s bytes, changed %s\n' "local" "$lsize" "$lmod"

        rline="$(rclone lsl "$REMOTE_DIR/$name" 2>/dev/null | head -1)"
        if [ -z "$rline" ]; then
            err "not on Proton Drive at all — the sync has never succeeded"
        else
            rsize="$(awk '{print $1}' <<<"$rline")"
            rmod="$(awk '{print $2" "$3}' <<<"$rline" | cut -d. -f1)"
            printf '   %-12s %s bytes, changed %s\n' "Proton Drive" "$rsize" "$rmod"
            if [ "$lsize" = "$rsize" ]; then
                ok "in sync — both sides are the same file"
            else
                warn "the two sides DIFFER — the next run will reconcile them"
            fi
        fi
    else
        err "no .kdbx in $LOCAL_DIR"
    fi

    # The answer to "how stale might Proton Drive be right now". Read from our
    # own stamp file, so a sync you ran by hand counts exactly like one the
    # timer ran.
    if [ -s "$STAMP" ]; then
        local last ago_s ago
        last="$(cat "$STAMP")"
        ago_s=$(( $(date +%s) - last ))
        if   ((ago_s < 90));    then ago="${ago_s}s ago"
        elif ((ago_s < 5400));  then ago="$((ago_s / 60)) min ago"
        elif ((ago_s < 172800)); then ago="$((ago_s / 3600))h ago"
        else ago="$((ago_s / 86400))d ago"; fi
        printf '   %-12s %s  (%s)\n' "last synced" \
            "$(date -d "@$last" '+%Y-%m-%d %H:%M:%S')" "$ago"
    else
        printf '   %-12s %s\n' "last synced" "never recorded — run: kpsync sync"
    fi
    printf '   %-12s %s\n' "next run" \
        "$(systemctl --user list-timers keepassxc-sync --no-pager 2>/dev/null | awk 'NR==2{print $3" "$4}')"
    echo

    log "local:  $LOCAL_DIR"
    ls -la "$LOCAL_DIR" 2>/dev/null | sed 's/^/   /'
    echo
    log "remote: $REMOTE_DIR"
    rclone lsl "$REMOTE_DIR" 2>&1 | sed 's/^/   /'
    echo
    # Conflicts are named ..conflict1, ..conflict2 by --conflict-loser num.
    local conflicts
    conflicts=$(find "$LOCAL_DIR" -name '*conflict*' 2>/dev/null | wc -l)
    if [ "$conflicts" -gt 0 ]; then
        warn "$conflicts conflict file(s) — both versions were kept:"
        find "$LOCAL_DIR" -name '*conflict*' | sed 's/^/   /'
        warn "Open each in KeePassXC, merge what you need, then delete the extras."
    else
        ok "no conflicts"
    fi
    echo
    log "timer:"
    systemctl --user list-timers keepassxc-sync --no-pager 2>/dev/null | sed 's/^/   /'
    log "last run: journalctl --user -u keepassxc-sync -n 20"
    log "full log: $LOG"
}

case "${1:-sync}" in
    init)         cmd_init ;;
    sync)         cmd_sync ;;
    status)       cmd_status ;;
    allow-delete) cmd_allow_delete ;;
    *)  err "Unknown command '$1' (init | sync | status | allow-delete)"; exit 1 ;;
esac
