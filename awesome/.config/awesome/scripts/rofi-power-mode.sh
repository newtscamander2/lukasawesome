#!/usr/bin/env bash
# rofi *script mode* listing session/power actions, so they appear as ordinary
# entries in the Super+R launcher — right after the apps — instead of living in
# a separate menu you have to search.
#
# rofi calls this script twice:
#   1. with no arguments  -> print one entry per line (the menu)
#   2. with the chosen line as $1 -> perform it
# ROFI_RETV/ROFI_INFO are set by rofi; we only need $1.
#
# Wired up in rc.lua as:
#   rofi -show combi -modes combi -combi-modes "drun,power:<this script>"
set -euo pipefail

# Destructive actions confirm first: these sit in the same list as your apps, so
# a stray Enter must not be able to power the machine off.
confirm() {
    local action="$1" theme
    theme="$HOME/.config/awesome/themes/$(cat "$HOME/.config/awesome/active_theme" 2>/dev/null || echo arch)"
    theme="$theme/rofi-$(basename "$theme").rasi"
    [ -r "$theme" ] || theme="$HOME/.config/awesome/themes/arch/rofi-arch.rasi"
    printf 'No, cancel\nYes, %s now\n' "$action" \
        | rofi -dmenu -i -p "$action?" -theme "$theme" \
               -theme-str 'window { width: 420px; height: 220px; } listview { columns: 1; lines: 2; } element-icon { size: 0px; } element-text { horizontal-align: 0; }' \
        | grep -q '^Yes'
}

case "${1:-}" in
    "")
        # Nerd-font glyphs match the wibar/launcher iconography.
        printf '  Lock screen\n'
        printf '  Log out\n'
        printf '  Suspend\n'
        printf '  Reboot\n'
        printf '  Power off\n'
        ;;
    *"Lock screen") light-locker-command -l 2>/dev/null || dm-tool lock ;;
    *"Log out")     confirm "Log out"   && awesome-client 'awesome.quit()' ;;
    *"Suspend")     systemctl suspend ;;
    *"Reboot")      confirm "Reboot"    && systemctl reboot ;;
    *"Power off")   confirm "Power off" && systemctl poweroff ;;
esac
