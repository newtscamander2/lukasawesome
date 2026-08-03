#!/usr/bin/env bash
# SSH identity + personal repo cloning (GitLab/GitHub).
#
# Deliberately NOT part of `make install`: a fresh machine can complete the
# full install over HTTPS with zero forge credentials. Run `make repos` when
# this machine should get its own SSH key and the personal repos.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

# Key path: SSH_KEY in install.conf wins. Otherwise reuse the key already on
# the machine — assuming a fixed filename generated a second, unused key on a
# machine where the key had been created by hand under another name.
KEY="$(cfg SSH_KEY "")"
if [ -z "$KEY" ]; then
    existing=()
    while IFS= read -r pub; do
        existing+=("${pub%.pub}")
    done < <(find "$HOME/.ssh" -maxdepth 1 -type f -name '*.pub' 2>/dev/null | sort)

    case "${#existing[@]}" in
        0) KEY="$HOME/.ssh/id_ed25519" ;;
        1) KEY="${existing[0]}"; log "Reusing existing SSH key: $KEY" ;;
        *) err "Several SSH keys exist in ~/.ssh:"
           printf '     %s\n' "${existing[@]}" >&2
           err "Set SSH_KEY=<path> in install.conf so this is unambiguous."
           exit 1 ;;
    esac
fi

# Label stored in the .pub file. Cosmetic (forges use it as the key title), but
# 'whoami@hostname' is a poor label and 'hostname' is not installed on a stock
# Arch system — it lives in inetutils, so it silently expanded to nothing.
# Prefer the git identity, which is the name you actually go by on the forge.
default_host="$(hostnamectl --static 2>/dev/null || cat /etc/hostname 2>/dev/null || echo unknown)"
default_comment="$(git config --global user.email 2>/dev/null || true)"
[ -z "$default_comment" ] && default_comment="$(whoami)@$default_host"
KEY_COMMENT="$(cfg SSH_KEY_COMMENT "$default_comment")"

# --- 1. SSH key --------------------------------------------------------------
if [ -f "$KEY" ]; then
    ok "SSH key $KEY already exists."
else
    log "Generating SSH key ($KEY) labelled '$KEY_COMMENT'"
    run mkdir -p "$HOME/.ssh"
    run ssh-keygen -t ed25519 -f "$KEY" -C "$KEY_COMMENT"
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
