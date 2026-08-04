#!/usr/bin/env bash
# wallpaper-prep.sh — turn a loud concert photo into a quiet desktop backdrop.
#
# Usage:
#   wallpaper-prep.sh <source-image>     # prints absolute path of processed image, exit 0
#   wallpaper-prep.sh --test <image>     # process + report timings and tone stats
#   wallpaper-prep.sh --force <image>    # ignore any cache entry and reprocess
#   wallpaper-prep.sh --prune            # run cache maintenance only
#   wallpaper-prep.sh --help
#
# Contract for callers (rc.lua):
#   out=$(wallpaper-prep.sh "$src") && feh --bg-fill "$out" || feh --bg-fill "$src"
#   On ANY failure the script prints nothing to stdout and exits non-zero, so the
#   caller can always fall back to the untouched original. Diagnostics go to stderr.
#
# Overrides (all optional, all part of the cache key where they affect output):
#   WP_PREP_SAT=70          saturation kept, %          WP_PREP_DARKEN=0.65
#   WP_PREP_MEAN_MAX=0.20   target luminance ceiling    WP_PREP_MEAN_MIN=0.06
#   WP_PREP_BLUR_PCT=0.35   blur sigma, % of width      WP_PREP_TINT=#efe8ff
#   WP_PREP_QUALITY=92      WP_PREP_CACHE_DIR=...  WP_PREP_MAX_AGE_DAYS=30
#   WP_PREP_MAX_FILES=400
#
# WHY the numbers below (Dr460nized rice: bg #1b1b28, hot pink #ff79c6 accent):
# the wallpaper must be *backdrop*, never subject. The UI is the subject.
set -euo pipefail

# ---------------------------------------------------------------------------
# Tunables. Bump PIPELINE_VERSION whenever any of these defaults or the magick
# pipeline changes — the version is part of the cache key, so old renders are
# ignored (and eventually pruned) instead of being served stale.
# ---------------------------------------------------------------------------
PIPELINE_VERSION=1

# Saturation kept, in percent. 70 == "desaturate 30%". Enough to stop orange
# pyro from competing with #ff79c6, little enough that the photo keeps its mood.
SAT_PCT="${WP_PREP_SAT:-70}"

# Baseline darkening: keep 65% of each channel == "darken 35%". Applied as an
# RGB multiply, NOT -modulate brightness: multiplying maps white -> neutral grey,
# whereas HSL brightness reduction drags blown-out highlights back toward their
# underlying hue and turns pyro into radioactive orange/yellow blobs.
DARKEN="${WP_PREP_DARKEN:-0.65}"

# ...but a flat 35% is not enough for these sources. Some concert shots are
# blown out (mean luminance ~0.79 of full white); 35% off still leaves a glaring
# backdrop. So the multiply is adapted per image to land the mean luminance in
# [MEAN_MIN, MEAN_MAX]: bright photos get darkened much harder than 35%, and a
# nearly black photo is never crushed into a featureless void. 0.20 was picked
# by eye: at that mean the pink/purple UI clearly reads as foreground.
MEAN_MAX="${WP_PREP_MEAN_MAX:-0.20}"
MEAN_MIN="${WP_PREP_MEAN_MIN:-0.06}"

# Gaussian blur sigma as a percentage of screen width. 0.35% == sigma ~6.7px at
# 1920. Deliberately below the 0.6-1% range that "soft background" tutorials
# suggest: at 0.6%+ these stage photos turn into unrecognisable smears, and the
# whole point is that you can still tell it's a Rammstein show. 0.35% kills fine
# detail (faces, cables, crowd texture) that would otherwise pull the eye, while
# stage silhouettes survive.
BLUR_PCT="${WP_PREP_BLUR_PCT:-0.35}"

# Cool/violet cast. +level-colors with a pure black point is a per-channel
# multiply (R*0.937 G*0.910 B*1.000), so shadows stay genuinely black — unlike a
# -colorize or a lifted black point, which greys out the image and destroys the
# contrast against the dark theme bg. The result nudges warm orange toward the
# theme's violet without looking like a filter.
TINT_WHITE="${WP_PREP_TINT:-#efe8ff}"

QUALITY="${WP_PREP_QUALITY:-92}"          # dark blurred gradients band below ~88
CACHE_DIR="${WP_PREP_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/lukasawesome/wallpapers}"
CACHE_MAX_AGE_DAYS="${WP_PREP_MAX_AGE_DAYS:-30}"
CACHE_MAX_FILES="${WP_PREP_MAX_FILES:-400}"
PRUNE_EVERY_HOURS=24                      # prune at most this often, not per call

FALLBACK_W=1920
FALLBACK_H=1080

die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit 1; }

usage() {
    # Print the header comment block (everything after the shebang up to the
    # first non-comment line), stripped of its leading "# ".
    awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

# ---------------------------------------------------------------------------
# Screen geometry. Rendering at the exact panel size means feh never rescales
# (rescaling would soften or alias our carefully chosen blur) and makes the blur
# radius resolution-appropriate.
# ---------------------------------------------------------------------------
screen_size() {
    local line=""
    if command -v xrandr >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
        # Prefer the primary output; otherwise the first connected one with a mode.
        line="$(xrandr --current 2>/dev/null | grep -m1 -E '\bconnected primary [0-9]+x[0-9]+' || true)"
        [ -n "$line" ] || line="$(xrandr --current 2>/dev/null | grep -m1 -E '\bconnected( primary)? [0-9]+x[0-9]+' || true)"
    fi
    if [[ "$line" =~ ([0-9]+)x([0-9]+)\+[0-9]+\+[0-9]+ ]]; then
        printf '%s %s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    else
        printf '%s %s' "$FALLBACK_W" "$FALLBACK_H"
    fi
}

hash_key() {
    # sha256sum is coreutils; fall back to md5sum, then to a crude sanitised key.
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -c1-32
    elif command -v md5sum >/dev/null 2>&1; then md5sum | cut -c1-32
    else cksum | tr -d ' '
    fi
}

# ---------------------------------------------------------------------------
# Cache hygiene: age-based prune plus a hard file cap. Only ever runs after a
# cold render (a cache hit adds nothing, so it has nothing to clean up), and then
# at most once every PRUNE_EVERY_HOURS thanks to a stamp file. Entries deleted by
# the age rule simply cost one 0.5s re-render the next time they come up.
# ---------------------------------------------------------------------------
prune_cache() {
    local stamp="$CACHE_DIR/.last-prune" forced="${1:-0}"
    if [ "$forced" != "1" ] && [ -f "$stamp" ]; then
        # -mmin is GNU find; if the stamp is younger than the interval, skip.
        [ -n "$(find "$stamp" -maxdepth 0 -mmin "+$((PRUNE_EVERY_HOURS * 60))" 2>/dev/null)" ] || return 0
    fi
    : > "$stamp" 2>/dev/null || true
    find "$CACHE_DIR" -maxdepth 1 -type f -name '*.jpg' -mtime "+$CACHE_MAX_AGE_DAYS" -delete 2>/dev/null || true
    # Hard cap: drop the oldest entries beyond CACHE_MAX_FILES.
    local n
    n="$(find "$CACHE_DIR" -maxdepth 1 -type f -name '*.jpg' 2>/dev/null | wc -l)"
    if [ "$n" -gt "$CACHE_MAX_FILES" ]; then
        find "$CACHE_DIR" -maxdepth 1 -type f -name '*.jpg' -printf '%T@ %p\0' 2>/dev/null \
            | sort -zn | head -zn "$((n - CACHE_MAX_FILES))" \
            | while IFS= read -r -d '' entry; do rm -f -- "${entry#* }"; done
    fi
}

# "file[0]" selects the first frame of an animated webp/gif and the first page of
# anything multi-page. Skip the suffix if the name itself ends in [n], which
# ImageMagick would otherwise swallow as a frame selector.
read_spec_for() {
    if [[ "$1" == *'['*']' ]]; then printf '%s' "$1"; else printf '%s[0]' "$1"; fi
}

# ---------------------------------------------------------------------------
# The pipeline. $1 = source, $2 = destination (already-final path is written
# atomically by the caller via a temp file in the same directory).
# ---------------------------------------------------------------------------
process() {
    local src="$1" dst="$2" w="$3" h="$4"
    local read_spec sigma src_mean k
    read_spec="$(read_spec_for "$src")"

    sigma="$(awk -v w="$w" -v p="$BLUR_PCT" 'BEGIN{ s = w*p/100; if (s < 0.5) s = 0.5; printf "%.2f", s }')"

    # Mean luminance of a cheap ~100px sample. It is cropped to the *screen*
    # aspect first, so the measurement matches the pixels that will actually be
    # displayed (a photo with a bright sky band that gets cropped away must not
    # drag the whole image darker). Area-averaging resize preserves the mean and
    # -define jpeg:size lets libjpeg DCT-scale during decode, so this costs a few
    # milliseconds even on a 4K source.
    local sw=100 sh
    sh="$(awk -v w="$w" -v h="$h" 'BEGIN{ v = int(100*h/w + 0.5); if (v < 1) v = 1; print v }')"
    src_mean="$(magick -quiet -define jpeg:size=400x400 "$read_spec" -auto-orient -colorspace sRGB \
        -resize "${sw}x${sh}^" -gravity center -extent "${sw}x${sh}" \
        -format '%[fx:mean]' info: 2>/dev/null)" || return 1
    [ -n "$src_mean" ] || return 1

    # An RGB multiply scales the mean exactly, so the needed factor is closed-form.
    k="$(awk -v m="$src_mean" -v d="$DARKEN" -v hi="$MEAN_MAX" -v lo="$MEAN_MIN" 'BEGIN{
            if (m <= 0) { printf "%.4f", d; exit }
            k = d
            if (m * k > hi) k = hi / m          # blown-out source: darken harder
            if (m * k < lo) k = lo / m          # near-black source: do not crush
            if (k > 1)    k = 1                 # never brighten past the original
            if (k < 0.02) k = 0.02
            printf "%.4f", k
        }')"

    magick -quiet -define jpeg:size="$((w * 2))x$((h * 2))" "$read_spec" \
        -auto-orient \
        -colorspace sRGB \
        -background '#1b1b28' -alpha remove -alpha off \
        -filter Lanczos -resize "${w}x${h}^" -gravity center -extent "${w}x${h}" \
        -modulate "100,${SAT_PCT},100" \
        -blur "0x${sigma}" \
        -evaluate multiply "$k" \
        +level-colors "black,${TINT_WHITE}" \
        -strip -quality "$QUALITY" \
        "$dst"
}

stats() { # "mean hsbSat hslSat" for an image (both saturation metrics: HSB S is
          # the intuitive "how colourful", HSL S is what -modulate actually scales)
    local m s l spec
    spec="$(read_spec_for "$1")"
    m="$(magick -quiet "$spec" -format '%[fx:mean]' info: 2>/dev/null || echo 0)"
    s="$(magick -quiet "$spec" -colorspace HSB -format '%[fx:mean.g]' info: 2>/dev/null || echo 0)"
    l="$(magick -quiet "$spec" -colorspace HSL -format '%[fx:mean.g]' info: 2>/dev/null || echo 0)"
    printf '%s %s %s' "$m" "$s" "$l"
}

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------
MODE=run
case "${1:-}" in
    -h|--help)  usage; exit 0 ;;
    --prune)    MODE=prune ;;
    --test)     MODE=test;  shift ;;
    --force)    MODE=force; shift ;;
    -*)         die "unknown option: $1" ;;
esac

mkdir -p "$CACHE_DIR" || die "cannot create cache dir: $CACHE_DIR"

if [ "$MODE" = prune ]; then
    prune_cache 1
    printf 'pruned: %s (%s entries left)\n' "$CACHE_DIR" \
        "$(find "$CACHE_DIR" -maxdepth 1 -type f -name '*.jpg' | wc -l)" >&2
    exit 0
fi

SRC="${1:-}"
[ -n "$SRC" ] || { usage >&2; exit 2; }
[ -f "$SRC" ] && [ -r "$SRC" ] || die "not a readable file: $SRC"

# Absolute path, so the cache key is stable regardless of the caller's cwd.
SRC_ABS="$(cd -- "$(dirname -- "$SRC")" && printf '%s/%s' "$(pwd -P)" "$(basename -- "$SRC")")"

read -r SCREEN_W SCREEN_H <<<"$(screen_size)"

MTIME="$(stat -c '%Y' -- "$SRC_ABS" 2>/dev/null || echo 0)"
SIZE="$(stat -c '%s' -- "$SRC_ABS" 2>/dev/null || echo 0)"
KEY="$(printf '%s|%s|%s|%sx%s|v%s|%s|%s|%s|%s|%s|%s' \
        "$SRC_ABS" "$MTIME" "$SIZE" "$SCREEN_W" "$SCREEN_H" "$PIPELINE_VERSION" \
        "$SAT_PCT" "$DARKEN" "$MEAN_MAX" "$MEAN_MIN" "$BLUR_PCT" "$TINT_WHITE" | hash_key)"
OUT="$CACHE_DIR/$KEY.jpg"

if [ "$MODE" != test ] && [ "$MODE" != force ] && [ -s "$OUT" ]; then
    # Cache hit: print and stop. No ImageMagick, no directory scan, not even the
    # prune interval check — maintenance only makes sense after something new was
    # written, and this is the path the 10-minute rotation takes ~99% of the time.
    printf '%s\n' "$OUT"
    exit 0
fi

if [ "$MODE" = test ] || [ "$MODE" = force ]; then
    rm -f -- "$OUT"            # cold render requested
fi

# Only a cache MISS needs ImageMagick, so the hit path above stays a pure stat().
command -v magick >/dev/null 2>&1 || die "ImageMagick 7 (magick) not found"
# Cheap validity check: -ping reads only the header, not the pixels.
magick identify -quiet -ping "$(read_spec_for "$SRC_ABS")" >/dev/null 2>&1 \
    || die "not a decodable image: $SRC_ABS"

TMP=""
# Never leave a partial entry behind. Note the explicit `return "$rc"`: a bash
# EXIT trap whose last command fails would otherwise overwrite the exit status.
cleanup() { local rc=$?; [ -n "$TMP" ] && rm -f -- "$TMP"; return "$rc"; }
trap cleanup EXIT

# Temp file lives in the cache dir so the rename is atomic (same filesystem).
TMP="$(mktemp "$CACHE_DIR/.tmp-XXXXXXXX.jpg")"

if [ "$MODE" = test ]; then
    t0="$(date +%s.%N)"
fi

# Capture ImageMagick's diagnostics rather than discarding them: stdout must stay
# clean for the caller, but a silent failure is impossible to debug.
if ! ERR="$(process "$SRC_ABS" "$TMP" "$SCREEN_W" "$SCREEN_H" 2>&1 >/dev/null)"; then
    [ -n "$ERR" ] && printf '%s\n' "$ERR" >&2
    die "processing failed: $SRC_ABS"
fi
[ -s "$TMP" ] || die "processing produced an empty file: $SRC_ABS"

mv -f -- "$TMP" "$OUT"
TMP=""

if [ "$MODE" = test ]; then
    t1="$(date +%s.%N)"
    # Second call goes through the normal cached path.
    t2="$(date +%s.%N)"
    cached="$("$0" "$SRC_ABS")"
    t3="$(date +%s.%N)"
    read -r bm bs bl <<<"$(stats "$SRC_ABS")"
    read -r am as al <<<"$(stats "$OUT")"
    {
        printf 'source      : %s\n' "$SRC_ABS"
        printf 'output      : %s\n' "$OUT"
        printf 'cached path : %s\n' "$cached"
        printf 'geometry    : %sx%s (blur sigma %s)\n' "$SCREEN_W" "$SCREEN_H" \
            "$(awk -v w="$SCREEN_W" -v p="$BLUR_PCT" 'BEGIN{printf "%.2f", w*p/100}')"
        printf 'cold render : %.3fs\n' "$(awk -v a="$t0" -v b="$t1" 'BEGIN{print b-a}')"
        printf 'cache hit   : %.4fs\n' "$(awk -v a="$t2" -v b="$t3" 'BEGIN{print b-a}')"
        printf 'brightness  : %s -> %s (%.1f%%)\n' "$bm" "$am" \
            "$(awk -v a="$bm" -v b="$am" 'BEGIN{print (a>0)?(b/a-1)*100:0}')"
        printf 'sat (HSB)   : %s -> %s (%.1f%%)\n' "$bs" "$as" \
            "$(awk -v a="$bs" -v b="$as" 'BEGIN{print (a>0)?(b/a-1)*100:0}')"
        printf 'sat (HSL)   : %s -> %s (%.1f%%)\n' "$bl" "$al" \
            "$(awk -v a="$bl" -v b="$al" 'BEGIN{print (a>0)?(b/a-1)*100:0}')"
    } >&2
fi

printf '%s\n' "$OUT"
prune_cache
exit 0
