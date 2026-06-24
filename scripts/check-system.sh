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
    svc_enabled "$dm.service" && pass "$dm enabled"
done

log "GPU / microcode (GPU=$(cfg GPU amd))"
check_pkg amd-ucode
case "$(cfg GPU amd)" in
    amd)   check_pkg vulkan-radeon ;;
    intel) check_pkg vulkan-intel ;;
    nvidia|hybrid) check_pkg nvidia-utils ;;
esac

if enabled LAPTOP; then
    log "Laptop extras"
    check_svc tlp.service
    check_cmd brightnessctl
    [ -f /etc/X11/xorg.conf.d/30-touchpad.conf ] && pass "touchpad config present" || miss "touchpad config missing"
fi

if enabled INSTALL_DEV; then
    log "Dev toolchains"
    check_cmd docker
    svc_active docker.service && pass "docker active" || note "docker not active"
    id -nG "$USER" | grep -qw docker && pass "user in docker group" || note "user not in docker group (re-login)"
    for c in gcc javac python; do check_cmd "$c"; done
fi

log "Dotfiles symlinks"
for pkg_name in $(cfg STOW_PACKAGES "awesome nvim tmux alacritty fontconfig"); do
    case "$pkg_name" in
        awesome)   target="$HOME/.config/awesome" ;;
        nvim)      target="$HOME/.config/nvim" ;;
        tmux)      target="$HOME/.config/tmux" ;;
        alacritty) target="$HOME/.config/alacritty" ;;
        fontconfig)target="$HOME/.config/fontconfig/fonts.conf" ;;
        bash)      target="$HOME/.bashrc" ;;
        rclone)    target="$HOME/.config/systemd/user/protondrive.service" ;;
        clang-format) target="$HOME/.clang-format" ;;
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
