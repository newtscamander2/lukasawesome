#!/usr/bin/env bash
# Set up ~/aarhusuni as a git repository laid out for worktrees — one working
# directory per course — and turn on the five-minute snapshot timer.
#
#     ~/aarhusuni/.bare/          the only copy of the history
#     ~/aarhusuni/.git            one line: "gitdir: ./.bare"
#     ~/aarhusuni/main/           branch main — every course, merged
#     ~/aarhusuni/course/math/    branch course/math
#
# Two jobs, decided by what is already on GitLab:
#
#   first time   the notes are here and the project is empty  -> init and push
#   new machine  the project has commits                      -> clone them back
#
# Idempotent either way: safe to re-run, and `DRY_RUN=1 make notes` prints
# every action without touching anything.
#
# Deliberately NOT part of `make install`: it needs GitLab access, and a fresh
# machine should be able to finish the base install without any credentials.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

NOTES="$(cfg NOTES_DIR "$HOME/aarhusuni")"
NAMESPACE="$(cfg GITLAB_NAMESPACE "newtscamander")"
PROJECT="$(cfg NOTES_PROJECT "aarhusuni")"
# The unattended key: no passphrase, registered on the project as a deploy key.
# SSH_ALIAS is a Host entry pointing at gitlab.com but offering only this key,
# so the notes remote uses it and nothing else does.
DEPLOY_KEY="$(cfg NOTES_DEPLOY_KEY "$HOME/.ssh/id_ed25519_${PROJECT}")"
SSH_ALIAS="gitlab-${PROJECT}"
# NOTES_REMOTE overrides the lot — for a different forge, or for testing this
# script against a throwaway repository on disk.
REMOTE="$(cfg NOTES_REMOTE "git@${SSH_ALIAS}:${NAMESPACE}/${PROJECT}.git")"
BARE="$NOTES/.bare"
MAIN="$NOTES/main"
HOOKS_SRC="$DOTFILES_DIR/scripts/notes-hooks"

# ---------------------------------------------------------------------------
# 1. Preconditions
# ---------------------------------------------------------------------------
command -v git >/dev/null 2>&1 || { err "git is not installed."; exit 1; }

# The systemd ssh-agent socket. bash/.bashrc exports this too, but only for
# interactive shells — and this script is usually reached through make, which is
# not one. Without it every push here would fail for want of a key.
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket}"

# Enable the socket, do not just point at it. Nothing else in this repo turned
# it on: check-system asked whether it was enabled and every fresh machine
# answered no, so the snapshot timer had no agent to push with and failed
# silently -- exactly the outage the timer exists to prevent. Socket activation
# means enabling it costs nothing until something connects.
run systemctl --user enable --now ssh-agent.socket

GITLAB_REMOTE=0
case "$REMOTE" in *gitlab.com*|*"$SSH_ALIAS"*) GITLAB_REMOTE=1 ;; esac

# ---------------------------------------------------------------------------
# 1b. The unattended key
#
# The snapshot timer runs while nobody is at the keyboard, so it cannot answer a
# passphrase prompt. This is a second key with no passphrase, registered on the
# notes project as a DEPLOY KEY rather than on the account.
#
# What that buys, precisely: the key sits unencrypted on this disk, so it must
# reach as little as possible. As a deploy key it reaches exactly one project --
# lose the laptop and you revoke one key in one project's settings; goat, cv,
# lukasawesome and the account itself are untouched.
#
# What it does NOT buy, so nobody is misled by the name: a write deploy key can
# push to any branch its creator could, not only wip/*. GitLab has no
# branch-scoped deploy keys on Free -- protecting main against everyone would
# block your own pushes too, and push rules by branch name are a paid feature.
# Treat the key as "full write access to the notes project, and nothing else".
# ---------------------------------------------------------------------------
setup_deploy_key() {
    [ "$GITLAB_REMOTE" = "1" ] || return 0

    if [ -f "$DEPLOY_KEY" ]; then
        ok "Deploy key already exists ($DEPLOY_KEY)."
    else
        log "Creating a passphrase-less deploy key for ${PROJECT}"
        run mkdir -p "$(dirname "$DEPLOY_KEY")"
        run ssh-keygen -t ed25519 -f "$DEPLOY_KEY" -N "" -q \
            -C "${PROJECT}-autosave@$(hostnamectl --static 2>/dev/null || cat /etc/hostname 2>/dev/null || echo unknown)"
    fi
    [ "$DRY_RUN" = "1" ] || { chmod 600 "$DEPLOY_KEY"; chmod 644 "$DEPLOY_KEY.pub"; }

    # The Host alias, written between markers so re-runs replace rather than
    # append. Without IdentitiesOnly the account key would be offered first and
    # GitLab would accept it, hiding the fact that the deploy key is missing.
    local cfg_file="$HOME/.ssh/config"
    # State first, DRY_RUN second: checking the flag first made a dry run report
    # "would add" even when the block was already there.
    if grep -q "^Host ${SSH_ALIAS}\$" "$cfg_file" 2>/dev/null; then
        ok "$SSH_ALIAS is already in $cfg_file."
    elif [ "$DRY_RUN" = "1" ]; then
        log "would add the '$SSH_ALIAS' block to $cfg_file"
    else
        log "Adding the '$SSH_ALIAS' host to $cfg_file"
        # Prepended, not appended: ssh takes the first value it finds for most
        # options, and a catch-all "Host *" at the end of the file would
        # otherwise win over anything added after it.
        local tmp; tmp="$(mktemp)"
        {
            printf '# --- %s (managed by lukasawesome: make notes) ---\n' "$SSH_ALIAS"
            printf '# Unattended pushes for the notes repository. Deploy key on that\n'
            printf '# project only -- see scripts/notes.sh for what it can and cannot do.\n'
            printf 'Host %s\n' "$SSH_ALIAS"
            printf '    HostName gitlab.com\n'
            printf '    User git\n'
            printf '    IdentityFile %s\n' "${DEPLOY_KEY/#$HOME/\~}"
            printf '    IdentitiesOnly yes\n'
            printf '    AddKeysToAgent yes\n'
            # ssh matches config blocks by the ALIAS, so the "Host gitlab.com"
            # block's IPv6 workaround does not apply here — repeat it.
            printf '    AddressFamily inet\n'
            printf '    ConnectTimeout 10\n'
            printf '\n'
            [ -f "$cfg_file" ] && cat "$cfg_file"
        } > "$tmp"
        mv "$tmp" "$cfg_file"
        chmod 600 "$cfg_file"
        ok "$SSH_ALIAS -> gitlab.com using $(basename "$DEPLOY_KEY")"
    fi

}

# Can we reach the project at all, and with which key? The deploy key is tried
# on its own first -- if it works, this machine needs nothing else, which is the
# whole point of having it. The account key is the fallback, and only one of the
# two has to work.
deploy_key_works() {
    [ -f "$DEPLOY_KEY" ] || return 1
    # -F /dev/null: a "Host gitlab.com" block in ~/.ssh/config contributes its
    # IdentityFile even under IdentitiesOnly=yes, so the ACCOUNT key would be
    # offered alongside -i and GitLab would accept it — reporting the deploy
    # key as registered when it is not. Test with the deploy key and nothing
    # else. AddressFamily inet matches the config workaround this drops: IPv6
    # to gitlab.com blackholes on some networks.
    GIT_SSH_COMMAND="ssh -F /dev/null -i $DEPLOY_KEY -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 -o AddressFamily=inet -o StrictHostKeyChecking=accept-new" \
        git ls-remote --heads "git@gitlab.com:${NAMESPACE}/${PROJECT}.git" >/dev/null 2>&1
}

check_access() {
    [ "$GITLAB_REMOTE" = "1" ] || return 0
    [ "$DRY_RUN" = "1" ] && return 0

    if deploy_key_works; then
        ok "The deploy key is registered and can reach ${PROJECT}."
        return 0
    fi

    warn "The deploy key is not registered on ${PROJECT} yet, so unattended"
    warn "snapshots cannot be pushed -- they will be saved locally only."
    echo
    log "Add it at:"
    echo "   https://gitlab.com/${NAMESPACE}/${PROJECT}/-/settings/repository"
    echo "   -> Deploy keys -> Add new key"
    echo "   -> TICK 'Grant write permissions to this repository'"
    echo
    log "The key (also at ${DEPLOY_KEY}.pub):"
    echo
    cat "$DEPLOY_KEY.pub" 2>/dev/null
    echo

    # Without the deploy key, the account key has to carry this run. BatchMode
    # unless someone is at the keyboard: with no terminal there is nobody to
    # type a passphrase, and ssh would otherwise sit waiting for one until the
    # end of time -- a setup script that hangs is worse than one that fails.
    local batch=(-o BatchMode=yes)
    [ -t 0 ] && batch=()
    ssh_out="$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
        "${batch[@]}" -T git@gitlab.com 2>&1 || true)"
    if printf '%s' "$ssh_out" | grep -q "Welcome to GitLab"; then
        ok "Your account key works, so setup can continue."
        log "Re-run 'make notes' after adding the deploy key to verify it."
    else
        err "Your account key does not work either:"
        printf '     %s\n' "$ssh_out" >&2
        err "Either add the deploy key above, or run 'make repos' to set up"
        err "this machine's account key. One of the two has to work."
        exit 1
    fi
}

setup_deploy_key
check_access

# Does the project exist, and does it have anything in it? This is what decides
# which of the two jobs we are doing, and it is worth knowing before writing
# anything at all.
remote_state="missing"
ls_remote_error=""
if [ "$DRY_RUN" != "1" ]; then
    if refs="$(git ls-remote --heads "$REMOTE" 2>&1)"; then
        # An empty project answers successfully with no refs at all — that is
        # the state we want, not a failure.
        [ -n "$refs" ] && remote_state="populated" || remote_state="empty"
    else
        ls_remote_error="$refs"
    fi
fi

if [ "$remote_state" = "missing" ] && [ "$DRY_RUN" != "1" ]; then
    err "Cannot reach ${REMOTE}:"
    printf '     %s\n' "$ls_remote_error" >&2
    echo >&2
    if printf '%s' "$ls_remote_error" | grep -qi "permission denied\|could not read from remote\|publickey"; then
        err "That is an access error, not a missing project. Either the key is"
        err "not in the agent, or the project belongs to someone else."
        err "  ssh-add -l                 # is the key loaded?"
        err "  ssh-add ~/.ssh/id_ed25519  # load it (asks for the passphrase)"
        exit 1
    fi
    # Deliberately not automated. GitLab can create a project from a push, but
    # then its visibility comes from a server default — and "private" is not
    # something to infer for six years of coursework.
    err "Create it first, so its visibility is your decision and not a default:"
    err "  1. https://gitlab.com/projects/new  ->  Create blank project"
    err "  2. Project name: ${PROJECT}"
    err "  3. Visibility: PRIVATE"
    err "  4. Untick 'Initialize repository with a README' — it must be empty"
    echo >&2
    err "Then run 'make notes' again."
    exit 1
fi
if [ "$DRY_RUN" = "1" ]; then
    log "Would check ${REMOTE} and either push to it or clone from it."
else
    log "GitLab project ${REMOTE} is ${remote_state}."
fi

# ---------------------------------------------------------------------------
# 2. The bare repository
# ---------------------------------------------------------------------------
fresh_clone=0
if [ -d "$BARE" ]; then
    ok "$BARE already exists."
elif [ "$remote_state" = "populated" ]; then
    log "The project already has commits — cloning them onto this machine."
    run mkdir -p "$NOTES"
    run git clone --bare "$REMOTE" "$BARE"
    fresh_clone=1
else
    log "Creating a new repository at $BARE"
    run mkdir -p "$NOTES"
    run git init --bare --quiet --initial-branch=main "$BARE"
    run git -C "$BARE" remote add origin "$REMOTE"
fi

# The .git file is what makes ~/aarhusuni itself behave like the repository, so
# `git -C ~/aarhusuni ...` works from the top of the layout.
if [ ! -e "$NOTES/.git" ]; then
    log "Pointing $NOTES/.git at ./.bare"
    run_sh "printf 'gitdir: ./.bare\n' > '$NOTES/.git'"
fi

# A bare clone fetches nothing by default: without this, remote branches made on
# another machine would never become visible here. (This is the step the dev.to
# article calls out, and the one people forget.)
run git -C "$BARE" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# ---------------------------------------------------------------------------
# 3. Guardrail configuration
# ---------------------------------------------------------------------------
# core.hooksPath is relative, so it resolves inside whichever worktree is
# committing — every worktree therefore uses the hooks its own branch carries,
# and a fresh clone gets them without installing anything.
run git -C "$BARE" config core.hooksPath .githooks
# A pull may only fast-forward. Anything else is a merge you did not ask for.
run git -C "$BARE" config pull.ff only
# Show the common ancestor in a conflict, not just the two sides — the only
# thing that makes a conflict readable if one ever happens.
run git -C "$BARE" config merge.conflictStyle zdiff3
# Remember how a conflict was resolved, in case the same one comes back.
run git -C "$BARE" config rerere.enabled true
# Drop remote branches that no longer exist, so --classes never lists ghosts.
run git -C "$BARE" config fetch.prune true
run git -C "$BARE" config push.default simple
# Notes are text; the hook refuses anything bigger by mistake.
run git -C "$BARE" config goat.maxfilemb 20
ok "Guardrails configured (hooks, ff-only pulls, prune, size limit)."

# ---------------------------------------------------------------------------
# 4. The main worktree
# ---------------------------------------------------------------------------
if [ -d "$MAIN" ]; then
    ok "$MAIN already exists."
elif [ "$fresh_clone" = "1" ]; then
    log "Checking out main"
    run git -C "$NOTES" worktree add "$MAIN" main
else
    log "Creating the main worktree"
    run git -C "$NOTES" worktree add --orphan -b main "$MAIN" 2>/dev/null \
        || run git -C "$NOTES" worktree add --detach "$MAIN"
fi

# Existing notes: anything sitting loose in ~/aarhusuni belongs in main/. This
# is the one destructive-looking step, so it moves rather than copies, refuses
# to overwrite, and says exactly what it did.
if [ "$DRY_RUN" != "1" ] && [ -d "$MAIN" ]; then
    shopt -s nullglob
    for entry in "$NOTES"/*semester; do
        name="$(basename "$entry")"
        if [ -e "$MAIN/$name" ]; then
            warn "Both $entry and $MAIN/$name exist — leaving both alone."
            warn "Merge them by hand, then delete $entry."
        else
            log "Moving $name into the main worktree"
            mv "$entry" "$MAIN/$name"
            ok "$name is now at $MAIN/$name"
        fi
    done
    shopt -u nullglob
fi

# ---------------------------------------------------------------------------
# 5. The files the repository needs to defend itself
# ---------------------------------------------------------------------------
install_repo_files() {
    [ -d "$MAIN" ] || return 0

    run mkdir -p "$MAIN/.githooks"
    for hook in "$HOOKS_SRC"/*; do
        [ -f "$hook" ] || continue
        run install -m 0755 "$hook" "$MAIN/.githooks/$(basename "$hook")"
    done

    if [ ! -f "$MAIN/.gitignore" ]; then
        run_sh "cat > '$MAIN/.gitignore' <<'IGNORE'
# The source is main.tex. Everything a build produces is derived, and stays out
# of the history — which also means: anything matched here is NOT backed up by
# the snapshot timer.

# latexmk's aux directory (see the .latexmkrc gm writes into every entry)
latex_debug_files/

# LaTeX build artefacts
*.aux
*.bbl
*.bcf
*.blg
*.fdb_latexmk
*.fls
*.log
*.lof
*.lot
*.out
*.toc
*.run.xml
*.synctex.gz
*.synctex(busy)
*.nav
*.snm
*.vrb
*.idx
*.ilg
*.ind
*.glo
*.gls
*.glg
*.xdv
*.pytxcode
pythontex-files-*/
build/
_minted*/

# PDFs ARE kept, deliberately. They are technically build artefacts, but the
# question "what exactly did I hand in?" has one correct answer and it is not
# "whatever recompiling produces today" — fonts, package versions and the goat
# release all move underneath you over three years.
#
# The cost: every latexmk run rewrites main.pdf, so a rebuilt document shows as
# changed even when the .tex did not move. Build noise lives in
# latex_debug_files/, ignored above.

# Editor and OS noise
*.swp
*~
.DS_Store
.vscode/
IGNORE"
    fi

    # No README. Every file at the top of the repository is checked out into
    # every course worktree as well (cone-mode sparse-checkout keeps root
    # files), so a README is clutter in five places to say something the docs
    # already say. .gitignore and .githooks earn their place there; prose does
    # not. The guide lives in ~/lukasawesome/docs/worktrees.md.
    ok "Hooks and .gitignore are in place."
}
install_repo_files

# First commit, if this is a new repository.
if [ "$DRY_RUN" != "1" ] && [ "$fresh_clone" = "0" ] && [ -d "$MAIN" ]; then
    if ! git -C "$MAIN" rev-parse --verify --quiet HEAD >/dev/null; then
        log "First commit"
        git -C "$MAIN" add -A
        git -C "$MAIN" commit --quiet -m "notes: start"
        ok "Committed."
    fi
    if [ -n "$(git -C "$MAIN" status --porcelain)" ]; then
        log "Committing the repository's own files"
        git -C "$MAIN" add -A
        git -C "$MAIN" commit --quiet -m "notes: hooks, ignore rules and README"
        ok "Committed."
    fi
    log "Pushing main"
    git -C "$MAIN" push --set-upstream origin main
    ok "main is on GitLab."
fi

# Nested projects (shared homework) are ignored by the parent by design, so a
# fresh clone has to be told to fetch them back.
if [ "$fresh_clone" = "1" ] && [ "$DRY_RUN" != "1" ]; then
    "$HOME/.local/bin/goat-manager" --nest restore || \
        warn "Could not restore nested projects — run 'gm --nest restore' later."
fi

# ---------------------------------------------------------------------------
# 6. The snapshot timer
# ---------------------------------------------------------------------------
UNIT="$HOME/.config/systemd/user/goat-autosave.timer"
if [ -e "$UNIT" ]; then
    run systemctl --user daemon-reload
    run systemctl --user enable --now goat-autosave.timer
    ok "Snapshots every five minutes (systemctl --user list-timers goat-autosave)."
else
    warn "$UNIT is missing — run 'make stow' (the 'notes' package ships it),"
    warn "then re-run 'make notes'."
fi

# ---------------------------------------------------------------------------
echo
ok "Notes repository ready at $NOTES"
echo
log "Open a course:        class math"
log "See what is loose:    gm --pending"
log "Read the guide:       $DOTFILES_DIR/docs/worktrees.md"
