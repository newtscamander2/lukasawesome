#!/usr/bin/env bash
# Symlink the configured stow packages into $HOME.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

command -v stow >/dev/null 2>&1 || pac_install stow

cd "$DOTFILES_DIR"
for pkg in $(cfg STOW_PACKAGES "awesome nvim tmux alacritty fontconfig bash rclone clang-format"); do
    if [ -d "$pkg" ]; then
        log "Stowing '$pkg' -> \$HOME"
        # -R (restow) makes re-runs idempotent.
        run stow -v -R -t "$HOME" "$pkg"
    else
        warn "stow package '$pkg' not found, skipping."
    fi
done
ok "Symlinks created. (If stow reported conflicts, remove the pre-existing files and re-run.)"
