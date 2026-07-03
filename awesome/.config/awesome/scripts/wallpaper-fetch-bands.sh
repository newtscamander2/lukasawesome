#!/usr/bin/env bash
# Fetch band wallpapers (Rammstein / MoonSun) from Wikimedia Commons into
# ~/Media/wallpapers/bands/. Idempotent: existing files are kept, so you can
# also drop your own images into the folder and they survive re-runs.
set -euo pipefail

DEST="$HOME/Media/wallpapers/bands"
API="https://commons.wikimedia.org/w/api.php"
PER_QUERY=12
MIN_WIDTH=1200

mkdir -p "$DEST"

fetch_query() {
    local query="$1"
    local enc
    enc=$(python3 - "$query" <<'EOF'
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
EOF
)
    # Titles of matching files (bitmap formats only)
    curl -sf "${API}?action=query&list=search&srsearch=${enc}&srnamespace=6&srlimit=${PER_QUERY}&format=json" |
        jq -r '.query.search[].title' |
        grep -iE '\.(jpe?g|png|webp)$' |
        while IFS= read -r title; do
            local_name=$(echo "${title#File:}" | tr ' /' '__')
            [ -e "$DEST/$local_name" ] && continue
            info=$(curl -sf -G "$API" \
                --data-urlencode "action=query" \
                --data-urlencode "titles=$title" \
                --data-urlencode "prop=imageinfo" \
                --data-urlencode "iiprop=url|size" \
                --data-urlencode "iiurlwidth=2560" \
                --data-urlencode "format=json")
            width=$(echo "$info" | jq -r '.query.pages[].imageinfo[0].width // 0')
            url=$(echo "$info" | jq -r '.query.pages[].imageinfo[0].thumburl // .query.pages[].imageinfo[0].url // empty')
            if [ -n "$url" ] && [ "$width" -ge "$MIN_WIDTH" ]; then
                echo "  -> $local_name (${width}px)"
                curl -sf -o "$DEST/$local_name" "$url" || rm -f "$DEST/$local_name"
            fi
        done
}

for q in "Rammstein concert" "Rammstein" "Till Lindemann" "MoonSun band" "Susanne Scherer MoonSun"; do
    echo "Query: $q"
    fetch_query "$q" || echo "  (no new images for this query)"
done

# Known good files that full-text search misses (MoonSun is a small band —
# Commons has very little; drop your own images into $DEST, they are kept).
declare -A DIRECT=(
    ["MoonSun.jpg"]="https://upload.wikimedia.org/wikipedia/commons/0/0c/MoonSun.jpg"
)
for name in "${!DIRECT[@]}"; do
    [ -e "$DEST/$name" ] || { echo "Direct: $name"; curl -sf -o "$DEST/$name" "${DIRECT[$name]}" || rm -f "$DEST/$name"; }
done

count=$(find "$DEST" -type f | wc -l)
echo "Done. $count wallpapers in $DEST"
