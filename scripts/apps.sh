#!/usr/bin/env bash
# Post-install app provisioning: VSCode settings/extensions and the
# video-wallpaper marker. (Personal repo cloning lives in repos.sh —
# `make repos` — so `make install` never needs SSH keys.)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

# --- VSCode OSS: dark mode settings + LaTeX Workshop extension ---
if enabled INSTALL_VSCODE; then
    dest="$HOME/.config/Code - OSS/User"
    log "Applying VSCode OSS settings"
    run mkdir -p "$dest"
    run cp "$DOTFILES_DIR/vscode/settings.json" "$dest/settings.json"
    if command -v code >/dev/null 2>&1; then
        while IFS= read -r ext; do
            [ -z "$ext" ] && continue
            case "$ext" in \#*) continue ;; esac
            run code --install-extension "$ext"
        done < "$DOTFILES_DIR/vscode/extensions.txt"
    elif [ "$DRY_RUN" = "1" ]; then
        printf "   [dry-run] code --install-extension (from vscode/extensions.txt)\n"
    else
        warn "'code' not found; install VSCode OSS, then re-run to add extensions."
    fi
fi

# --- Brave: managed policy (forced extensions + Rewards disabled) ---
if enabled INSTALL_BROWSER; then
    log "Installing Brave managed policy (extensions, Rewards off)"
    run sudo install -Dm644 "$DOTFILES_DIR/brave/policies.json" \
        /etc/brave/policies/managed/lukasawesome.json
fi

# --- Neovim: bootstrap lazy.nvim + install plugins from the lockfile ---
# Owning this here means `make install` leaves a fully working editor: a
# partial/interrupted first clone of lazy.nvim otherwise blocks every later
# nvim start with "module 'lazy' not found".
if command -v nvim >/dev/null 2>&1; then
    lazydir="$HOME/.local/share/nvim/lazy/lazy.nvim"
    if [ ! -f "$lazydir/lua/lazy/init.lua" ]; then
        log "Bootstrapping lazy.nvim (removing any partial clone first)"
        run rm -rf "$lazydir"
        if ! run git clone --filter=blob:none --branch=stable \
                https://github.com/folke/lazy.nvim.git "$lazydir"; then
            err "Could not clone lazy.nvim from GitHub — check network and re-run 'make apps'."
            exit 1
        fi
    fi
    log "Installing nvim plugins from lazy-lock.json (headless, first run takes a minute)"
    run nvim --headless "+Lazy! restore" +qa \
        || warn "Plugin restore reported errors — open nvim and run :Lazy sync."
else
    warn "nvim not installed yet — re-run 'make packages' then 'make apps'."
fi

# --- Video wallpaper marker read by rc.lua ---
marker="$HOME/.config/awesome/video_wallpaper"
if enabled VIDEO_WALLPAPER; then
    log "Enabling video wallpaper"
    run_sh "mkdir -p '$(dirname "$marker")' && touch '$marker'"
else
    run_sh "rm -f '$marker'"
fi

ok "App provisioning complete."
