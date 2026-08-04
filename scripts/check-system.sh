#!/usr/bin/env bash
# Read-only health check: verifies the dotfiles install set things up correctly
# (packages, services, audio, symlinks). Makes no changes.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

fails=0

pass() { printf "  ${C_GREEN}\xe2\x9c\x93${C_RESET} %s\n" "$*"; }
miss() { printf "  ${C_RED}\xe2\x9c\x97${C_RESET} %s\n" "$*"; fails=$((fails + 1)); }
note() { printf "  ${C_YELLOW}-${C_RESET} %s\n" "$*"; }

have()        { command -v "$1" >/dev/null 2>&1; }
pkg()         { pacman -Q "$1" >/dev/null 2>&1; }
svc_enabled() { systemctl is-enabled --quiet "$1" 2>/dev/null; }
svc_active()  { systemctl is-active  --quiet "$1" 2>/dev/null; }
usvc_active() { systemctl --user is-active --quiet "$1" 2>/dev/null; }

check_cmd() { if have "$1"; then pass "$1 present"; else miss "$1 missing"; fi; }
check_pkg() { if pkg "$1"; then pass "$1 installed"; else miss "$1 not installed"; fi; }
check_svc() {
    if svc_active "$1"; then pass "$1 active"
    elif svc_enabled "$1"; then note "$1 enabled (not active yet — reboot?)"
    else miss "$1 not enabled"; fi
}

log "Networking"
check_cmd nmcli
check_svc NetworkManager.service

log "Audio (pipewire, user services)"
check_cmd pactl
if usvc_active pipewire; then pass "pipewire (user) active"; else miss "pipewire (user) not active"; fi
if usvc_active wireplumber; then pass "wireplumber (user) active"; else note "wireplumber not active"; fi

log "Bluetooth"
check_svc bluetooth.service

log "Firewall & mirrors"
if have ufw; then
    if sudo -n ufw status 2>/dev/null | grep -qi "Status: active"; then pass "ufw active"
    else note "ufw installed (status needs sudo or not active)"; fi
else miss "ufw missing"; fi
if svc_enabled reflector.timer; then pass "reflector.timer enabled"; else note "reflector.timer not enabled"; fi

log "Display manager"
for dm in lightdm sddm ly; do
    svc_enabled "$dm.service" || continue
    # "enabled" alone hides the common failure: the unit is enabled but crashed
    # on boot, so VT1 is black. Check that it actually came up.
    if svc_active "$dm.service"; then pass "$dm enabled and active"
    else miss "$dm enabled but NOT active (journalctl -b -u $dm)"; fi
done
# LightDM needs org.freedesktop.Accounts at startup or it exits immediately.
if svc_enabled lightdm.service; then
    check_pkg accountsservice
    [ -d /usr/share/xsessions ] && [ -n "$(ls -A /usr/share/xsessions 2>/dev/null)" ] \
        && pass "xsessions present ($(ls /usr/share/xsessions | tr '\n' ' '))" \
        || miss "no sessions in /usr/share/xsessions — greeter will have nothing to launch"
    # Screen lock (Super+Escape / 5 min idle) locks to the lightdm greeter.
    check_pkg light-locker
    [ -f /etc/lightdm/lightdm-gtk-greeter.conf ] \
        && pass "greeter config deployed" \
        || note "greeter config not deployed yet (make services)"
fi

log "Desktop extras"
check_pkg cava
check_pkg xclip
check_pkg playerctl
# wallpaper-prep.sh shells out to 'magick', not 'convert': ImageMagick 7 renamed
# the entry point, so check the binary too — a v6 leftover satisfies the package
# check but leaves the script falling back to unprocessed wallpapers.
check_pkg imagemagick
check_cmd magick
check_pkg breeze
check_pkg plasma-integration
if grep -q '^QT_QPA_PLATFORMTHEME=kde$' /etc/environment 2>/dev/null; then
    pass "QT_QPA_PLATFORMTHEME=kde set in /etc/environment"
else
    miss "QT_QPA_PLATFORMTHEME=kde not in /etc/environment (make apps, then re-login)"
fi
# Optional -git theme packages: note, never fail — everything degrades.
for d in /usr/share/icons/candy-icons /usr/share/icons/Sweet-cursors /usr/share/themes/Sweet-Dark; do
    [ -d "$d" ] && pass "$(basename "$d") present" || note "$(basename "$d") missing (falls back)"
done
if have kreadconfig6; then
    kde_icons="$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null)"
    [ -n "$kde_icons" ] && pass "kdeglobals icon theme: $kde_icons" \
        || note "kdeglobals has no icon theme yet (make apps)"
fi
if enabled INSTALL_VPN; then check_pkg proton-vpn-gtk-app; fi

log "Wallpaper pipeline"
# wallpaper-prep.sh is stowed with the awesome package and post-processes the
# raw band images before feh sets them. It is new in the rice upgrade, so a
# missing file only means "not stowed yet" — not breakage.
wp_prep="$HOME/.config/awesome/scripts/wallpaper-prep.sh"
if [ ! -e "$wp_prep" ]; then
    note "wallpaper-prep.sh not deployed yet ($wp_prep — make stow)"
elif [ ! -x "$wp_prep" ]; then
    # Stow keeps the repo file's mode, so a non-executable link means the repo
    # copy lost +x, and rc.lua's awful.spawn of it fails silently at login.
    miss "wallpaper-prep.sh present but not executable ($wp_prep)"
else
    pass "wallpaper-prep.sh present and executable"
fi
# Source images for the rotation (and thus for the prep cache). rc.lua kicks off
# wallpaper-fetch-bands.sh when the folder is empty, so empty is not breakage.
wp_src="$HOME/Media/wallpapers/bands"
wp_count=$(find "$wp_src" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l)
if [ "$wp_count" -gt 0 ]; then
    pass "wallpaper source populated ($wp_count images in ~/Media/wallpapers/bands)"
else
    note "no wallpapers in ~/Media/wallpapers/bands yet (fetched on first login)"
fi
# Prep cache, filled lazily on the first rotation and keyed by source+mtime+
# resolution+pipeline version, so an absent or empty dir is normal on a fresh
# machine and never a failure. Deliberately counts files instead of looking for
# specific names — the key scheme is the prep script's business, not ours.
wp_cache="${XDG_CACHE_HOME:-$HOME/.cache}/lukasawesome/wallpapers"
if [ -d "$wp_cache" ]; then
    note "wallpaper prep cache: $(find "$wp_cache" -maxdepth 1 -type f 2>/dev/null | wc -l) cached image(s) in $wp_cache"
else
    note "wallpaper prep cache not created yet (populated on first wallpaper rotation)"
fi

log "Xorg config snippets"
# One truncated snippet aborts the whole X server, so validate every file, not
# just the ones this repo writes.
shopt -s nullglob
xorg_snippets=(/etc/X11/xorg.conf.d/*.conf)
shopt -u nullglob
if [ "${#xorg_snippets[@]}" -eq 0 ]; then
    note "no snippets in /etc/X11/xorg.conf.d"
else
    for snippet in "${xorg_snippets[@]}"; do
        if xorg_conf_valid "$snippet"; then pass "$(basename "$snippet") parses"
        else miss "$(basename "$snippet") is malformed — Xorg will refuse to start"; fi
    done
fi

log "GPU / microcode (GPU=$(cfg GPU amd))"
# Microcode follows the actual CPU, not the GPU flag — this box is an Intel CPU
# with an AMD GPU, and the old hardcoded amd-ucode check failed forever on it.
case "$(grep -m1 '^vendor_id' /proc/cpuinfo | awk '{print $3}')" in
    GenuineIntel) check_pkg intel-ucode ;;
    AuthenticAMD) check_pkg amd-ucode ;;
    *)            note "unknown CPU vendor — skipping microcode check" ;;
esac
case "$(cfg GPU amd)" in
    amd)   check_pkg vulkan-radeon ;;
    intel) check_pkg vulkan-intel ;;
    nvidia|hybrid) check_pkg nvidia-utils ;;
esac

if enabled LAPTOP; then
    log "Laptop extras"
    check_svc tlp.service
    check_cmd brightnessctl
    if xorg_conf_valid /etc/X11/xorg.conf.d/30-touchpad.conf; then pass "touchpad config present and valid"
    elif [ -f /etc/X11/xorg.conf.d/30-touchpad.conf ]; then miss "touchpad config present but malformed"
    else miss "touchpad config missing"; fi
fi

if enabled INSTALL_DEV; then
    log "Dev toolchains"
    check_cmd docker
    svc_active docker.service && pass "docker active" || note "docker not active"
    id -nG "$USER" | grep -qw docker && pass "user in docker group" || note "user not in docker group (re-login)"
    for c in gcc javac python; do check_cmd "$c"; done
fi

log "Dotfiles symlinks"
for pkg_name in $(cfg STOW_PACKAGES "awesome nvim tmux alacritty fontconfig bash rclone clang-format cava qt applications"); do
    case "$pkg_name" in
        awesome)   target="$HOME/.config/awesome" ;;
        nvim)      target="$HOME/.config/nvim" ;;
        tmux)      target="$HOME/.config/tmux" ;;
        alacritty) target="$HOME/.config/alacritty" ;;
        fontconfig)target="$HOME/.config/fontconfig/fonts.conf" ;;
        bash)      target="$HOME/.bashrc" ;;
        rclone)    target="$HOME/.config/systemd/user/protondrive.service" ;;
        clang-format) target="$HOME/.clang-format" ;;
        cava)      target="$HOME/.config/cava" ;;
        qt)        target="$HOME/.local/share/color-schemes/Dr460nized.colors" ;;
        applications) target="$HOME/.local/share/applications/awesome-power.desktop" ;;
        *)         target="" ;;
    esac
    [ -z "$target" ] && continue
    if [ -L "$target" ] && readlink -f "$target" | grep -q "$DOTFILES_DIR"; then
        pass "$pkg_name -> repo"
    elif [ -e "$target" ]; then
        note "$pkg_name exists but is not a symlink into the repo"
    else
        miss "$pkg_name not linked ($target)"
    fi
done

echo
if [ "$fails" -eq 0 ]; then
    ok "All critical checks passed."
else
    err "$fails critical check(s) failed — see ✗ above."
    exit 1
fi
