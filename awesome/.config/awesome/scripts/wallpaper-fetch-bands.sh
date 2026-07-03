#!/usr/bin/env bash
# Fetch band wallpapers (Rammstein / MoonSun) from Wikimedia Commons into
# ~/Media/wallpapers/bands/ by crawling the Commons category tree.
# Idempotent: existing files are kept, so you can also drop your own images
# into the folder and they survive re-runs.
set -uo pipefail

DEST="$HOME/Media/wallpapers/bands"
API="https://commons.wikimedia.org/w/api.php"
UA="lukasawesome-wallpaper-fetch/1.0 (personal wallpaper script)"
TARGET=100      # stop once the folder holds this many images
MIN_WIDTH=1200  # skip small images
CRAWL_DEPTH=2   # how deep to follow subcategories

mkdir -p "$DEST"

# Retry transient failures (incl. 429 rate limits) and pace requests gently.
api() {
    sleep 0.5
    curl -sf -A "$UA" --retry 5 --retry-delay 3 --retry-all-errors -G "$API" "$@" ||
        echo "API request failed (after retries)" >&2
}

count_files() { find "$DEST" -type f | wc -l; }

# --- 1. Collect candidate file titles by crawling categories -----------------
ROOTS=("Category:Rammstein" "Category:Till Lindemann" "Category:Members of Rammstein")
# Skip non-wallpaper material and unrelated acts.
SKIP_CAT_RE='tribute|logo|song|single|album|cover'

declare -A SEEN_CAT
TITLES_FILE=$(mktemp)
trap 'rm -f "$TITLES_FILE" "${TITLES_FILE}.shuf"' EXIT

crawl() {
    local cat="$1" depth="$2"
    [ -n "${SEEN_CAT[$cat]:-}" ] && return 0
    SEEN_CAT[$cat]=1
    echo "Scanning $cat (depth $depth)" >&2

    api --data-urlencode "action=query" --data-urlencode "list=categorymembers" \
        --data-urlencode "cmtitle=$cat" --data-urlencode "cmtype=file" \
        --data-urlencode "cmlimit=500" --data-urlencode "format=json" |
        jq -r '.query.categorymembers[].title' |
        grep -iE '\.(jpe?g|png|webp)$' >> "$TITLES_FILE" || true

    if [ "$depth" -gt 0 ]; then
        while IFS= read -r sub; do
            [ -z "$sub" ] && continue
            if echo "$sub" | grep -qiE "$SKIP_CAT_RE"; then
                echo "  (skipping $sub)" >&2
                continue
            fi
            crawl "$sub" $((depth - 1))
        done < <(api --data-urlencode "action=query" --data-urlencode "list=categorymembers" \
                     --data-urlencode "cmtitle=$cat" --data-urlencode "cmtype=subcat" \
                     --data-urlencode "cmlimit=100" --data-urlencode "format=json" |
                 jq -r '.query.categorymembers[].title')
    fi
}

for root in "${ROOTS[@]}"; do
    crawl "$root" "$CRAWL_DEPTH"
done

sort -u "$TITLES_FILE" | shuf > "${TITLES_FILE}.shuf"
echo "Found $(wc -l < "${TITLES_FILE}.shuf") candidate files on Commons"

# --- 2. Resolve URLs in batches of 50 and download until TARGET --------------
download_batch() {
    local joined="$1"
    api --data-urlencode "action=query" --data-urlencode "titles=$joined" \
        --data-urlencode "prop=imageinfo" --data-urlencode "iiprop=url|size" \
        --data-urlencode "iiurlwidth=2560" --data-urlencode "format=json" |
        jq -r '.query.pages[] | select(.imageinfo != null) |
               "\(.imageinfo[0].width)\t\(.imageinfo[0].thumburl // .imageinfo[0].url)\t\(.title)"' |
        while IFS=$'\t' read -r width url title; do
            [ "$(count_files)" -ge "$TARGET" ] && return 0
            [ "${width:-0}" -ge "$MIN_WIDTH" ] || continue
            local_name=$(echo "${title#File:}" | tr ' /' '__')
            [ -e "$DEST/$local_name" ] && continue
            echo "  -> $local_name (${width}px)"
            curl -sf -A "$UA" -o "$DEST/$local_name" "$url" || rm -f "$DEST/$local_name"
        done
}

batch=""
n=0
while IFS= read -r title; do
    [ "$(count_files)" -ge "$TARGET" ] && break
    batch="${batch:+$batch|}$title"
    n=$((n + 1))
    if [ "$n" -eq 50 ]; then
        download_batch "$batch"
        batch=""; n=0
    fi
done < "${TITLES_FILE}.shuf"
[ -n "$batch" ] && [ "$(count_files)" -lt "$TARGET" ] && download_batch "$batch"

# --- 3. Known good files that category crawling misses ------------------------
# MoonSun is a small band — Commons has very little; drop your own images into
# $DEST, they are kept.
declare -A DIRECT=(
    ["MoonSun.jpg"]="https://upload.wikimedia.org/wikipedia/commons/0/0c/MoonSun.jpg"
)
for name in "${!DIRECT[@]}"; do
    [ -e "$DEST/$name" ] || { echo "Direct: $name"; curl -sf -A "$UA" -o "$DEST/$name" "${DIRECT[$name]}" || rm -f "$DEST/$name"; }
done

echo "Done. $(count_files) wallpapers in $DEST"
