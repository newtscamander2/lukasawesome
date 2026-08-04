#!/usr/bin/env bash
# Rofi power menu (Super+Escape / the "Power…" entry in the Super+R launcher).
# Destructive actions ask for confirmation first, so a fuzzy search that lands
# on "Power off" can't take the machine down on a single Enter.
set -euo pipefail

THEME="$HOME/.config/awesome/themes/$(cat "$HOME/.config/awesome/active_theme" 2>/dev/null || echo arch)"
THEME_FILE="$THEME/rofi-$(basename "$THEME").rasi"
[ -r "$THEME_FILE" ] || THEME_FILE="$HOME/.config/awesome/themes/arch/rofi-arch.rasi"

menu() { rofi -dmenu -i -p "$1" -theme "$THEME_FILE" -theme-str 'window { width: 420px; height: 340px; } listview { columns: 1; lines: 6; } element-icon { size: 0px; } element-text { horizontal-align: 0; }'; }

confirm() {
    printf 'No, cancel\nYes, %s\n' "$1" | menu "$1?" | grep -q '^Yes'
}

choice="$(printf '  Lock screen\n  Log out\n  Suspend\n  Reboot\n  Power off\n' | menu 'Power')"

case "$choice" in
    *"Lock screen") light-locker-command -l 2>/dev/null || dm-tool lock ;;
    *"Log out")     confirm "Log out"  && awesome-client 'awesome.quit()' ;;
    *"Suspend")     systemctl suspend ;;
    *"Reboot")      confirm "Reboot"   && systemctl reboot ;;
    *"Power off")   confirm "Power off" && systemctl poweroff ;;
esac
