#!/usr/bin/env bash
# Symlink the configured stow packages into $HOME.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

command -v stow >/dev/null 2>&1 || pac_install stow

cd "$DOTFILES_DIR"

# Move aside pre-existing regular files (e.g. /etc/skel's .bashrc on a fresh
# machine) that would block stow; symlinks/dirs are left for stow to manage.
backup_conflicts() {
    local pkg="$1" rel target
    while IFS= read -r -d '' f; do
        rel="${f#"$pkg"/}"
        target="$HOME/$rel"
        if [ -e "$target" ] && [ ! -L "$target" ] && [ ! -d "$target" ] &&
           [ "$(realpath -e "$target" 2>/dev/null)" != "$(realpath -e "$f")" ]; then
            warn "Backing up pre-existing $target -> $target.pre-stow"
            run mv "$target" "$target.pre-stow"
        fi
    done < <(find "$pkg" -type f -print0)
}

for pkg in $(cfg STOW_PACKAGES "awesome nvim tmux alacritty fontconfig bash rclone clang-format cava qt greenclip"); do
    if [ -d "$pkg" ]; then
        log "Stowing '$pkg' -> \$HOME"
        backup_conflicts "$pkg"
        # -R (restow) makes re-runs idempotent.
        run stow -v -R -t "$HOME" "$pkg"
    else
        warn "stow package '$pkg' not found, skipping."
    fi
done
ok "Symlinks created. (Pre-existing files were saved as *.pre-stow.)"
