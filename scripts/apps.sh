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

# --- Qt apps (Dolphin, KeePassXC…): platform theme + colours + icons ---
# Without QT_QPA_PLATFORMTHEME=kde, KF6 apps never load the KDE platform theme
# and so never read kdeglobals — Dolphin renders stock light Breeze no matter
# what colours are configured (verified the hard way: with qt5ct the icon theme
# applied but the palette did not).
# /etc/environment is the right home for the variable: pam_env applies it at
# every login (lightdm AND a bare startx), so awesome and everything it spawns
# inherit it. A file under ~/.config/environment.d would only reach systemd
# *user* services, i.e. not a rofi-launched Dolphin. Needs one logout/login.
if enabled INSTALL_BASE; then
    if grep -q '^QT_QPA_PLATFORMTHEME=kde$' /etc/environment 2>/dev/null; then
        ok "QT_QPA_PLATFORMTHEME=kde already set in /etc/environment."
    else
        log "Setting QT_QPA_PLATFORMTHEME=kde in /etc/environment (login-wide)"
        # Rewrite any other value rather than appending a second one.
        run_sh "sudo sed -i '/^QT_QPA_PLATFORMTHEME=/d' /etc/environment && \
                echo 'QT_QPA_PLATFORMTHEME=kde' | sudo tee -a /etc/environment >/dev/null"
    fi

    # With the KDE platform theme active, Dolphin takes its colours from
    # kdeglobals [Colors:*] and its icons from [Icons]. kdeglobals is live user
    # state (KDE apps rewrite it), so it is deliberately NOT stowed: back it up
    # once, then merge the scheme in and set the individual keys.
    kde="$HOME/.config/kdeglobals"
    if [ ! -f "$kde" ]; then
        run_sh "mkdir -p '$HOME/.config' && touch '$kde'"
    fi
    run cp -n "$kde" "$kde.pre-theme" 2>/dev/null || true

    # The Dr460nized KDE colour scheme ships in this repo (stowed to
    # ~/.local/share/color-schemes). Merging its [Colors:*] into kdeglobals is
    # what actually recolours Dolphin — the ColorScheme key alone is only a
    # label that KDE's own settings app would act on.
    scheme="$HOME/.local/share/color-schemes/Dr460nized.colors"
    if [ -r "$scheme" ] && [ "$DRY_RUN" != "1" ]; then
        log "Merging the Dr460nized colour scheme into kdeglobals"
        python3 - "$scheme" "$kde" <<'PY'
import configparser, sys
src_path, dst_path = sys.argv[1], sys.argv[2]
def load(p):
    c = configparser.RawConfigParser(strict=False)
    c.optionxform = str
    c.read(p)
    return c
src, dst = load(src_path), load(dst_path)
for sec in src.sections():
    if sec.startswith("Colors:") or sec == "WM":
        if not dst.has_section(sec):
            dst.add_section(sec)
        for k, v in src.items(sec):
            dst.set(sec, k, v)
with open(dst_path, "w") as fh:
    dst.write(fh, space_around_delimiters=False)
PY
    elif [ ! -r "$scheme" ]; then
        warn "Dr460nized.colors not found — run 'make stow' first, then re-run 'make apps'."
    fi

    if command -v kwriteconfig6 >/dev/null 2>&1; then
        icon_theme="Papirus-Dark"
        [ -d /usr/share/icons/candy-icons ] && icon_theme="candy-icons"
        log "Setting kdeglobals: style=Breeze, icons=$icon_theme"
        # Breeze honours the KDE colour scheme completely; there is no Sweet
        # Kvantum theme in the AUR, so Kvantum would add nothing here.
        run kwriteconfig6 --file kdeglobals --group KDE     --key widgetStyle Breeze
        run kwriteconfig6 --file kdeglobals --group Icons   --key Theme "$icon_theme"
        [ -r "$scheme" ] && run kwriteconfig6 --file kdeglobals --group General --key ColorScheme Dr460nized
    else
        warn "kwriteconfig6 missing — install kconfig or set kdeglobals by hand."
    fi
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
