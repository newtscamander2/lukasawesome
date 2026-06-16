#!/usr/bin/env bash
# Video wallpaper for X11 / AwesomeWM via xwinwrap + mpv.
#
# Usage: wallpaper-video.sh [/path/to/video]
#   Default video: ~/Media/wallpapers/video/default.mp4
#
# To avoid the "looks bad / drains battery" failure modes, this falls back to a
# still feh wallpaper when:
#   - xwinwrap or mpv is not installed
#   - the video file is missing
#   - the machine is on battery (override with FORCE_VIDEO=1)
#   - more than one monitor is connected (override with FORCE_MULTI=1)
set -euo pipefail

VIDEO="${1:-$HOME/Media/wallpapers/video/default.mp4}"
FALLBACK_DIR="$HOME/Media/wallpapers"

still_fallback() {
    if command -v feh >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        feh --randomize --bg-fill "$FALLBACK_DIR"/* 2>/dev/null || true
    fi
    exit 0
}

command -v xwinwrap >/dev/null 2>&1 || still_fallback
command -v mpv      >/dev/null 2>&1 || still_fallback
[ -r "$VIDEO" ] || still_fallback

# Skip on battery unless forced.
if [ "${FORCE_VIDEO:-0}" != "1" ]; then
    on_ac=1
    for ps in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
        [ -r "$ps" ] && on_ac="$(cat "$ps")"
    done
    [ "$on_ac" = "1" ] || still_fallback
fi

# Skip on multi-monitor unless forced (a single looping video across two heads
# tends to tear / look bad).
if [ "${FORCE_MULTI:-0}" != "1" ] && command -v xrandr >/dev/null 2>&1; then
    connected="$(xrandr --query | grep -c ' connected')"
    [ "$connected" -le 1 ] || still_fallback
fi

# Replace any previous instance.
pkill -f 'xwinwrap.*mpv' 2>/dev/null || true

xwinwrap -fs -fdt -ni -b -nf -ov -- \
    mpv -wid WID --loop --no-audio --no-osc --no-osd-bar \
        --really-quiet --no-input-default-bindings \
        --panscan=1.0 --hwdec=auto "$VIDEO" &
