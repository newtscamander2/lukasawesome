#!/usr/bin/env bash
# Put the repo's personal CLI tools on $PATH.
#
# Everything in <repo>/bin/ is symlinked into ~/.local/bin, plus the short
# aliases in ALIASES below. Deliberately NOT a stow package: ~/.local/bin is
# shared with other installers (goat's install.sh links goat-img, goat-lint,
# goat-keys and goat-logo there), and stow would fold the whole directory into
# a symlink pointing back into this repo, so those tools would end up being
# written into the dotfiles checkout.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

SRC="$DOTFILES_DIR/bin"
LOCALBIN="$HOME/.local/bin"

# Short aliases: "<link> <target>" pairs.
ALIASES=(
    "gm goat-manager"
)

[ -d "$SRC" ] || { warn "no bin/ directory in $DOTFILES_DIR, skipping."; exit 0; }

run mkdir -p "$LOCALBIN"

for tool in "$SRC"/*; do
    [ -f "$tool" ] || continue
    name="$(basename "$tool")"
    run chmod +x "$tool"
    run ln -sfn "$tool" "$LOCALBIN/$name"
    ok "$name -> $LOCALBIN/$name"
done

for pair in "${ALIASES[@]}"; do
    link="${pair%% *}"; target="${pair##* }"
    if [ -e "$SRC/$target" ]; then
        # Relative link so it keeps working if $HOME moves.
        run ln -sfn "$target" "$LOCALBIN/$link"
        ok "$link -> $target"
    fi
done

# The PATH entry itself comes from the stowed bash/.bashrc; warn when this
# shell has not picked it up yet (a fresh install, before re-login).
case ":$PATH:" in
    *":$LOCALBIN:"*) ;;
    *) warn "$LOCALBIN is not on \$PATH in this shell. Run 'make stow' and"
       warn "open a new terminal (or: source ~/.bashrc)." ;;
esac
