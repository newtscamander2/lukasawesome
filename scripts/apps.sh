#!/usr/bin/env bash
# Post-install app provisioning: VSCode settings/extensions, personal repos,
# and the video-wallpaper marker.
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

# --- Personal repos into ~/projects ---
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

# --- Video wallpaper marker read by rc.lua ---
marker="$HOME/.config/awesome/video_wallpaper"
if enabled VIDEO_WALLPAPER; then
    log "Enabling video wallpaper"
    run_sh "mkdir -p '$(dirname "$marker")' && touch '$marker'"
else
    run_sh "rm -f '$marker'"
fi

ok "App provisioning complete."
