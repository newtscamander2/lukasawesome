---------------------------------------------------------
-- Dr460nized — Garuda-inspired Dracula neon for AwesomeWM
-- Hot pink accent on near-black; pairs with picom's pink
-- glow (see picom.conf shadow-color) and heavy blur.
-- cat_* variable names are kept for rc.lua compatibility.
---------------------------------------------------------

local theme_assets = require("beautiful.theme_assets")
local xresources   = require("beautiful.xresources")
local dpi          = xresources.apply_dpi
local gfs          = require("gears.filesystem")
local gshape       = require("gears.shape")
local gstring      = require("gears.string")
local themes_path  = gfs.get_themes_dir()

local theme = {}

-- Palette (Dracula / Garuda Dr460nized; accent = cat_mauve = hot pink)
theme.cat_base      = "#1b1b28"
theme.cat_mantle    = "#15151f"
theme.cat_crust     = "#0f0f17"
theme.cat_surface0  = "#282a36"
theme.cat_surface1  = "#44475a"
theme.cat_surface2  = "#565872"
theme.cat_text      = "#f8f8f2"
theme.cat_subtext1  = "#d4d4e0"
theme.cat_subtext0  = "#aeaec2"
theme.cat_overlay0  = "#6272a4"
theme.cat_overlay1  = "#7b88b8"
theme.cat_mauve     = "#ff79c6"
theme.cat_blue      = "#bd93f9"
theme.cat_sky       = "#8be9fd"
theme.cat_teal      = "#8be9fd"
theme.cat_green     = "#50fa7b"
theme.cat_yellow    = "#f1fa8c"
theme.cat_peach     = "#ffb86c"
theme.cat_red       = "#ff5555"
theme.cat_pink      = "#ff92d0"

-- Derived accent shades. Neon only reads as neon when it has a top-lit
-- gradient and a rim: mauve alone paints flat. Kept as cat_* tokens so rc.lua
-- can reuse them instead of re-inventing literals.
theme.cat_mauve_deep = "#e35fae"  -- mauve, ~12% darker: bottom stop of pink gradients
theme.cat_mauve_rim  = "#ffc2e6"  -- mauve blown out to near-white: 1px rim light
theme.cat_mauve_dim  = "#7a4a68"  -- mauve at ~40% over base: pink cast without shouting
theme.cat_red_rim    = "#ff9b9b"  -- same rim trick for the urgent state
theme.cat_surface_hi = "#33354a"  -- surface0 lifted: top stop of "raised chip" gradients

---------------------------------------------------------------
-- Type scale
-- The rice used to be one font at one weight everywhere. Two cuts of
-- FiraCode fix that without adding a dependency:
--   * "Propo"  (proportional) — headings and hero numbers. Reads as design.
--   * plain    (mono)         — data, chrome, anything inside a pill.
-- Deliberately non-linear: the display tier steps by ~1.5x so hierarchy is
-- unmistakable at a glance, the chrome tier steps by 1pt because those three
-- roles must feel like one voice at three densities.
--   display 30  ->  h1 20  ->  h2 13   (~1.5x jumps)
--   body 10     ->  label 9 ->  micro 8
-- Weight keywords are Pango's own (Light/Medium/Semi-Bold), verified to
-- resolve to real FiraCode faces via fontconfig — not family-name suffixes.
-- ALL of these are NEW, OPTIONAL keys: rc.lua must read them defensively,
-- e.g. `font = beautiful.font_h2 or beautiful.font`, so the arch/ubuntu/
-- windows7 themes (which do not define them) keep working unchanged.
---------------------------------------------------------------
theme.font           = "FiraCode Nerd Font 10"                  -- base: unchanged on purpose
theme.font_display   = "FiraCode Nerd Font Propo Light 30"      -- hero clock / one big number per tile
theme.font_h1        = "FiraCode Nerd Font Propo Light 20"      -- tile titles, greeting line
theme.font_h2        = "FiraCode Nerd Font Propo Medium 13"     -- section heads inside a tile
theme.font_body      = "FiraCode Nerd Font 10"                  -- prose, menus, notifications (== theme.font)
theme.font_label     = "FiraCode Nerd Font Medium 9"            -- wibar pill values, list rows
theme.font_micro     = "FiraCode Nerd Font Semi-Bold 8"         -- uppercase eyebrow labels (see micro_markup)
theme.font_glyph     = "FiraCode Nerd Font 13"                  -- nerd-font icon cells in pills
theme.font_glyph_lg  = "FiraCode Nerd Font 18"                  -- launcher / tile header glyphs

-- Micro-label convention: UPPERCASE + tracking. At 8pt all-caps is cramped
-- and unreadable without it; tracking is what turns it into a design element.
-- Pango wants 1024ths of a point, so 1229 ~= 1.2pt.
theme.font_micro_spacing = 1229

--- Build a letter-spaced uppercase micro label.
-- Usage in rc.lua (guard it, the sibling themes lack this key):
--   local micro = beautiful.micro_markup
--   txt:set_markup(micro and micro("cpu load", beautiful.cat_subtext0) or "CPU LOAD")
-- @tparam string text  Plain text; XML-escaped here, so pass raw text only.
-- @tparam[opt] string col  Any pango-safe color string.
-- @treturn string Pango markup.
theme.micro_markup = function(text, col)
    return string.format(
        "<span font_desc='%s' letter_spacing='%d'%s>%s</span>",
        theme.font_micro,
        theme.font_micro_spacing,
        col and (" foreground='" .. col .. "'") or "",
        gstring.xml_escape(tostring(text):upper())
    )
end

theme.bg_normal     = theme.cat_base
theme.bg_focus      = theme.cat_surface0
theme.bg_urgent     = theme.cat_red
theme.bg_minimize   = theme.cat_surface1
-- Must match the bg of the tray chip in rc.lua: xembed icons cannot be
-- transparent and always paint on this color.
theme.bg_systray    = theme.cat_surface0
theme.systray_icon_spacing = dpi(4)

theme.fg_normal     = theme.cat_text
theme.fg_focus      = theme.cat_mauve
theme.fg_urgent     = theme.cat_base
theme.fg_minimize   = theme.cat_overlay0

theme.useless_gap   = dpi(14)
theme.border_width  = dpi(2)
-- Focused window gets a wider border so the active window is easy to spot
theme.border_width_focus = dpi(3)
-- Unfocused borders keep a faint pink cast instead of neutral grey: that is
-- what makes the whole session look themed rather than "dark grey WM with a
-- pink highlight", and it makes the focused neon border a step up in the same
-- hue rather than a hue change. rc.lua reuses border_normal for desktop tiles.
theme.border_normal = theme.cat_mauve_dim
theme.border_focus  = theme.cat_mauve
theme.border_marked = theme.cat_peach

---------------------------------------------------------------
-- Taglist / tasklist shared geometry
--
-- IMPORTANT (verified in /usr/share/awesome/lib/awful/widget/common.lua,
-- awesome 4.3): common.list_update() runs
--     cache.bgb.shape              = item_args.shape
--     cache.bgb.shape_border_width = item_args.shape_border_width
--     cache.bgb.shape_border_color = item_args.shape_border_color
-- unconditionally on EVERY update, where item_args comes from the theme. So a
-- `shape =` set on the background_role widget inside rc.lua's widget_template
-- is overwritten with nil on the first refresh — the pills were rendering as
-- hard rectangles. The theme is therefore the ONLY working place to define
-- taglist/tasklist shapes, which is why they live here now.
---------------------------------------------------------------
local function pill(r) return function(cr, w, h) gshape.rounded_rect(cr, w, h, r) end end
local PILL_RADIUS = dpi(6)   -- must equal UI.radius_inner in rc.lua

-- Pill height: wibar is 50px, minus the strip's outer margin (4 top / 2 bottom)
-- and inner margin (4 / 4) => 36. Used only as the end point of the vertical
-- gradients; cairo pads past the last stop, so if the bar height changes the
-- gradient flattens gracefully instead of breaking.
local PILL_H = 36

local function top_lit(top, bottom)
    return { type = "linear", from = { 0, 0 }, to = { 0, PILL_H },
             stops = { { 0, top }, { 1, bottom } } }
end

-- Taglist
-- Three clearly different objects instead of near-identical dark chips:
--   selected = neon gradient pill lit from above + near-white rim
--   occupied = raised chip, hairline pink border ("has windows")
--   empty    = ghost outline only, so the occupied ones group visually
theme.taglist_font         = theme.font_glyph   -- tag names are nerd glyphs; 10pt was too timid
-- Selected: a flat fill looks like paint, a top-lit gradient looks like light.
-- Pairs with picom's pink shadow, which does the actual bloom outside the pill.
theme.taglist_bg_focus     = { type = "linear", from = { 0, 0 }, to = { 0, PILL_H },
                               stops = { { 0,   theme.cat_pink },
                                         { 0.5, theme.cat_mauve },
                                         { 1,   theme.cat_mauve_deep } } }
theme.taglist_fg_focus     = theme.cat_crust    -- crust > base: max contrast on hot pink
theme.taglist_bg_occupied  = top_lit(theme.cat_surface_hi, theme.cat_surface0)
theme.taglist_fg_occupied  = theme.cat_mauve
theme.taglist_bg_empty     = theme.cat_crust .. "40"  -- 25%: darker than the bar, reads as a recess
theme.taglist_fg_empty     = theme.cat_overlay0
theme.taglist_bg_urgent    = top_lit(theme.cat_red, "#d63b3b")
theme.taglist_fg_urgent    = theme.cat_crust

-- Shapes + borders. The base pair applies to the occupied/normal state; the
-- _focus / _empty / _urgent overrides are what create the visual grouping.
theme.taglist_shape                     = pill(PILL_RADIUS)
theme.taglist_shape_border_width        = dpi(1)
theme.taglist_shape_border_color        = theme.cat_mauve .. "59"      -- 35% pink hairline
theme.taglist_shape_focus               = pill(PILL_RADIUS)
theme.taglist_shape_border_width_focus  = dpi(1)
theme.taglist_shape_border_color_focus  = theme.cat_mauve_rim          -- rim light: pill sits "above" the bar
-- Empty tags get the same silhouette but only an outline, so a run of occupied
-- tags reads as a block and the empties recede.
theme.taglist_shape_border_width_empty  = dpi(1)
theme.taglist_shape_border_color_empty  = theme.cat_surface1 .. "80"   -- 50% grey, no hue
theme.taglist_shape_urgent              = pill(PILL_RADIUS)
theme.taglist_shape_border_width_urgent = dpi(2)   -- thicker: urgency must win the glance
theme.taglist_shape_border_color_urgent = theme.cat_red_rim

-- NOTE: taglist_spacing is ignored — rc.lua passes an explicit
-- `layout = { spacing = 4, ... }`, which takes precedence. Kept as
-- documentation of the intended value should that layout ever be dropped.
theme.taglist_spacing      = dpi(4)

-- Tasklist
theme.tasklist_bg_normal   = theme.cat_mantle
theme.tasklist_fg_normal   = theme.cat_subtext1
theme.tasklist_bg_focus    = top_lit(theme.cat_surface_hi, theme.cat_surface0)
theme.tasklist_fg_focus    = theme.cat_mauve
theme.tasklist_bg_minimize = theme.cat_mantle
theme.tasklist_fg_minimize = theme.cat_overlay0
theme.tasklist_bg_urgent   = theme.cat_red
theme.tasklist_fg_urgent   = theme.cat_crust
theme.tasklist_spacing     = dpi(4)   -- also overridden by rc.lua's explicit layout
theme.tasklist_disable_icon = false
theme.tasklist_plain_task_name = true
-- Titles sit in the chrome tier. FiraCode is monospaced, so the heavier focused
-- weight has identical advance widths — no pill re-flow when focus moves.
theme.tasklist_font        = theme.font_label
theme.tasklist_font_focus  = "FiraCode Nerd Font Semi-Bold 9"
-- Same clobbering rule as the taglist: these restore rc.lua's rounded pill.
theme.tasklist_shape                      = pill(PILL_RADIUS)
theme.tasklist_shape_focus                = pill(PILL_RADIUS)
theme.tasklist_shape_border_width_focus   = dpi(1)
theme.tasklist_shape_border_color_focus   = theme.cat_mauve .. "73"    -- 45%: quieter than a tag pill
theme.tasklist_shape_minimized            = pill(PILL_RADIUS)
theme.tasklist_shape_urgent               = pill(PILL_RADIUS)
theme.tasklist_shape_border_width_urgent  = dpi(1)
theme.tasklist_shape_border_color_urgent  = theme.cat_red_rim

-- Prompt (beautiful.prompt_font is honoured by awful.prompt)
theme.prompt_bg     = theme.cat_mantle
theme.prompt_fg     = theme.cat_mauve
theme.prompt_font   = theme.font_label   -- lives in a wibar pill, so chrome tier

-- Hotkeys popup (super+F1)
theme.hotkeys_bg              = theme.cat_base .. "e6"  -- frosted (picom blurs shaped wiboxes)
theme.hotkeys_fg              = theme.cat_text
theme.hotkeys_border_width    = dpi(2)
theme.hotkeys_border_color    = theme.cat_mauve
theme.hotkeys_modifiers_fg    = theme.cat_blue
theme.hotkeys_label_bg        = theme.cat_mauve
theme.hotkeys_label_fg        = theme.cat_base
theme.hotkeys_group_margin    = dpi(40)
-- Group headers get the heading tier, key descriptions the chrome tier: the
-- popup was previously one size and read as an undifferentiated wall.
theme.hotkeys_font            = theme.font_h2
theme.hotkeys_description_font = theme.font_label

-- Notifications (naughty)
-- Frosted like the hotkeys popup: alpha + a shaped wibox is what picom blurs.
theme.notification_bg           = theme.cat_mantle .. "e6"
theme.notification_fg           = theme.cat_text
theme.notification_border_width = dpi(2)
theme.notification_border_color = theme.cat_mauve
theme.notification_margin       = dpi(14)   -- was 12; the 2px neon border needs breathing room
theme.notification_font         = theme.font_body
-- Cap the width so long messages wrap into a readable column instead of a
-- screen-wide strip, and pin icon size so app icons cannot dictate popup height.
theme.notification_max_width    = dpi(420)
theme.notification_icon_size    = dpi(48)
theme.notification_shape        = function(cr, w, h) gshape.rounded_rect(cr, w, h, dpi(10)) end

-- Menu
theme.menu_submenu_icon = themes_path .. "default/submenu.png"
theme.menu_height       = dpi(22)
theme.menu_width        = dpi(160)
theme.menu_bg_normal    = theme.cat_mantle
theme.menu_fg_normal    = theme.cat_text
theme.menu_bg_focus     = theme.cat_surface0
theme.menu_fg_focus     = theme.cat_mauve
theme.menu_border_color = theme.cat_mauve
theme.menu_border_width = dpi(2)
theme.menu_font         = theme.font_body   -- honoured by awful.menu (menu_font -> font)

-- Taglist decorator squares: deliberately NOT set.
-- Two reasons, both verified in awful/widget/taglist.lua + widget/common.lua:
--   1. They are delivered as `bg_image` and painted unscaled over the pill, so
--      with our custom template they land as a stray 4px dot fighting the
--      glyph cell and the gradient.
--   2. taglist_label() sets is_selected = true whenever squares_sel exists and
--      the focused client is on that tag, and that branch SKIPS
--      bg_occupied/fg_occupied entirely — so having them silently broke the
--      occupied styling for multi-tagged/sticky clients.
-- The gradient + border states above carry the same information.
-- (theme_assets is still used for awesome_icon below.)

-- Titlebars (kept simple — currently disabled in rules, but ready if enabled)
theme.titlebar_bg_normal = theme.cat_mantle
theme.titlebar_bg_focus  = theme.cat_base
theme.titlebar_fg_normal = theme.cat_subtext1
theme.titlebar_fg_focus  = theme.cat_mauve

-- Layout icons (reuse stock awesome icons — they're just layout indicators)
theme.layout_fairh       = themes_path .. "default/layouts/fairhw.png"
theme.layout_fairv       = themes_path .. "default/layouts/fairvw.png"
theme.layout_floating    = themes_path .. "default/layouts/floatingw.png"
theme.layout_magnifier   = themes_path .. "default/layouts/magnifierw.png"
theme.layout_max         = themes_path .. "default/layouts/maxw.png"
theme.layout_fullscreen  = themes_path .. "default/layouts/fullscreenw.png"
theme.layout_tilebottom  = themes_path .. "default/layouts/tilebottomw.png"
theme.layout_tileleft    = themes_path .. "default/layouts/tileleftw.png"
theme.layout_tile        = themes_path .. "default/layouts/tilew.png"
theme.layout_tiletop     = themes_path .. "default/layouts/tiletopw.png"
theme.layout_spiral      = themes_path .. "default/layouts/spiralw.png"
theme.layout_dwindle     = themes_path .. "default/layouts/dwindlew.png"
theme.layout_cornernw    = themes_path .. "default/layouts/cornernww.png"
theme.layout_cornerne    = themes_path .. "default/layouts/cornernew.png"
theme.layout_cornersw    = themes_path .. "default/layouts/cornersww.png"
theme.layout_cornerse    = themes_path .. "default/layouts/cornersew.png"

theme.awesome_icon = theme_assets.awesome_icon(
    theme.menu_height, theme.cat_mauve, theme.cat_base
)

theme.icon_theme = nil

-- Wallpaper unset — rc.lua handles wallpapers via feh
theme.wallpaper = nil

return theme
