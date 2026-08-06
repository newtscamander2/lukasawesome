#!/usr/bin/env bash
# Regenerates the Windows 7 (Aero) theme assets with ImageMagick.
#
# The generated PNGs/JPEG are COMMITTED, so the theme works on a machine with no
# ImageMagick — this script exists so the assets stay reproducible and tweakable
# instead of being opaque binaries nobody can regenerate.
#
#   ./make-assets.sh              # everything drawn (not the fetched assets)
#   ./make-assets.sh buttons      # buttons | misc
#   ./make-assets.sh orb          # re-fetch the real Vista/7 start orb
#   ./make-assets.sh wallpaper    # re-fetch Windows 7's Harmony
#   ./make-assets.sh orb-draw | wallpaper-draw    # offline stand-ins instead
#
# Two assets are the genuine articles, fetched rather than drawn: the start orb
# (ORB_URL) and the Harmony wallpaper (WALLPAPER_URL). Everything else — the
# titlebar glass, tray, quick-launch, desktop and Start-menu icons, and the user
# picture — is drawn from primitives to evoke Aero, tracing nothing. The two
# fetched assets have drawn stand-ins (`orb-draw`, `wallpaper-draw`) so a machine
# with no network still gets a coherent desktop.
#
# IM gotcha worth knowing before editing: filling a shape with a gradient is
# done with `-tile <gradient> -draw`. The obvious `gradient | mask |
# -compose CopyOpacity` route silently produced an unmasked image here (no
# alpha channel in the result at all), which is why nothing below uses it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p titlebar icons

# --- Start orb ---------------------------------------------------------------
# The real Vista/7 orb. Committed, so this only runs to re-fetch it. Stored at
# 128px — twice the on-screen size, which keeps cairo's downscale crisp — and
# the hover state is the same art lifted, as Windows does.
ORB_URL="https://www.rw-designer.com/icon-image/25968-256x256x32.png"

make_orb_official() {
    local tmp
    tmp="$(mktemp -t w7orb.XXXXXX.png)"
    if curl -sfL --max-time 40 -A "Mozilla/5.0" -o "$tmp" "$ORB_URL" \
       && magick identify "$tmp" >/dev/null 2>&1; then
        magick "$tmp" -filter Lanczos -resize 128x128 start.png
        magick start.png -modulate 118,112 start-hover.png
        rm -f "$tmp"
        echo "fetched start.png from $ORB_URL"
    else
        rm -f "$tmp"
        echo "download failed — drawing the synthetic orb instead" >&2
        draw_orb "start.png" 100
        draw_orb "start-hover.png" 122
    fi
}

# Offline fallback, drawn at 4x and downscaled: the rim highlight and the flag
# gaps are ~1px features at the final 64px, and drawing them directly at that
# size mushes them. Lighter glass than the real orb, but the right silhouette.
draw_orb() {
    local out="$1"
    local bright="$2"
    local S=256 C=128 R=118 FS G

    magick -size ${S}x${S} gradient:'#b4e6ff-#0a355a' _gr.png
    # The disc: gradient-filled circle on a transparent canvas.
    magick -size ${S}x${S} xc:none -tile _gr.png -draw "circle $C,$C $C,$((C-R))" _o1.png

    magick _o1.png \
        `# inner bright ring — light caught just inside the glass edge` \
        \( -size ${S}x${S} xc:none -stroke '#8ad4ff' -strokewidth 3 -fill none \
           -draw "circle $C,$C $C,$((C-R+4))" -blur 0x2 \) -composite \
        `# dark rim, so the orb sits ON the taskbar rather than in it` \
        \( -size ${S}x${S} xc:none -stroke '#04223a' -strokewidth 5 -fill none \
           -draw "circle $C,$C $C,$((C-R))" -blur 0x1 \) -composite \
        `# top gloss, sized to stay inside the disc so it needs no clipping` \
        \( -size ${S}x${S} xc:none -fill 'rgba(255,255,255,0.45)' \
           -draw "ellipse $C,$((S*27/100)) $((R*54/100)),$((R*22/100)) 0,360" -blur 0x8 \) -composite \
        `# bottom crescent — bounced light, the second half of the glass read` \
        \( -size ${S}x${S} xc:none -stroke 'rgba(170,225,255,0.8)' -strokewidth 4 -fill none \
           -draw "arc $((C-R+18)),$((C-R+18)) $((C+R-18)),$((C+R-18)) 35,145" -blur 0x3 \) -composite \
        _o2.png

    # Four-pane flag. The left pair sits lower and the right pair higher: that
    # offset is what reads as a waving flag instead of a 2x2 grid.
    FS=$((R*30/100)); G=$((R*5/100))
    magick _o2.png -stroke none -fill 'rgba(255,255,255,0.96)' \
        -draw "roundrectangle $((C-FS-G)),$((C-FS-G+7)) $((C-G)),$((C-G+7)) 4,4" \
        -draw "roundrectangle $((C+G)),$((C-FS-G-5)) $((C+FS+G)),$((C-G-5)) 4,4" \
        -draw "roundrectangle $((C-FS-G)),$((C+G+7)) $((C-G)),$((C+FS+G+7)) 4,4" \
        -draw "roundrectangle $((C+G)),$((C+G-5)) $((C+FS+G)),$((C+FS+G-5)) 4,4" \
        _o3.png

    # Outer glow: the orb bleeds light onto the taskbar around it. Border first
    # so the glow has somewhere to live instead of being clipped to the circle.
    magick _o3.png -bordercolor none -border 20 \
        \( +clone -alpha extract -blur 0x9 -fill '#7fd0ff' -colorize 100 \) \
        -compose DstOver -composite \
        -modulate "$bright" \
        -resize 64x64 "$out"
    rm -f _gr.png _o1.png _o2.png _o3.png
}

# --- Titlebar buttons --------------------------------------------------------
# Aero's controls are one glass capsule split in three. Each is drawn separately
# so awesome can lay them out; the outer corners are rounded on every one, which
# at 25px reads the same as the real capsule.
# Trailing args are the glyph's -draw pairs, taken as an array: a single
# string would word-split and hand `-draw` only the primitive's NAME.
make_button() {
    local out="$1" w="$2" h="$3" top="$4" bot="$5"
    shift 5
    local glyph=("$@")
    local S=4
    local W=$((w*S)) H=$((h*S)) RND=$((3*S))

    magick -size ${W}x${H} gradient:"$top-$bot" _bg.png
    # Glass = a hard highlight line under the top edge + a soft inner stroke.
    magick -size ${W}x${H} xc:none -tile _bg.png \
        -draw "roundrectangle 0,0 $((W-1)),$((H-1)) $RND,$RND" \
        -fill 'rgba(255,255,255,0.50)' -stroke none \
        -draw "rectangle $((S*2)),$((S*2)) $((W-S*2)),$((S*3))" \
        -fill none -stroke 'rgba(255,255,255,0.35)' -strokewidth $S \
        -draw "roundrectangle $((S/2)),$((S/2)) $((W-S)),$((H-S)) $RND,$RND" \
        _btn.png
    # Glyphs are stroked primitives, not glyphs from a font: the Wingdings-style
    # marks Windows uses are not guaranteed installed and would render as tofu.
    magick _btn.png -stroke white -strokewidth $((S+1)) -fill none "${glyph[@]}" \
        -resize ${w}x${h} "$out"
    rm -f _bg.png _btn.png
}

BTN_W=25; BTN_H=17
# Glyph coordinates are in the 4x space (100x68 for a 25x17 button).
MIN_GLYPH=(-draw "line 38,48 62,48")
MAX_GLYPH=(-draw "rectangle 38,24 62,46")
RESTORE_GLYPH=(-draw "rectangle 30,30 52,50" -draw "polyline 38,30 38,20 62,20 62,40 52,40")
CLOSE_GLYPH=(-draw "line 74,24 94,46" -draw "line 94,24 74,46")

# --- Wallpaper ---------------------------------------------------------------
# The real thing: Windows 7's default "Harmony" (Img0). Committed alongside the
# generated assets, so this only runs when you want to re-fetch it.
WALLPAPER_URL="https://windowswallpaper.miraheze.org/wiki/Special:FilePath/Img0_(Windows_7).jpg"

make_wallpaper() {
    local out="$1" tmp
    tmp="$(mktemp -t w7wall.XXXXXX.jpg)"
    if curl -sfL --max-time 40 -A "Mozilla/5.0" -o "$tmp" "$WALLPAPER_URL" \
       && magick identify "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$out"
        echo "fetched $out from $WALLPAPER_URL"
    else
        rm -f "$tmp"
        echo "download failed — drawing the synthetic fallback instead" >&2
        draw_wallpaper "$out"
    fi
}

# Offline fallback, drawn from primitives: bright sky, a soft fan of light rays
# from behind a four-pane flag, and a bloom. Not a trace of the original — it
# just has to survive a machine with no network at install time.
draw_wallpaper() {
    local out="$1" W=2560 H=1440
    local cx=$((W/2)) cy=$((H*60/100))

    magick -size ${W}x${H} radial-gradient:'#4db3e8-#06253f' _sky.png
    magick _sky.png \( -size ${W}x${H} xc:none -fill 'rgba(120,215,255,0.55)' \
        -draw "ellipse $cx,$((H*46/100)) $((W*30/100)),$((H*34/100)) 0,360" \
        -blur 0x60 \) -composite _sky2.png

    # Rays as MVG, because 22 wedges of varying width and opacity is more
    # legible generated than as 22 hand-written -draw arguments.
    python3 - "$W" "$H" "$cx" "$cy" > _rays.mvg <<'PY'
import sys, math
W, H, cx, cy = (int(v) for v in sys.argv[1:5])
print("push graphic-context")
for i in range(22):
    a = -175 + i * (170 / 21)
    span = 1.2 + (i % 4) * 0.5
    r = max(W, H) * 1.4
    a0, a1 = math.radians(a - span), math.radians(a + span)
    pts = " ".join(f"{cx + r * math.cos(t):.0f},{cy + r * math.sin(t):.0f}" for t in (a0, a1))
    print(f"fill rgba(210,240,255,{0.035 + 0.025 * (i % 4):.3f}) stroke none "
          f"polygon {cx},{cy} {pts}")
print("pop graphic-context")
PY
    magick -size ${W}x${H} xc:none -draw @_rays.mvg -blur 0x14 _rays.png

    # Four-pane flag, sheared and given a little perspective so it waves.
    # -virtual-pixel transparent is load-bearing: without it the distort fills
    # the layer's bounding box opaque and the logo arrives in a grey rectangle.
    local L=440 P=200 G=24
    magick -size ${L}x${L} xc:none \
        -fill '#f35325' -draw "roundrectangle 0,0 $P,$P 10,10" \
        -fill '#81bc06' -draw "roundrectangle $((P+G)),0 $((P+G+P)),$P 10,10" \
        -fill '#05a6f0' -draw "roundrectangle 0,$((P+G)) $P,$((P+G+P)) 10,10" \
        -fill '#ffb900' -draw "roundrectangle $((P+G)),$((P+G)) $((P+G+P)),$((P+G+P)) 10,10" \
        _flag.png
    magick _flag.png -background none -virtual-pixel transparent -shear 0x-9 \
        -distort Perspective "0,0 12,26  470,0 470,-6  0,470 0,470  470,470 462,452" \
        -trim +repage -resize $((W*28/100))x _flagw.png

    magick _sky2.png _rays.png -composite \
        \( -size ${W}x${H} xc:none -fill 'rgba(235,250,255,0.42)' \
           -draw "ellipse $cx,$((H*48/100)) $((W*20/100)),$((H*30/100)) 0,360" \
           -blur 0x55 \) -composite \
        \( _flagw.png \) -gravity center -geometry +0-$((H*3/100)) -composite \
        -quality 92 "$out"
    rm -f _sky.png _sky2.png _rays.mvg _rays.png _flag.png _flagw.png
}

# --- Notification-area glyph strip ------------------------------------------
# One 16px white-ish icon per indicator. Flat and monochrome on purpose: Win7's
# tray icons are small and desaturated, and Nerd Font glyphs at this size in a
# textbox sat off the pixel grid.
make_tray_icons() {
    local A='rgba(235,246,255,0.92)'
    # Network: four rising bars.
    magick -size 64x64 xc:none -fill "$A" -stroke none \
        -draw "rectangle 6,44 16,58" -draw "rectangle 20,34 30,58" \
        -draw "rectangle 34,22 44,58" -draw "rectangle 48,8 58,58" \
        -resize 16x16 icons/network.png
    # Volume: speaker cone + two arcs.
    magick -size 64x64 xc:none -fill "$A" -stroke none \
        -draw "polygon 10,26 22,26 34,12 34,52 22,38 10,38" \
        -stroke "$A" -strokewidth 4 -fill none \
        -draw "arc 34,18 50,46 -60,60" -draw "arc 34,10 60,54 -60,60" \
        -resize 16x16 icons/volume.png
    # Action-centre flag.
    magick -size 64x64 xc:none -stroke "$A" -strokewidth 5 -fill none \
        -draw "polyline 16,56 16,10 52,10 52,34 16,34" \
        -resize 16x16 icons/flag.png
}

# --- Quick-launch icons ------------------------------------------------------
# Drawn rather than pulled from the icon theme: menubar.utils.lookup_icon
# returns nil for most names on this machine, and mixing Candy icons into Aero
# chrome looked like two eras stapled together.
make_ql_icons() {
    local S=128
    # Explorer: gold folder with a tab and a gloss band.
    magick -size ${S}x${S} gradient:'#ffd977-#d99b1c' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png \
        -draw "roundrectangle 8,34 120,112 8,8" \
        -draw "roundrectangle 8,20 60,40 6,6" \
        -fill 'rgba(255,255,255,0.35)' -stroke none \
        -draw "roundrectangle 14,40 114,62 6,6" \
        -fill none -stroke 'rgba(120,80,10,0.55)' -strokewidth 3 \
        -draw "roundrectangle 8,34 120,112 8,8" \
        -resize 48x48 icons/ql-explorer.png
    # Browser: blue glass globe with two meridians.
    magick -size ${S}x${S} gradient:'#9fdcff-#0d5a94' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png -draw "circle 64,64 64,10" \
        -fill none -stroke 'rgba(255,255,255,0.75)' -strokewidth 3 \
        -draw "ellipse 64,64 22,54 0,360" \
        -draw "line 12,64 116,64" \
        -stroke 'rgba(255,255,255,0.45)' -draw "arc 20,26 108,74 0,180" \
        -resize 48x48 icons/ql-browser.png
    # Terminal: dark glass panel with a prompt.
    magick -size ${S}x${S} gradient:'#3a4a58-#101820' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png \
        -draw "roundrectangle 8,16 120,112 10,10" \
        -fill none -stroke 'rgba(180,220,255,0.55)' -strokewidth 3 \
        -draw "roundrectangle 8,16 120,112 10,10" \
        -fill '#8be9a0' -stroke none -pointsize 54 \
        -font "$(fc-match -f '%{file}' 'FiraCode Nerd Font' 2>/dev/null || echo DejaVu-Sans-Mono)" \
        -annotate +24+82 '>_' \
        -resize 48x48 icons/ql-terminal.png
    rm -f _g.png
}

# --- Desktop icons -----------------------------------------------------------
# The two Win7 desktop staples that are not just an app launcher. 48px, because
# that is the size Windows uses and scaling 32 up looks soft.
make_desk_icons() {
    local S=192
    # Computer: a monitor with a glass screen, bezel and stand.
    magick -size ${S}x${S} gradient:'#bfd8e8-#5d7c92' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png \
        -draw "roundrectangle 10,24 182,132 10,10" \
        -fill '#0d3f66' -stroke none -draw "roundrectangle 20,34 172,122 4,4" \
        -fill 'rgba(150,215,255,0.55)' -draw "polygon 20,122 172,34 172,58 20,122" \
        -fill '#8ba6b8' -draw "roundrectangle 78,132 114,158 3,3" \
        -draw "roundrectangle 46,158 146,172 6,6" \
        -fill none -stroke 'rgba(40,70,95,0.65)' -strokewidth 3 \
        -draw "roundrectangle 10,24 182,132 10,10" \
        -resize 48x48 icons/desk-computer.png
    # Recycle bin: translucent tapered bin, lid, and the chasing-arrows triangle.
    magick -size ${S}x${S} gradient:'#dff0fa-#7fa8c0' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png \
        -draw "polygon 46,52 146,52 132,178 60,178" \
        -draw "roundrectangle 38,34 154,54 6,6" \
        -fill none -stroke 'rgba(45,85,115,0.60)' -strokewidth 3 \
        -draw "polyline 46,52 60,178 132,178 146,52" \
        -draw "roundrectangle 38,34 154,54 6,6" \
        `# recycling mark: a triangle of arrows reads at 48px, a literal
         # three-arrow logo does not` \
        -stroke '#2f9e46' -strokewidth 8 -fill none \
        -draw "polygon 96,84 126,140 66,140" \
        -stroke '#2f9e46' -strokewidth 5 \
        -draw "polyline 118,126 126,140 112,144" \
        -resize 48x48 icons/desk-recycle.png
    rm -f _g.png
}

# --- Start-menu icons + user picture -----------------------------------------
# Generated rather than harvested from /usr/share/icons: the paths differ per
# machine (dolphin and code have no icon at all here), and a menu that mixes
# Candy icons into Aero chrome looks like two eras stapled together.
make_menu_icons() {
    local S=128
    # Snipping Tool: scissors.
    magick -size ${S}x${S} xc:none -stroke '#4a6b82' -strokewidth 9 -fill none \
        -draw "line 34,30 88,92" -draw "line 94,30 40,92" \
        -fill '#dceaf5' -stroke '#4a6b82' -strokewidth 7 \
        -draw "circle 34,102 34,86" -draw "circle 94,102 94,86" \
        -resize 24x24 icons/sm-snip.png
    # Media Player: play triangle on a glass disc.
    magick -size ${S}x${S} gradient:'#ffb36b-#d1542a' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png -draw "circle 64,64 64,8" \
        -fill white -stroke none -draw "polygon 50,38 94,64 50,90" \
        -fill none -stroke 'rgba(255,255,255,0.5)' -strokewidth 4 \
        -draw "arc 16,16 112,112 200,340" \
        -resize 24x24 icons/sm-media.png
    # Visual Studio Code: angle brackets on a dark panel.
    magick -size ${S}x${S} gradient:'#4a90c2-#1c5a8a' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png \
        -draw "roundrectangle 10,18 118,110 10,10" \
        -fill none -stroke white -strokewidth 8 \
        -draw "polyline 48,44 28,64 48,84" -draw "polyline 80,44 100,64 80,84" \
        -resize 24x24 icons/sm-code.png
    # Passwords: a key.
    magick -size ${S}x${S} xc:none \
        -fill '#e8b830' -stroke '#8a6a10' -strokewidth 5 \
        -draw "circle 44,56 44,26" \
        -fill '#e8b830' -stroke none -draw "rectangle 58,48 108,64" \
        -draw "rectangle 88,64 98,84" -draw "rectangle 68,64 78,78" \
        -fill '#1b2b38' -stroke none -draw "circle 44,56 44,44" \
        -resize 24x24 icons/sm-key.png
    # Shut-down glyph for the menu's bottom-right button.
    magick -size ${S}x${S} xc:none -stroke '#2a4356' -strokewidth 11 -fill none \
        -draw "arc 20,20 108,108 -60,240" \
        -draw "line 64,10 64,52" \
        -resize 20x20 icons/sm-power.png
    rm -f _g.png
}

# Win7's default user picture, near enough: a light glass tile with a bust
# silhouette and the era's thin bevel.
make_avatar() {
    local S=192
    magick -size ${S}x${S} gradient:'#ffd9a8-#e07a2f' _g.png
    magick -size ${S}x${S} xc:none -tile _g.png \
        -draw "roundrectangle 0,0 $((S-1)),$((S-1)) 8,8" \
        `# bust: head + shoulders, the shape Windows used` \
        -fill 'rgba(255,255,255,0.92)' -stroke none \
        -draw "circle 96,74 96,40" \
        -draw "path 'M 40,168 C 40,120 152,120 152,168 Z'" \
        -fill none -stroke 'rgba(255,255,255,0.65)' -strokewidth 4 \
        -draw "roundrectangle 3,3 $((S-4)),$((S-4)) 8,8" \
        -resize 48x48 icons/avatar.png
    rm -f _g.png
}

what="${1:-all}"
run_orb()   { draw_orb "start.png" 100; draw_orb "start-hover.png" 122; }
run_btns()  {
    make_button "titlebar/minimize.png" $BTN_W $BTN_H '#d3ecff' '#7cbde6' "${MIN_GLYPH[@]}"
    make_button "titlebar/maximize.png" $BTN_W $BTN_H '#d3ecff' '#7cbde6' "${MAX_GLYPH[@]}"
    make_button "titlebar/restore.png"  $BTN_W $BTN_H '#d3ecff' '#7cbde6' "${RESTORE_GLYPH[@]}"
    make_button "titlebar/close.png"    42      $BTN_H '#f7b3a9' '#c3372a' "${CLOSE_GLYPH[@]}"
    local b
    for b in minimize maximize restore; do
        magick "titlebar/$b.png" -modulate 116 "titlebar/$b-hover.png"
    done
    magick "titlebar/close.png" -modulate 120 "titlebar/close-hover.png"
}

case "$what" in
    # "all" deliberately leaves the wallpaper alone: it is committed, and a
    # network fetch on every asset tweak is both slow and rude.
    # "all" leaves the fetched assets (orb, wallpaper) alone: they are
    # committed, and hitting the network on every asset tweak is slow and rude.
    all)       run_btns; make_tray_icons; make_ql_icons; make_desk_icons
               make_menu_icons; make_avatar ;;
    orb)           make_orb_official ;;
    orb-draw)      run_orb ;;
    buttons)   run_btns ;;
    wallpaper)     make_wallpaper "wallpaper.jpg" ;;
    wallpaper-draw) draw_wallpaper "wallpaper.jpg" ;;
    misc)      make_tray_icons; make_ql_icons; make_desk_icons
               make_menu_icons; make_avatar ;;
    *) echo "usage: make-assets.sh [all|orb|orb-draw|buttons|wallpaper|wallpaper-draw|misc]" >&2
       exit 1 ;;
esac
echo "assets written to $(pwd)"
