#!/usr/bin/env bash
# Rofi clipboard history (Super+V). greenclip's daemon watches the X CLIPBOARD
# selection and records every change; this lists the history, lets you pick an
# entry, and puts that entry back on the clipboard ready to paste.
#
# Passwords: greenclip writes its own config to ~/.config/greenclip.toml on
# first run, and 'blacklisted_applications' there is a list of WM_CLASS names
# whose copies are never recorded. It defaults to [] — set it to
# ["keepassxc"] to keep vault entries out of ~/.cache/greenclip.history, which
# is an on-disk file (mode 0600, but still plaintext to anything running as you).
set -euo pipefail

THEME="$HOME/.config/awesome/themes/$(cat "$HOME/.config/awesome/active_theme" 2>/dev/null || echo arch)"
THEME_FILE="$THEME/rofi-$(basename "$THEME").rasi"
[ -r "$THEME_FILE" ] || THEME_FILE="$HOME/.config/awesome/themes/arch/rofi-arch.rasi"

# Wider than the power menu — entries are lines of text, not one-word verbs.
# '-format i' makes rofi return the index of the chosen line in the input list
# instead of the line itself, which is what lets the list show a shortened
# label while we copy back the full, unmodified value.
menu() { rofi -dmenu -i -p "$1" -format i -theme "$THEME_FILE" -theme-str 'window { width: 820px; height: 420px; } listview { columns: 1; lines: 10; } element-icon { size: 0px; } element-text { horizontal-align: 0; }'; }

# Truncation width for the DISPLAYED label only, never for the value that goes
# back on the clipboard — silently copying a cut-off URL or command is the kind
# of bug you only notice after pasting it somewhere that matters.
MAX_DISPLAY=110

err_menu() { rofi -e "$1" -theme "$THEME_FILE"; }

if ! command -v greenclip >/dev/null 2>&1; then
    err_menu "greenclip is not installed — run 'make packages' (AUR: rofi-greenclip)."
    exit 1
fi

# rc.lua starts the daemon at login, but a crash or a fresh install leaves it
# dead — and a dead history daemon records nothing while everything still looks
# fine. Start it here instead of showing an empty list that reads as "you have
# not copied anything".
if ! pgrep -x greenclip >/dev/null 2>&1; then
    greenclip daemon >/dev/null 2>&1 &
    sleep 0.4   # let it attach to X and read the history file back in
fi

# Exactly one entry per line: greenclip replaces embedded newlines with U+00A0
# when printing, so a multi-line copy stays a single row and cannot desynchronise
# the indices we select by. Tabs are *not* escaped — handled below.
mapfile -t entries < <(greenclip print 2>/dev/null || true)

if [ "${#entries[@]}" -eq 0 ]; then
    err_menu "Clipboard history is empty — copy something first."
    exit 0
fi

# Build the display labels: literal tabs first (rofi's row renderer treats a tab
# as a column separator, so an entry containing one would render as two cells
# and knock the rest of the row out of alignment), then the length cap.
display=()
for entry in "${entries[@]}"; do
    label="${entry//$'\t'/    }"
    if [ "${#label}" -gt "$MAX_DISPLAY" ]; then
        label="${label:0:$MAX_DISPLAY}…"
    fi
    display+=("$label")
done

# Escape / no selection exits quietly — rofi returns 1 in that case.
index="$(printf '%s\n' "${display[@]}" | menu 'Clipboard')" || exit 0
[ -n "$index" ] || exit 0

# 'greenclip print <entry>' is greenclip's own copy-back path: it restores the
# real newlines and tabs and takes ownership of the CLIPBOARD selection. Piping
# to xclip instead would paste greenclip's flattened one-line form.
greenclip print "${entries[$index]}"
