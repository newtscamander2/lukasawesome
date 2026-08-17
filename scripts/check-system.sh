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
    # Without this the greeter's X server DPMS-offs the monitor after 10 min
    # locked, and amdgpu (RX 7600) may never relight it — reboot-only black.
    [ -f /etc/lightdm/lightdm.conf.d/50-no-dpms.conf ] \
        && pass "lightdm no-DPMS conf deployed" \
        || miss "50-no-dpms.conf not deployed — locked screen can black-hole on amdgpu (make services)"
fi

log "Desktop extras"
check_pkg cava
# One cava is correct while audio plays; more than one means the visualizer's
# process tracking has drifted from reality. This reached 131 processes once,
# dragging awesome to 15GB RSS, because cava ignores SIGTERM and the old code
# assumed the kill had worked.
# pgrep -c prints "0" AND exits 1 when nothing matches, so '|| echo 0' fired on
# top of the 0 it had already printed and cava_n became the two-line string
# $'0\n0' -- which [ -gt ] rejects with "integer expected". Take the count and
# only substitute on a non-zero exit.
cava_n=$(pgrep -xc cava 2>/dev/null) || cava_n=0
if [ "$cava_n" -gt 1 ]; then
    miss "$cava_n cava processes running (expected 0 or 1) — run: pkill -9 -x cava"
elif [ "$cava_n" -eq 1 ]; then
    pass "cava: 1 process (visualizer running)"
else
    note "cava not running (only runs while audio plays and the desktop is visible)"
fi
check_pkg xclip
check_pkg playerctl
# Clipboard history (Super+V). The package alone proves nothing: greenclip only
# records while its daemon runs, so an installed-but-dead daemon means Super+V
# opens an empty list forever. rc.lua spawns it at login, so "not running" on a
# machine that has not re-logged in since install is expected, not breakage.
check_pkg rofi-greenclip
if pgrep -x greenclip >/dev/null 2>&1; then
    pass "greenclip daemon running (clipboard history recording)"
else
    note "greenclip daemon not running (started by rc.lua at login — re-login or restart awesome)"
fi
# The history file is PLAINTEXT on disk, so a missing blacklist means KeePassXC
# copies get recorded. Treat that as a real failure, not a note.
if [ -r "$HOME/.config/greenclip.toml" ]; then
    if grep -qi 'blacklisted_applications.*keepassxc' "$HOME/.config/greenclip.toml"; then
        pass "greenclip blacklists KeePassXC (passwords not recorded)"
    else
        miss "greenclip.toml does NOT blacklist KeePassXC — passwords would be stored in plaintext"
    fi
else
    note "greenclip.toml not deployed yet (make stow)"
fi
clip_menu="$HOME/.config/awesome/scripts/clipboard-menu.sh"
if [ ! -e "$clip_menu" ]; then
    note "clipboard-menu.sh not deployed yet ($clip_menu — make stow)"
elif [ ! -x "$clip_menu" ]; then
    # Stow preserves the repo file's mode, so a non-executable link means the
    # repo copy lost +x and the Super+V keybinding fails silently.
    miss "clipboard-menu.sh present but not executable ($clip_menu)"
else
    pass "clipboard-menu.sh present and executable"
fi
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
for pkg_name in $(cfg STOW_PACKAGES "awesome nvim tmux alacritty fontconfig bash rclone clang-format cava qt greenclip notes keepassxc flameshot"); do
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
        greenclip) target="$HOME/.config/greenclip.toml" ;;
        notes)     target="$HOME/.config/systemd/user/goat-autosave.timer" ;;
        keepassxc) target="$HOME/.config/systemd/user/keepassxc-sync.timer" ;;
        flameshot) target="$HOME/.config/flameshot/flameshot.ini" ;;
        *)         target="" ;;
    esac
    [ -z "$target" ] && continue
    # Test where the path LANDS, not whether its last component is a symlink.
    # stow folds a package into a single directory link whenever it is the only
    # owner of that directory, so ~/.config/flameshot is the symlink and the
    # flameshot.ini inside it is an ordinary file -- correctly linked, but
    # [ -L ] on the file says no. fontconfig, qt and flameshot all reported
    # "exists but is not a symlink into the repo" while being perfectly stowed,
    # which is worse than no check: it teaches you to ignore the output.
    #
    # realpath -m resolves symlinks anywhere along the path and does not require
    # the file to exist, so one comparison covers both folded and unfolded
    # packages. The old readlink|grep also matched DOTFILES_DIR anywhere in the
    # resolved path rather than at the front.
    if [ -e "$target" ] && [[ "$(realpath -m "$target" 2>/dev/null)" == "$DOTFILES_DIR"/* ]]; then
        pass "$pkg_name -> repo"
    elif [ -e "$target" ]; then
        note "$pkg_name exists but does not resolve into the repo"
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
