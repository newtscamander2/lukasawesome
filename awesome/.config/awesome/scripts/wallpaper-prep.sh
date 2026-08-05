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
#   WP_PREP_SAT=80            saturation kept, %        WP_PREP_DARKEN=0.72
#   WP_PREP_MEAN_MAX=0.28     luminance ceiling         WP_PREP_MEAN_MIN=0.09
#   WP_PREP_BLUR_PCT=0.28     blur sigma, % of width    WP_PREP_TINT=#efe8ff
#   WP_PREP_UI_RECT=560x470+24+74   region kept dark for the UI tile
#   WP_PREP_UI_TARGET=0.12    mean luminance to hit inside that region
#   WP_PREP_UI_MAX=0.70       max corner darkening      WP_PREP_UI_MIN=0.10
#   WP_PREP_UI_FEATHER=0.36   fade distance, fraction of W/H
#   WP_PREP_QUALITY=92        WP_PREP_CACHE_DIR=...  WP_PREP_MAX_AGE_DAYS=30
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
PIPELINE_VERSION=3   # v3: lifted the tone floor — the photo was too suppressed

# Saturation kept, in percent. 70 == "desaturate 30%". Enough to stop orange
# pyro from competing with #ff79c6, little enough that the photo keeps its mood.
SAT_PCT="${WP_PREP_SAT:-80}"

# Baseline darkening: keep 65% of each channel == "darken 35%". Applied as an
# RGB multiply, NOT -modulate brightness: multiplying maps white -> neutral grey,
# whereas HSL brightness reduction drags blown-out highlights back toward their
# underlying hue and turns pyro into radioactive orange/yellow blobs.
DARKEN="${WP_PREP_DARKEN:-0.72}"

# ...but a flat 35% is not enough for these sources. Some concert shots are
# blown out (mean luminance ~0.79 of full white); 35% off still leaves a glaring
# backdrop. So the multiply is adapted per image to land the mean luminance in
# [MEAN_MIN, MEAN_MAX]: bright photos get darkened much harder than 35%, and a
# nearly black photo is never crushed into a featureless void. 0.20 was picked
# by eye. NOTE: 0.20 proved too aggressive in practice — the photo was so
# suppressed it read as a plain dark gradient, losing the point of having a
# wallpaper at all. 0.28 keeps the UI clearly in front while letting the image
# stay legible; nudge MEAN_MAX down again if a future wallpaper set is brighter.
MEAN_MAX="${WP_PREP_MEAN_MAX:-0.28}"
MEAN_MIN="${WP_PREP_MEAN_MIN:-0.09}"

# Gaussian blur sigma as a percentage of screen width. 0.35% == sigma ~6.7px at
# 1920. Deliberately below the 0.6-1% range that "soft background" tutorials
# suggest: at 0.6%+ these stage photos turn into unrecognisable smears, and the
# whole point is that you can still tell it's a Rammstein show. 0.35% kills fine
# detail (faces, cables, crowd texture) that would otherwise pull the eye, while
# stage silhouettes survive.
BLUR_PCT="${WP_PREP_BLUR_PCT:-0.28}"

# Cool/violet cast. +level-colors with a pure black point is a per-channel
# multiply (R*0.937 G*0.910 B*1.000), so shadows stay genuinely black — unlike a
# -colorize or a lifted black point, which greys out the image and destroys the
# contrast against the dark theme bg. The result nudges warm orange toward the
# theme's violet without looking like a filter.
TINT_WHITE="${WP_PREP_TINT:-#efe8ff}"

# --- UI-safe luminance floor -----------------------------------------------
# A global mean inside the target band still says nothing about any *particular*
# region: a daylight shot with a white building in the top-left lands at mean
# 0.19 overall while that quadrant sits at 0.83. That is exactly where the
# dash_tile lives (workarea top-left + 24px, 560x470) and its frosted background
# is only ~67% opaque, so the tile washes out and the pink accents lose contrast.
#
# UI_RECT is the region that must stay dark, in screen pixels: WxH+X+Y. Y already
# includes the wibar strut. Everything else is derived from it, so moving the
# tile only means changing this one value.
UI_RECT="${WP_PREP_UI_RECT:-560x470+24+74}"

# Mean luminance to hit inside UI_RECT. 0.12 leaves comfortable headroom under
# the ~0.15 at which the frosted tile starts to wash out.
UI_TARGET="${WP_PREP_UI_TARGET:-0.12}"

# Bounds on the corner darkening. UI_MAX stops a searingly bright photo from
# being punched into a black hole (never multiply the corner below 0.30). UI_MIN
# keeps a whisper of falloff on images that need none, so the corner treatment
# looks like consistent lighting across the rotation rather than a filter that
# switches on and off between wallpapers. 0.10 is imperceptible on its own.
UI_MAX="${WP_PREP_UI_MAX:-0.70}"
UI_MIN="${WP_PREP_UI_MIN:-0.10}"

# How far the darkening fades out past UI_RECT, as a fraction of width/height.
# The falloff has a *plateau* covering UI_RECT (so the whole tile is uniformly
# dark and the numeric target is actually guaranteed, not just met at the
# corner), then a smoothstep fade. 0.36 == ~690px horizontally / ~390px
# vertically at 1080p, i.e. the darkening is gone by ~62% width / ~88% height.
# The brief suggested fading out by the horizontal centre and ~60% height, but
# UI_RECT alone already reaches 30% width / 50% height: fading that fast puts the
# steepest part of the ramp right at the tile's edge, which reads as a visible
# dark rectangle. A wider, lazier fade is what makes it look like light falloff.
UI_FEATHER="${WP_PREP_UI_FEATHER:-0.36}"

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
# Measurement: everything the pipeline does is driven by two numbers taken from
# the source, so both live here.
# ---------------------------------------------------------------------------
UI_RW=0 UI_RH=0 UI_RX=0 UI_RY=0
parse_ui_rect() {
    [[ "$UI_RECT" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]] \
        || die "WP_PREP_UI_RECT must look like WxH+X+Y, got: $UI_RECT"
    UI_RW="${BASH_REMATCH[1]}"; UI_RH="${BASH_REMATCH[2]}"
    UI_RX="${BASH_REMATCH[3]}"; UI_RY="${BASH_REMATCH[4]}"
}

# Mean luminance of the whole frame AND of UI_RECT, from one cheap sample.
# The sample is resized/cropped to the *screen* aspect first, so both figures
# describe the pixels that will actually be displayed (a bright sky band that
# gets cropped away must not drag the whole image darker). Area-averaging resize
# preserves the mean, and -define jpeg:size lets libjpeg DCT-scale during decode,
# so the whole measurement costs a few milliseconds even on a 4K source.
# Echoes "globalMean uiRectMean".
sample_means() {
    local src="$1" w="$2" h="$3"
    local sw=480 sh cw ch cx cy out
    read -r sh cw ch cx cy <<<"$(awk -v w="$w" -v h="$h" -v sw=480 \
        -v rw="$UI_RW" -v rh="$UI_RH" -v rx="$UI_RX" -v ry="$UI_RY" 'BEGIN{
            s  = sw / w
            sh = int(h * s + 0.5); if (sh < 1) sh = 1
            cx = int(rx * s);      if (cx < 0)  cx = 0
            cy = int(ry * s);      if (cy < 0)  cy = 0
            cw = int(rw * s + 0.5); ch = int(rh * s + 0.5)
            if (cw < 1) cw = 1;    if (ch < 1) ch = 1
            if (cx + cw > sw) cw = sw - cx;  if (cw < 1) { cx = 0; cw = sw }
            if (cy + ch > sh) ch = sh - cy;  if (ch < 1) { cy = 0; ch = sh }
            print sh, cw, ch, cx, cy
        }')"
    # +repage after -extent is mandatory: -extent leaves a page offset and the
    # following -crop would otherwise be measured from the wrong origin.
    out="$(magick -quiet -define jpeg:size="$((sw * 2))x$((sw * 2))" "$(read_spec_for "$src")" \
        -auto-orient -colorspace sRGB \
        -resize "${sw}x${sh}^" -gravity center -extent "${sw}x${sh}" +repage \
        \( +clone -gravity none -crop "${cw}x${ch}+${cx}+${cy}" +repage \) \
        -print '%[fx:u[0].mean] %[fx:u[1].mean]' null: 2>/dev/null)" || return 1
    [ -n "$out" ] || return 1
    printf '%s' "$out"
}

# Turn those two measurements into the two multipliers. Echoes "k strength".
tone_factors() {
    awk -v m="$1" -v r="$2" -v d="$DARKEN" -v hi="$MEAN_MAX" -v lo="$MEAN_MIN" \
        -v t="$UI_TARGET" -v smax="$UI_MAX" -v smin="$UI_MIN" 'BEGIN{
            # Global darkening. An RGB multiply scales the mean exactly, so the
            # factor that lands the frame in [lo, hi] is closed-form.
            k = d
            if (m > 0) {
                if (m * k > hi) k = hi / m      # blown-out source: darken harder
                if (m * k < lo) k = lo / m      # near-black source: do not crush
            }
            if (k > 1)    k = 1                 # never brighten past the original
            if (k < 0.02) k = 0.02

            # UI floor. r*k is what UI_RECT will read after the global darkening,
            # so the extra factor needed there is just t/(r*k). Images already
            # dark enough get only the UI_MIN whisper.
            f = 1
            if (r * k > 0) f = t / (r * k)
            if (f > 1) f = 1
            if (f < 1 - smax) f = 1 - smax
            s = 1 - f
            if (s < smin) s = smin
            printf "%.4f %.4f", k, s
        }'
}

# ---------------------------------------------------------------------------
# The pipeline. $1 = source, $2 = destination (already-final path is written
# atomically by the caller via a temp file in the same directory).
# ---------------------------------------------------------------------------
process() {
    local src="$1" dst="$2" w="$3" h="$4"
    local read_spec sigma gm rm k s
    read_spec="$(read_spec_for "$src")"

    sigma="$(awk -v w="$w" -v p="$BLUR_PCT" 'BEGIN{ s = w*p/100; if (s < 0.5) s = 0.5; printf "%.2f", s }')"

    read -r gm rm <<<"$(sample_means "$src" "$w" "$h")" || return 1
    [ -n "$gm" ] && [ -n "$rm" ] || return 1
    read -r k s <<<"$(tone_factors "$gm" "$rm")"

    # Build the UI falloff mask: two 1-D ramps, each 0 across a plateau that
    # covers UI_RECT and rising to 1 over the feather distance. Squared, summed
    # and square-rooted they give the distance from the plateau, so the iso-lines
    # are a *rounded* rectangle — a plain product of the two ramps would give
    # square corners, which the eye reads as a dark box. -function Polynomial
    # -2,3,0,0 is smoothstep (3u^2-2u^3): zero slope at both ends, so there is no
    # crease where the fade starts or stops. Finally 1 - strength*s inverts it
    # into a multiplier.
    local -a mask=()
    if [ "$(awk -v s="$s" 'BEGIN{ print (s > 0.001) ? 1 : 0 }')" = 1 ]; then
        local px py fx fy
        read -r px py fx fy <<<"$(awk -v w="$w" -v h="$h" -v f="$UI_FEATHER" \
            -v rw="$UI_RW" -v rh="$UI_RH" -v rx="$UI_RX" -v ry="$UI_RY" 'BEGIN{
                margin = 16                       # keep the ramp off the tile edge
                px = rx + rw + margin; py = ry + rh + margin
                if (px > w - 1) px = w - 1;  if (px < 1) px = 1
                if (py > h - 1) py = h - 1;  if (py < 1) py = 1
                fx = int(w * f + 0.5); fy = int(h * f + 0.5)
                if (px + fx > w) fx = w - px;  if (fx < 1) fx = 1
                if (py + fy > h) fy = h - py;  if (fy < 1) fy = 1
                print px, py, fx, fy
            }')"
        mask=(
            '(' -size "${h}x${fx}" gradient:black-white -rotate -90
                -background black -gravity east -extent "$((px + fx))x${h}"
                -background white -gravity west -extent "${w}x${h}"
                -evaluate pow 2
                '(' -size "${w}x${fy}" gradient:black-white
                    -background black -gravity south -extent "${w}x$((py + fy))"
                    -background white -gravity north -extent "${w}x${h}"
                    -evaluate pow 2 ')'
                -compose Plus -composite
                -evaluate pow 0.5 -clamp -negate
                -function Polynomial "-2,3,0,0"
                -evaluate multiply "$s" -negate ')'
            # -gravity none: parentheses do not restore settings without
            # -respect-parentheses, and a leaked gravity would offset the composite.
            -gravity none -compose Multiply -composite +repage
        )
    fi

    magick -quiet -define jpeg:size="$((w * 2))x$((h * 2))" "$read_spec" \
        -auto-orient \
        -colorspace sRGB \
        -background '#1b1b28' -alpha remove -alpha off \
        -filter Lanczos -resize "${w}x${h}^" -gravity center -extent "${w}x${h}" +repage \
        -modulate "100,${SAT_PCT},100" \
        -blur "0x${sigma}" \
        -evaluate multiply "$k" \
        +level-colors "black,${TINT_WHITE}" \
        "${mask[@]}" \
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
parse_ui_rect

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
KEY="$(printf '%s|%s|%s|%sx%s|v%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s' \
        "$SRC_ABS" "$MTIME" "$SIZE" "$SCREEN_W" "$SCREEN_H" "$PIPELINE_VERSION" \
        "$SAT_PCT" "$DARKEN" "$MEAN_MAX" "$MEAN_MIN" "$BLUR_PCT" "$TINT_WHITE" \
        "$UI_RECT" "$UI_TARGET" "$UI_MAX" "$UI_MIN" "$UI_FEATHER" | hash_key)"
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
    # UI region: source figure comes from the sampler (the source has different
    # dimensions, so the rect only means anything after resize/crop); the output
    # figure is cropped straight out of the finished file.
    read -r t_gm t_rm <<<"$(sample_means "$SRC_ABS" "$SCREEN_W" "$SCREEN_H")"
    read -r t_k t_s <<<"$(tone_factors "$t_gm" "$t_rm")"
    ui_out="$(magick -quiet "$OUT" +repage -crop "$UI_RECT" +repage \
        -format '%[fx:mean]' info: 2>/dev/null || echo '?')"
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
        printf 'ui rect     : %s\n' "$UI_RECT"
        printf 'ui mean     : %s -> %s (target %s, must stay well under 0.15)\n' \
            "$t_rm" "$ui_out" "$UI_TARGET"
        printf 'factors     : darken k=%s, ui falloff strength=%s\n' "$t_k" "$t_s"
    } >&2
fi

printf '%s\n' "$OUT"
prune_cache
exit 0
