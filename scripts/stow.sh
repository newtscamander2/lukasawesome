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

for pkg in $(cfg STOW_PACKAGES "awesome nvim tmux alacritty fontconfig bash rclone clang-format cava qt notes keepassxc"); do
    if [ -d "$pkg" ]; then
        log "Stowing '$pkg' -> \$HOME"
        backup_conflicts "$pkg"
        # -R (restow) makes re-runs idempotent.
        #
        # --ignore for systemd's *.target.wants directories: they record which
        # units are enabled, and systemd only honours them as REAL directories.
        # With one stow package owning ~/.config/systemd/user, stow folds the
        # whole directory into a single symlink and the .wants dirs inside it
        # stay real, so it works by accident. Add a second package and stow has
        # to unfold, turning each .wants into a symlink -- at which point
        # systemd silently stops seeing them and the units never start at boot.
        # That is how the ssh-agent socket died, and with it every background
        # push of the notes snapshots. Let `systemctl --user enable` own them
        # instead, which is what .gitignore has always said.
        run stow -v -R --ignore='.*\.target\.wants' -t "$HOME" "$pkg"
    else
        warn "stow package '$pkg' not found, skipping."
    fi
done
ok "Symlinks created. (Pre-existing files were saved as *.pre-stow.)"
