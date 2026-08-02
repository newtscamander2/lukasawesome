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

# --- Video wallpaper marker read by rc.lua ---
marker="$HOME/.config/awesome/video_wallpaper"
if enabled VIDEO_WALLPAPER; then
    log "Enabling video wallpaper"
    run_sh "mkdir -p '$(dirname "$marker")' && touch '$marker'"
else
    run_sh "rm -f '$marker'"
fi

ok "App provisioning complete."
