#!/usr/bin/env bash
# Recover a broken graphical login from a TTY: get LightDM + AwesomeWM back to
# a working state. Written for the case where you boot to a black VT1 and can
# only reach a console with Ctrl+Alt+F2.
#
# Safe to re-run. Every file it touches is backed up first, and it never
# deletes anything. Run with DRY_RUN=1 to see what it would do.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

STAMP="$(date +%Y%m%d-%H%M%S)"
fixed=0
broken=0

fix()  { printf "  ${C_GREEN}fixed${C_RESET} %s\n" "$*"; fixed=$((fixed + 1)); }
bad()  { printf "  ${C_RED}x${C_RESET} %s\n" "$*"; broken=$((broken + 1)); }
good() { printf "  ${C_GREEN}ok${C_RESET} %s\n" "$*"; }

require_arch

if [ "$DRY_RUN" != "1" ]; then
    log "Asking for sudo up front so nothing stalls half-way"
    sudo -v || { err "This script needs sudo."; exit 1; }
fi

# --- 1. Packages a graphical login cannot start without ---------------------
# accountsservice is not a pacman dependency of lightdm but is required at
# runtime; without it LightDM cannot enumerate users.
log "Checking required packages"
missing=()
for p in xorg-server awesome lightdm lightdm-gtk-greeter accountsservice; do
    pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
done
if [ "${#missing[@]}" -gt 0 ]; then
    warn "Missing: ${missing[*]}"
    pac_install "${missing[@]}"
    fix "installed ${missing[*]}"
else
    good "all required packages present"
fi

# --- 2. Xorg config snippets ------------------------------------------------
# A single malformed snippet aborts the entire X server ("no screens found"),
# which takes LightDM down with it. Repair a missing EndSection when that is
# demonstrably the whole problem; otherwise park the file out of the way so X
# can start, and leave it for the user to inspect.
log "Validating /etc/X11/xorg.conf.d snippets"
shopt -s nullglob
snippets=(/etc/X11/xorg.conf.d/*.conf)
shopt -u nullglob
if [ "${#snippets[@]}" -eq 0 ]; then
    good "no snippets to check"
fi
for f in "${snippets[@]}"; do
    base="$(basename "$f")"
    if xorg_conf_valid "$f"; then
        good "$base"
        continue
    fi

    warn "$base is malformed — Xorg will refuse to start"

    # Build the repaired version in a temp file and validate it there. Only a
    # single unterminated trailing section is safely auto-repairable, and the
    # validator is the judge of that — a file can look balanced by keyword
    # count while still being structurally invalid.
    candidate="$(mktemp)"
    cat "$f" >"$candidate"
    printf 'EndSection\n' >>"$candidate"

    if xorg_conf_valid "$candidate"; then
        run_sh "sudo cp -a '$f' '$f.bak-$STAMP'"
        run_sh "sudo cp '$candidate' '$f'"
        fix "$base — appended missing EndSection (backup: $base.bak-$STAMP)"
    else
        # Not auto-repairable. Getting back to a desktop beats preserving a
        # file that cannot load anyway; Xorg reads only *.conf, so renaming
        # neutralises it with no data lost.
        run_sh "sudo mv '$f' '$f.broken-$STAMP'"
        fix "$base — not auto-repairable, moved aside as $base.broken-$STAMP"
    fi
    rm -f "$candidate"
done

# --- 3. A session for the greeter to launch ---------------------------------
log "Checking the Awesome session entry"
if [ -f /usr/share/xsessions/awesome.desktop ]; then
    good "awesome.desktop present"
else
    bad "/usr/share/xsessions/awesome.desktop missing — reinstall the awesome package"
fi

# --- 4. Awesome's own config ------------------------------------------------
# A broken rc.lua does not stop LightDM, but it drops you straight back to the
# greeter after login, which looks like a login failure.
log "Checking ~/.config/awesome"
if [ -e "$HOME/.config/awesome/rc.lua" ]; then
    good "rc.lua present"
else
    warn "rc.lua missing — restowing the awesome package"
    run bash "$(dirname "${BASH_SOURCE[0]}")/stow.sh"
    fix "restowed dotfiles"
fi
if [ -e "$HOME/.config/awesome/rc.lua" ] && command -v awesome >/dev/null 2>&1; then
    if awesome -k >/dev/null 2>&1; then
        good "rc.lua passes awesome's config check"
    else
        bad "rc.lua has a syntax error — run 'awesome -k' to see it"
        warn "Awesome will fail to start and bounce you back to the greeter."
    fi
fi

# --- 5. Display manager wiring ----------------------------------------------
log "Checking the display manager"
if [ "$(systemctl get-default)" != "graphical.target" ]; then
    warn "default target is $(systemctl get-default), not graphical.target"
    run sudo systemctl set-default graphical.target
    fix "set default target to graphical.target"
else
    good "default target is graphical.target"
fi

dm_link="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
if [ "$dm_link" != "/usr/lib/systemd/system/lightdm.service" ]; then
    warn "display-manager.service points at '${dm_link:-nothing}'"
    run sudo systemctl enable lightdm.service
    fix "enabled lightdm as the display manager"
else
    good "lightdm is the enabled display manager"
fi

# --- 6. Restart and verify --------------------------------------------------
# reset-failed matters: after 5 crashes in 10s systemd refuses further starts
# with "start request repeated too quickly" until the counter is cleared.
log "Restarting LightDM"
run sudo systemctl reset-failed lightdm.service
run sudo systemctl restart lightdm.service

if [ "$DRY_RUN" = "1" ]; then
    ok "Dry run complete — nothing was changed."
    exit 0
fi

sleep 3
echo
if systemctl is-active --quiet lightdm.service; then
    ok "LightDM is running. Switch to Ctrl+Alt+F1 and log in to Awesome."
    [ "$fixed" -gt 0 ] && warn "$fixed item(s) were repaired — consider rerunning 'make check-system'."
    exit 0
fi

err "LightDM is still not running. The last errors were:"
echo
sudo tail -n 25 /var/log/lightdm/lightdm.log 2>/dev/null || true
echo
err "X server log:"
sudo tail -n 25 /var/log/lightdm/x-0.log 2>/dev/null || true
echo
err "Report the above. Nothing further is auto-repairable."
exit 1
