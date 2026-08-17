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
for pkg_name in $(cfg STOW_PACKAGES "awesome nvim tmux alacritty fontconfig bash rclone clang-format cava qt notes keepassxc flameshot"); do
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
        notes)     target="$HOME/.config/systemd/user/goat-autosave.timer" ;;
        keepassxc) target="$HOME/.config/systemd/user/keepassxc-sync.timer" ;;
        flameshot) target="$HOME/.config/flameshot/flameshot.ini" ;;
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

log "Personal CLI tools (~/.local/bin)"
case ":$PATH:" in
    *":$HOME/.local/bin:"*) pass "~/.local/bin on \$PATH" ;;
    # Not critical: the PATH entry comes from the stowed .bashrc, so it only
    # shows up in shells started after 'make stow'.
    *) note "~/.local/bin not on \$PATH in this shell (open a new terminal)" ;;
esac
for tool in "$DOTFILES_DIR"/bin/*; do
    [ -f "$tool" ] || continue
    name="$(basename "$tool")"
    if [ -L "$HOME/.local/bin/$name" ]; then
        pass "$name linked"
    else
        miss "$name not linked (run 'make bin')"
    fi
done

# --- KeePassXC: is the database syncing, and is it out of git? ----------------
KP_LOCAL="$(cfg KEEPASS_LOCAL_DIR "$HOME/KeePassXC")"
if [ -d "$KP_LOCAL" ]; then
    echo
    log "KeePassXC ($KP_LOCAL)"
    if [ -n "$(find "$KP_LOCAL" -maxdepth 1 -name '*.kdbx' -print -quit 2>/dev/null)" ]; then
        pass "database present"
    else
        miss "no .kdbx in $KP_LOCAL"
    fi
    if systemctl --user is-active --quiet keepassxc-sync.timer; then
        pass "keepassxc-sync.timer active (every 15 min)"
    else
        miss "keepassxc-sync.timer not running (run 'make keepassxc')"
    fi
    # A blocked sync is silent unless something looks for it.
    if tail -40 "${XDG_STATE_HOME:-$HOME/.local/state}/keepassxc-sync.log" 2>/dev/null \
            | grep -q "too many deletes"; then
        miss "the sync is BLOCKED by a refused deletion"
        note "  bash ~/lukasawesome/scripts/keepassxc-sync.sh allow-delete"
    else
        pass "sync not blocked"
    fi
    if find "$KP_LOCAL" -maxdepth 1 -name '*conflict*' -print -quit 2>/dev/null | grep -q .; then
        miss "conflict files present — both versions were kept, merge them"
        note "  bash ~/lukasawesome/scripts/keepassxc-sync.sh status"
    else
        pass "no sync conflicts"
    fi
fi

# The one that must never be true: a password database inside a repository.
if find "$DOTFILES_DIR" "$HOME/aarhusuni" "$HOME/projects" -name '*.kdbx' \
        -not -path '*/.git/*' -print -quit 2>/dev/null | grep -q .; then
    miss "A .kdbx FILE IS INSIDE A GIT WORKING TREE — remove it before committing"
    find "$DOTFILES_DIR" "$HOME/aarhusuni" "$HOME/projects" -name '*.kdbx' \
        -not -path '*/.git/*' 2>/dev/null | sed 's/^/       /'
else
    pass "no password database inside any repository"
fi

# --- University notes: is the safety net actually running? --------------------
# This block exists because it once was not. A stow change turned
# ~/.config/systemd/user/sockets.target.wants into a symlink, systemd stopped
# honouring it, ssh-agent never started at boot, and every snapshot push failed
# for hours -- visible only to someone who ran 'gm --pending' and read it. A
# backup you have to remember to check is not a backup.
NOTES="$(cfg NOTES_DIR "$HOME/aarhusuni")"
if [ -d "$NOTES/.bare" ]; then
    echo
    log "University notes ($NOTES)"

    if systemctl --user is-enabled --quiet goat-autosave.timer 2>/dev/null; then
        if usvc_active goat-autosave.timer; then
            pass "goat-autosave.timer active (snapshots every 5 min)"
        else
            miss "goat-autosave.timer enabled but not running"
        fi
    else
        miss "goat-autosave.timer not enabled (run 'make notes')"
    fi

    # The deploy key is what makes unattended pushes possible at all: no
    # passphrase, scoped to this one project. If it works, the agent does not
    # matter for snapshots, so check it first and only fall back to asking
    # about the agent.
    NS="$(cfg GITLAB_NAMESPACE newtscamander)"
    PROJ="$(cfg NOTES_PROJECT aarhusuni)"
    KEY="$(cfg NOTES_DEPLOY_KEY "$HOME/.ssh/id_ed25519_${PROJ}")"
    if [ -f "$KEY" ]; then
        pass "deploy key present ($(basename "$KEY"))"
        if GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10" \
                git ls-remote --heads "git@gitlab.com:${NS}/${PROJ}.git" >/dev/null 2>&1; then
            pass "deploy key is registered — snapshots push unattended"
        else
            miss "deploy key is not registered on ${PROJ}"
            note "  https://gitlab.com/${NS}/${PROJ}/-/settings/repository -> Deploy keys"
            note "  (tick 'Grant write permissions'), then: make notes"
            if SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket" \
                    ssh-add -l >/dev/null 2>&1; then
                note "  meanwhile the agent holds a key, so pushes work by hand"
            else
                note "  and the agent holds no key, so nothing can push at all"
            fi
        fi
    else
        miss "no deploy key — run 'make notes' to create one"
    fi

    # The socket, not just the agent: a socket that is disabled will not come
    # back after a boot, which is how the backups once stopped for hours.
    if systemctl --user is-enabled --quiet ssh-agent.socket 2>/dev/null; then
        pass "ssh-agent.socket enabled"
    else
        miss "ssh-agent.socket not enabled"
        note "  systemctl --user enable --now ssh-agent.socket"
    fi

    # The last word on whether it is working: what gm itself thinks.
    if have gm; then
        if gm --pending 2>/dev/null | grep -q "push failed"; then
            miss "a snapshot push has failed — run 'gm --pending' for the reason"
        else
            pass "no failed snapshot pushes"
        fi
    fi
fi

echo
if [ "$fails" -eq 0 ]; then
    ok "All critical checks passed."
else
    err "$fails critical check(s) failed — see ✗ above."
    exit 1
fi
