---------------------------------------------------------
-- Windows 7 (Aero) Theme for AwesomeWM
-- Dark glass base, Aero light-blue accent. Reuses rc.lua's
-- wibar by exposing the same cat_* palette variable names.
---------------------------------------------------------

local theme_assets = require("beautiful.theme_assets")
local xresources   = require("beautiful.xresources")
local dpi          = xresources.apply_dpi
local gfs          = require("gears.filesystem")
local themes_path  = gfs.get_themes_dir()

local theme = {}

-- Palette (Aero-inspired; cat_* names kept for rc.lua compatibility)
theme.cat_base      = "#1c2b3a"  -- aero glass dark blue
theme.cat_mantle    = "#142231"
theme.cat_crust     = "#0d1822"
theme.cat_surface0  = "#2e4760"
theme.cat_surface1  = "#3d5a78"
theme.cat_surface2  = "#4d6f90"
theme.cat_text      = "#eaf3fb"
theme.cat_subtext1  = "#cfe0ef"
theme.cat_subtext0  = "#b3c9dd"
theme.cat_overlay0  = "#7fa0bd"
theme.cat_overlay1  = "#97b4ce"
theme.cat_mauve     = "#4aa3df"  -- accent: Aero blue glow
theme.cat_blue      = "#1ba1e2"
theme.cat_sky       = "#5bc8f5"
theme.cat_teal      = "#2dd4bf"
theme.cat_green     = "#4caf50"
theme.cat_yellow    = "#ffc40d"
theme.cat_peach     = "#ff8c00"
theme.cat_red       = "#e51400"
theme.cat_pink      = "#f472d0"

theme.font          = "FiraCode Nerd Font 10"

theme.bg_normal     = theme.cat_base
theme.bg_focus      = theme.cat_surface0
theme.bg_urgent     = theme.cat_red
theme.bg_minimize   = theme.cat_surface1
theme.bg_systray    = theme.cat_mantle

theme.fg_normal     = theme.cat_text
theme.fg_focus      = theme.cat_mauve
theme.fg_urgent     = theme.cat_base
theme.fg_minimize   = theme.cat_overlay0

theme.useless_gap   = dpi(6)
theme.border_width  = dpi(2)
theme.border_normal = theme.cat_surface0
theme.border_focus  = theme.cat_mauve
theme.border_marked = theme.cat_peach

-- Taglist
theme.taglist_bg_focus     = theme.cat_mauve
theme.taglist_fg_focus     = theme.cat_base
theme.taglist_bg_occupied  = theme.cat_surface0
theme.taglist_fg_occupied  = theme.cat_text
theme.taglist_bg_empty     = theme.cat_mantle
theme.taglist_fg_empty     = theme.cat_overlay0
theme.taglist_bg_urgent    = theme.cat_red
theme.taglist_fg_urgent    = theme.cat_base
theme.taglist_spacing      = dpi(4)

-- Tasklist
theme.tasklist_bg_normal   = theme.cat_mantle
theme.tasklist_fg_normal   = theme.cat_subtext1
theme.tasklist_bg_focus    = theme.cat_surface0
theme.tasklist_fg_focus    = theme.cat_mauve
theme.tasklist_bg_minimize = theme.cat_mantle
theme.tasklist_fg_minimize = theme.cat_overlay0
theme.tasklist_bg_urgent   = theme.cat_red
theme.tasklist_fg_urgent   = theme.cat_base
theme.tasklist_spacing     = dpi(4)
theme.tasklist_disable_icon = false
theme.tasklist_plain_task_name = true

-- Prompt
theme.prompt_bg     = theme.cat_mantle
theme.prompt_fg     = theme.cat_mauve

-- Hotkeys popup (super+F1)
theme.hotkeys_bg              = theme.cat_base
theme.hotkeys_fg              = theme.cat_text
theme.hotkeys_border_width    = dpi(2)
theme.hotkeys_border_color    = theme.cat_mauve
theme.hotkeys_modifiers_fg    = theme.cat_blue
theme.hotkeys_label_bg        = theme.cat_mauve
theme.hotkeys_label_fg        = theme.cat_base
theme.hotkeys_group_margin    = dpi(40)
theme.hotkeys_font            = "FiraCode Nerd Font 10"
theme.hotkeys_description_font = "FiraCode Nerd Font 9"

-- Notifications (naughty)
theme.notification_bg           = theme.cat_mantle
theme.notification_fg           = theme.cat_text
theme.notification_border_width = dpi(2)
theme.notification_border_color = theme.cat_mauve
theme.notification_margin       = dpi(12)
theme.notification_font         = "FiraCode Nerd Font 10"

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

-- Taglist decorator squares (subtle)
local taglist_square_size = dpi(4)
theme.taglist_squares_sel = theme_assets.taglist_squares_sel(
    taglist_square_size, theme.cat_mauve
)
theme.taglist_squares_unsel = theme_assets.taglist_squares_unsel(
    taglist_square_size, theme.cat_overlay0
)

-- Titlebars
theme.titlebar_bg_normal = theme.cat_mantle
theme.titlebar_bg_focus  = theme.cat_base
theme.titlebar_fg_normal = theme.cat_subtext1
theme.titlebar_fg_focus  = theme.cat_mauve

-- Layout icons (stock awesome icons)
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
