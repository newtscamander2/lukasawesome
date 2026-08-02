#!/usr/bin/env bash
# SSH identity + personal repo cloning (GitLab/GitHub).
#
# Deliberately NOT part of `make install`: a fresh machine can complete the
# full install over HTTPS with zero forge credentials. Run `make repos` when
# this machine should get its own SSH key and the personal repos.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

KEY="$HOME/.ssh/id_ed25519"

# --- 1. SSH key --------------------------------------------------------------
if [ -f "$KEY" ]; then
    ok "SSH key $KEY already exists."
else
    log "Generating SSH key ($KEY)"
    run mkdir -p "$HOME/.ssh"
    run ssh-keygen -t ed25519 -f "$KEY" -C "$(whoami)@$(hostname)"
fi

if [ -f "$KEY.pub" ]; then
    log "Public key — add it to your forges:"
    echo
    cat "$KEY.pub"
    echo
    log "GitLab: https://gitlab.com/-/user_settings/ssh_keys"
    log "GitHub: https://github.com/settings/ssh/new  (if this machine needs GitHub)"
fi
if [ "$(ask_yn 'Key added to GitLab — continue with clone/remote setup?' y)" != "yes" ]; then
    warn "Stopping. Re-run 'make repos' once the key is registered."
    exit 0
fi

# --- 2. Verify GitLab access ---------------------------------------------------
if [ "$DRY_RUN" != "1" ]; then
    ssh_out="$(ssh -o StrictHostKeyChecking=accept-new -T git@gitlab.com 2>&1 || true)"
    if printf '%s' "$ssh_out" | grep -q "Welcome to GitLab"; then
        ok "GitLab SSH access works."
    else
        err "GitLab did not accept the key ($ssh_out)."
        err "Register the key shown above, then re-run 'make repos'."
        exit 1
    fi
fi

# --- 3. Personal repos into ~/projects ----------------------------------------
clone_repo() {
    local url="$1" dir="$2"
    if [ -d "$dir/.git" ]; then
        ok "$dir already cloned."
    else
        run git clone "$url" "$dir"
    fi
}

run mkdir -p "$HOME/projects"
enabled CLONE_CV   && clone_repo "git@gitlab.com:newtscamander/cv.git"   "$HOME/projects/cv"
# goat is required by the neovim config (goat completion source).
enabled CLONE_GOAT && clone_repo "git@gitlab.com:newtscamander/goat.git" "$HOME/projects/goat"

# --- 4. Flip the dotfiles remote to SSH so future pushes work ------------------
origin="$(git -C "$DOTFILES_DIR" remote get-url origin 2>/dev/null || true)"
case "$origin" in
    https://gitlab.com/newtscamander/lukasawesome*)
        log "Switching dotfiles origin from HTTPS to SSH"
        run git -C "$DOTFILES_DIR" remote set-url origin git@gitlab.com:newtscamander/lukasawesome.git
        ;;
esac

ok "SSH + repo setup complete."
