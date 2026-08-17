#!/usr/bin/env bash
#
# setup-timeshift.sh — configure Timeshift for automatic BTRFS snapshots on a laptop.
#
# What this does:
#   1. Switches Timeshift to BTRFS mode (atomic, sub-second snapshots) and enables
#      boot/daily/weekly schedules with sane retention counts.
#   2. Replaces Timeshift's cron-based scheduling with systemd timers that
#        - catch up after the laptop was suspended or powered off (Persistent=true), and
#        - block suspend/shutdown while a snapshot is running (systemd-inhibit).
#   3. Takes a first snapshot so you can confirm it works.
#
# Safe to re-run. Run with: sudo ./setup-timeshift.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Tunables — edit these, then re-run the script to apply changes.
# ---------------------------------------------------------------------------

# Snapshot /home (the @home subvolume) alongside the system?
# Backup and restore are separate flags in Timeshift, so including @home in
# snapshots does NOT mean a system restore reverts your home directory --
# that stays an explicit choice, controlled by INCLUDE_HOME_ON_RESTORE below.
INCLUDE_HOME=true

# Roll @home back too when restoring a snapshot? Leave this false: you almost
# always want to repair the system without reverting documents. Individual files
# are still recoverable by browsing the snapshot read-only (see notes at the end).
INCLUDE_HOME_ON_RESTORE=false

# Which schedule levels to enable, and how many of each to keep.
SCHED_BOOT=true;     COUNT_BOOT=5
SCHED_DAILY=true;    COUNT_DAILY=7
SCHED_WEEKLY=true;   COUNT_WEEKLY=4
SCHED_MONTHLY=false; COUNT_MONTHLY=2
SCHED_HOURLY=false;  COUNT_HOURLY=6

# Take one snapshot at the end so you can verify the setup works.
TAKE_FIRST_SNAPSHOT=true

# ---------------------------------------------------------------------------

CONFIG=/etc/timeshift/timeshift.json
UNIT_DIR=/etc/systemd/system

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '\033[34m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m ✓\033[0m %s\n' "$*"; }

# --- preflight -------------------------------------------------------------

[[ $EUID -eq 0 ]] || die "must run as root: sudo $0"

command -v timeshift >/dev/null || die "timeshift is not installed (pacman -S timeshift)"
command -v jq        >/dev/null || die "jq is not installed (pacman -S jq)"
command -v systemd-inhibit >/dev/null || die "systemd-inhibit not found"

ROOT_FSTYPE=$(findmnt -no FSTYPE /)
[[ $ROOT_FSTYPE == btrfs ]] || die "/ is $ROOT_FSTYPE, not btrfs — BTRFS mode needs a btrfs root"

# Timeshift's BTRFS mode requires the root subvolume to be named exactly '@'.
ROOT_SRC=$(findmnt -no SOURCE /)
[[ $ROOT_SRC == *'[/@]'* ]] || die "root subvolume is not '@' (found: $ROOT_SRC) — Timeshift BTRFS mode requires it"

# backup_device_uuid = the btrfs filesystem; parent_device_uuid = the LUKS/partition
# underneath it, if any. Detected rather than hardcoded so this survives a reinstall.
FS_UUID=$(findmnt -no UUID /)
[[ -n $FS_UUID ]] || die "could not determine the UUID of /"

PARENT_UUID=""
if [[ $ROOT_SRC == /dev/mapper/* ]]; then
    _dm=${ROOT_SRC%%\[*}
    # TYPE first: it is never empty, so columns stay aligned even when a device
    # in the chain has no UUID.
    PARENT_UUID=$(lsblk -sno TYPE,UUID "$_dm" 2>/dev/null \
        | awk '$1=="part" && $2!="" {print $2; exit}') || true
fi

info "btrfs filesystem : $FS_UUID"
[[ -n $PARENT_UUID ]] && info "encrypted parent : $PARENT_UUID"
info "include @home    : $INCLUDE_HOME"

# --- 1. configure timeshift ------------------------------------------------

[[ -f $CONFIG ]] || die "$CONFIG not found — run 'timeshift --list' once to generate it"

BACKUP="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$CONFIG" "$BACKUP"
info "backed up config to $BACKUP"

# Timeshift stores booleans and integers as JSON *strings*, hence --arg throughout.
tmpcfg=$(mktemp)
jq \
  --arg dev     "$FS_UUID" \
  --arg parent  "$PARENT_UUID" \
  --arg home    "$INCLUDE_HOME" \
  --arg rhome   "$INCLUDE_HOME_ON_RESTORE" \
  --arg s_boot  "$SCHED_BOOT"    --arg c_boot  "$COUNT_BOOT" \
  --arg s_day   "$SCHED_DAILY"   --arg c_day   "$COUNT_DAILY" \
  --arg s_week  "$SCHED_WEEKLY"  --arg c_week  "$COUNT_WEEKLY" \
  --arg s_month "$SCHED_MONTHLY" --arg c_month "$COUNT_MONTHLY" \
  --arg s_hour  "$SCHED_HOURLY"  --arg c_hour  "$COUNT_HOURLY" \
  '
    .btrfs_mode         = "true"
  | .do_first_run       = "false"
  | .stop_cron_emails   = "true"
  | .backup_device_uuid = $dev
  | .parent_device_uuid = $parent
  # This timeshift build reads the split *_for_backup / *_for_restore keys;
  # the bare include_btrfs_home is the legacy name, set too for good measure.
  | .include_btrfs_home             = $home
  | .include_btrfs_home_for_backup  = $home
  | .include_btrfs_home_for_restore = $rhome
  | .schedule_boot      = $s_boot  | .count_boot    = $c_boot
  | .schedule_daily     = $s_day   | .count_daily   = $c_day
  | .schedule_weekly    = $s_week  | .count_weekly  = $c_week
  | .schedule_monthly   = $s_month | .count_monthly = $c_month
  | .schedule_hourly    = $s_hour  | .count_hourly  = $c_hour
  ' "$CONFIG" > "$tmpcfg"

# Only clobber the real config once jq has produced valid output.
[[ -s $tmpcfg ]] || die "jq produced an empty config; original left at $CONFIG"
install -m 0644 -o root -g root "$tmpcfg" "$CONFIG"
rm -f "$tmpcfg"
ok "Timeshift configured for BTRFS mode"

# --- 2. cron: leave it alone -----------------------------------------------

# Timeshift rewrites /etc/cron.d/timeshift-{hourly,boot} on EVERY run -- not just
# when you save settings in the GUI. Deleting them here is pointless: the first
# snapshot this script takes puts them straight back. So we let cron own the
# in-session schedule (hourly --check, and the @reboot boot snapshot) and add a
# systemd timer alongside it purely for catch-up, which is the one thing cron
# cannot do on a laptop that sleeps through its window.
#
# Both paths run the same idempotent 'timeshift --check', and timeshift holds a
# single-instance lock, so the overlap is safe.
info "leaving Timeshift's cron entries in place (it recreates them regardless)"

# --- 3. install systemd units ----------------------------------------------

# Hourly due-check. 'timeshift --check' is idempotent: it creates a snapshot only
# if one is actually due per the schedule above, and it also applies retention
# (deleting snapshots beyond the keep counts, including boot ones).
cat > "$UNIT_DIR/timeshift-check.service" <<'EOF'
[Unit]
Description=Timeshift scheduled snapshot check
Documentation=man:timeshift(1)
ConditionPathExists=/etc/timeshift/timeshift.json

[Service]
Type=oneshot
# --mode=block holds off suspend/shutdown until timeshift exits, so closing the
# lid mid-snapshot defers the suspend instead of interrupting the run.
ExecStart=/usr/bin/systemd-inhibit \
    --what=sleep:shutdown:idle \
    --who=timeshift \
    --why="Creating scheduled system snapshot" \
    --mode=block \
    /usr/bin/timeshift --check --scripted
EOF

cat > "$UNIT_DIR/timeshift-check.timer" <<'EOF'
[Unit]
Description=Timeshift snapshot check (hourly, with catch-up)

[Timer]
OnCalendar=hourly
# The key laptop setting: if the window passed while suspended or powered off,
# this fires as soon as the machine is awake again instead of skipping.
Persistent=true
RandomizedDelaySec=5m
AccuracySec=1m

[Install]
WantedBy=timers.target
EOF

chmod 0644 "$UNIT_DIR"/timeshift-check.{service,timer}
ok "installed systemd units"

# Boot snapshots come from cron's @reboot entry, which timeshift maintains itself.
# An earlier version of this script shipped a timeshift-boot.timer for that; it
# duplicated the cron job (two boot snapshots racing per boot), so remove it.
if [[ -e $UNIT_DIR/timeshift-boot.timer ]]; then
    systemctl disable --now timeshift-boot.timer >/dev/null 2>&1 || true
    rm -f "$UNIT_DIR"/timeshift-boot.{service,timer}
    ok "removed the redundant timeshift-boot units (cron's @reboot covers this)"
fi

systemctl daemon-reload

systemctl enable --now timeshift-check.timer >/dev/null
ok "enabled timeshift-check.timer"

# --- 4. first snapshot + verification --------------------------------------

if [[ $TAKE_FIRST_SNAPSHOT == true ]]; then
    info "taking a first snapshot..."
    # Timeshift refuses to start if another instance holds the lock (a cron
    # --check can fire at any minute). That is not a failure worth aborting on:
    # wait briefly, then treat a busy lock as success -- a snapshot is being
    # written either way.
    snap_out=$(systemd-inhibit --what=sleep:shutdown:idle --who=timeshift \
        --why="Creating initial system snapshot" --mode=block \
        timeshift --create --scripted --comments "initial setup" 2>&1) && rc=0 || rc=$?
    printf '%s\n' "$snap_out"
    if (( rc != 0 )); then
        if grep -qi 'Another instance' <<<"$snap_out"; then
            info "another timeshift run held the lock; it is creating a snapshot instead"
        else
            die "snapshot creation failed — see output above; config backup at $BACKUP"
        fi
    else
        ok "snapshot created"
    fi
fi

echo
info "snapshots:"
timeshift --list || true
echo
info "timers:"
systemctl list-timers --no-pager 'timeshift-*' || true

echo
ok "Done. Useful commands:"
cat <<'EOF'

  timeshift --list                              list snapshots
  sudo systemctl start timeshift-check.service  force a due-check now
  journalctl -u timeshift-check.service -n 50   check for errors
  systemctl list-timers 'timeshift-*'           when the next run is due
  sudo timeshift-gtk                            GUI

  Scheduling is split on purpose: cron (which timeshift maintains itself) runs
  the hourly check and the @reboot boot snapshot while the laptop is awake;
  timeshift-check.timer adds Persistent=true catch-up for windows missed while
  it was suspended or off. Same idempotent command, single-instance locked.

  Recovering individual files from ~ (no full restore needed):

    sudo mount -o subvol=/ /dev/mapper/root /mnt
    ls /mnt/timeshift-btrfs/snapshots/                 # pick a date
    cp -a /mnt/timeshift-btrfs/snapshots/<date>/@home/lukas/path/to/file ~/
    sudo umount /mnt

  Snapshots are read-only, so browsing them cannot damage anything.

  Reminder: these snapshots live on the same filesystem as your data. They undo
  mistakes; they do not survive a failed SSD. Your system files are replaceable
  from packages, but ~ is not — keep a real off-disk backup of it as well.
EOF
