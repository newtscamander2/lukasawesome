---------------------------------------------------------------
-- Windows 7 (Aero) theme for AwesomeWM
--
-- Paired with rc_windows7.lua, NOT with rc.lua: windows7 is a full
-- desktop mimic like win11, not a palette swap of the Arch layout.
--
-- The look rests on two ideas:
--   1. Everything is a vertical gradient. Aero's glass is a light top
--      half over a darker bottom half plus a 1px highlight under the
--      top edge. awesome accepts gears.color gradient strings anywhere
--      a colour goes, so the chrome is real gradients, not flat fills.
--   2. Chrome is LIGHT, the desktop is DARK. Window frames are pale
--      blue glass; the wallpaper and taskbar are deep blue.
--
-- Alpha is meaningful here: picom blurs whatever shows through, which
-- is what turns "translucent panel" into "frosted glass".
---------------------------------------------------------------

local theme_assets = require("beautiful.theme_assets")
local xresources   = require("beautiful.xresources")
local dpi          = xresources.apply_dpi
local gfs          = require("gears.filesystem")
local themes_path  = gfs.get_themes_dir()
local w7           = os.getenv("HOME") .. "/.config/awesome/themes/windows7/"

local theme = {}

---------------------------------------------------------------
-- Palette
---------------------------------------------------------------
-- Aero blues, light to dark.
theme.aero_ice     = "#f2f9ff"   -- glass highlight / titlebar top
theme.aero_pale    = "#dcecf9"   -- glass body
theme.aero_light   = "#b4d8f0"
theme.aero_mid     = "#5b9bc8"
theme.aero_accent  = "#1ba1e2"   -- Win7-era "Metro" cyan-blue
theme.aero_deep    = "#1c4a70"
theme.aero_navy    = "#0d2537"
theme.aero_ink     = "#0a1a26"

theme.w7_text      = "#12354f"   -- text on light glass
theme.w7_text_dim  = "#4a708c"
theme.w7_text_lite = "#eaf4ff"   -- text on dark glass (taskbar)
theme.w7_text_lite_dim = "#a8c8de"
theme.w7_red       = "#c3372a"
theme.w7_green     = "#4caf50"
theme.w7_amber     = "#ffc40d"

---------------------------------------------------------------
-- Gradients (gears.color linear syntax: linear:x0,y0:x1,y1:stop,colour:…)
---------------------------------------------------------------
theme.taskbar_height = dpi(40)
theme.titlebar_height = dpi(28)

-- Taskbar: dark blue glass. Bright hairline at the very top, then a
-- lighter upper band falling to near-black — Win7's bar is darkest at
-- the bottom edge, which is what makes it feel seated on the screen.
theme.taskbar_bg = "linear:0,0:0," .. theme.taskbar_height ..
    ":0,#bcdcf2cc:0.04,#5e9cc6b3:0.06,#2b5f87b3:0.55,#12354ec4:1,#071620d9"

-- Task buttons. Normal is barely there; focus is a lit glass capsule.
theme.taskbtn_normal = "linear:0,0:0," .. dpi(30) ..
    ":0,#ffffff26:0.5,#ffffff14:1,#ffffff08"
theme.taskbtn_focus = "linear:0,0:0," .. dpi(30) ..
    ":0,#ffffff73:0.06,#d6ecfa66:0.5,#9fcbe859:1,#6fa8cc4d"
theme.taskbtn_hover = "linear:0,0:0," .. dpi(30) ..
    ":0,#ffffff59:0.5,#cbe4f53d:1,#8fbcd92e"
theme.taskbtn_minimized = "linear:0,0:0," .. dpi(30) ..
    ":0,#ffffff1a:1,#ffffff0a"

-- Titlebars: pale glass. Focused is brighter and slightly more opaque —
-- Aero's unfocused frames wash out rather than change hue.
theme.titlebar_grad_focus = "linear:0,0:0," .. theme.titlebar_height ..
    ":0,#fbfdffe6:0.08,#e8f3fde0:0.55,#c9e0f0d9:1,#a8c9e0d9"
theme.titlebar_grad_normal = "linear:0,0:0," .. theme.titlebar_height ..
    ":0,#f0f5f9c4:0.08,#dfe9f0bd:0.55,#c8d6e0b8:1,#b2c3d0b8"

---------------------------------------------------------------
-- Fonts
---------------------------------------------------------------
-- Segoe UI is not installable from the repos; Noto Sans is the closest
-- humanist sans present on the machine. Sizes are Win7's: 9pt chrome.
theme.font           = "Noto Sans 9"
theme.font_taskbar   = "Noto Sans 9"
theme.font_title     = "Noto Sans Bold 9"
theme.font_clock     = "Noto Sans 9"
theme.font_clock_sub = "Noto Sans 8"

---------------------------------------------------------------
-- Core awesome keys
---------------------------------------------------------------
theme.bg_normal   = theme.aero_navy
theme.bg_focus    = theme.aero_deep
theme.bg_urgent   = theme.w7_red
theme.bg_minimize = theme.aero_ink
theme.bg_systray  = "#00000000"    -- the taskbar gradient shows through

theme.fg_normal   = theme.w7_text_lite
theme.fg_focus    = "#ffffff"
theme.fg_urgent   = "#ffffff"
theme.fg_minimize = theme.w7_text_lite_dim

-- Aero's window frames are thick translucent glass. A solid 1px border
-- would read as "tiling WM"; 4px of pale blue at 60% reads as the frame.
theme.useless_gap   = dpi(6)
theme.border_width  = dpi(4)
theme.border_normal = "#8fa8ba8c"
theme.border_focus  = "#b4dcf5d9"
theme.border_marked = theme.w7_amber

---------------------------------------------------------------
-- Tasklist — the wide, labelled buttons that date the desktop
---------------------------------------------------------------
local function tb_shape(cr, w, h)
    require("gears.shape").rounded_rect(cr, w, h, dpi(3))
end

theme.tasklist_bg_normal   = theme.taskbtn_normal
theme.tasklist_bg_focus    = theme.taskbtn_focus
theme.tasklist_bg_minimize = theme.taskbtn_minimized
theme.tasklist_bg_urgent   = theme.w7_red
theme.tasklist_fg_normal   = theme.w7_text_lite
theme.tasklist_fg_focus    = "#ffffff"
theme.tasklist_fg_minimize = theme.w7_text_lite_dim
theme.tasklist_fg_urgent   = "#ffffff"
-- awful.widget.common re-reads shape from the THEME on every update and
-- overwrites whatever the widget_template set, so it has to live here.
theme.tasklist_shape          = tb_shape
theme.tasklist_shape_focus    = tb_shape
theme.tasklist_shape_minimize = tb_shape
theme.tasklist_shape_urgent   = tb_shape
theme.tasklist_shape_border_width       = 1
theme.tasklist_shape_border_color       = "#ffffff2e"
theme.tasklist_shape_border_width_focus = 1
theme.tasklist_shape_border_color_focus = "#ffffff6b"
theme.tasklist_spacing         = dpi(3)
theme.tasklist_disable_icon    = false
theme.tasklist_plain_task_name = true

---------------------------------------------------------------
-- Taglist — Win7 has no workspaces, so these are deliberately tiny
-- glass pips rather than the Arch theme's labelled pills.
---------------------------------------------------------------
theme.taglist_bg_focus    = theme.taskbtn_focus
theme.taglist_fg_focus    = "#ffffff"
theme.taglist_bg_occupied = theme.taskbtn_normal
theme.taglist_fg_occupied = theme.w7_text_lite
theme.taglist_bg_empty    = "#ffffff0a"
theme.taglist_fg_empty    = theme.w7_text_lite_dim
theme.taglist_bg_urgent   = theme.w7_red
theme.taglist_fg_urgent   = "#ffffff"
theme.taglist_shape       = tb_shape
theme.taglist_shape_focus = tb_shape
theme.taglist_shape_empty = tb_shape
theme.taglist_spacing     = dpi(3)

---------------------------------------------------------------
-- Titlebar button assets (generated by make-assets.sh)
---------------------------------------------------------------
local tb = w7 .. "titlebar/"
theme.titlebar_bg_focus  = theme.titlebar_grad_focus
theme.titlebar_bg_normal = theme.titlebar_grad_normal
theme.titlebar_fg_focus  = theme.w7_text
theme.titlebar_fg_normal = theme.w7_text_dim

theme.titlebar_close_button_normal = tb .. "close.png"
theme.titlebar_close_button_focus  = tb .. "close.png"
theme.titlebar_close_button_normal_hover = tb .. "close-hover.png"
theme.titlebar_close_button_focus_hover  = tb .. "close-hover.png"

theme.titlebar_minimize_button_normal = tb .. "minimize.png"
theme.titlebar_minimize_button_focus  = tb .. "minimize.png"
theme.titlebar_minimize_button_normal_hover = tb .. "minimize-hover.png"
theme.titlebar_minimize_button_focus_hover  = tb .. "minimize-hover.png"

-- maximized_button has four states (normal/focus x active/inactive):
-- "active" means the window IS maximized, so it shows the restore glyph.
theme.titlebar_maximized_button_normal_inactive = tb .. "maximize.png"
theme.titlebar_maximized_button_focus_inactive  = tb .. "maximize.png"
theme.titlebar_maximized_button_normal_active   = tb .. "restore.png"
theme.titlebar_maximized_button_focus_active    = tb .. "restore.png"
theme.titlebar_maximized_button_normal_inactive_hover = tb .. "maximize-hover.png"
theme.titlebar_maximized_button_focus_inactive_hover  = tb .. "maximize-hover.png"
theme.titlebar_maximized_button_normal_active_hover   = tb .. "restore-hover.png"
theme.titlebar_maximized_button_focus_active_hover    = tb .. "restore-hover.png"

-- Not shown in the Aero layout, but awesome warns when they are missing.
for _, role in ipairs({ "ontop", "sticky", "floating" }) do
    for _, st in ipairs({ "normal_inactive", "focus_inactive",
                          "normal_active", "focus_active" }) do
        theme["titlebar_" .. role .. "_button_" .. st] = tb .. "maximize.png"
    end
end

---------------------------------------------------------------
-- Menus, notifications, hotkeys popup — all on light glass
---------------------------------------------------------------
theme.menu_submenu_icon = themes_path .. "default/submenu.png"
theme.menu_height       = dpi(24)
theme.menu_width        = dpi(180)
theme.menu_bg_normal    = "#f4f9fdf2"
theme.menu_fg_normal    = theme.w7_text
theme.menu_bg_focus     = theme.aero_light
theme.menu_fg_focus     = theme.w7_text
theme.menu_border_color = "#9fc4dd"
theme.menu_border_width = dpi(1)

theme.notification_bg           = "#eef6fcf2"
theme.notification_fg           = theme.w7_text
theme.notification_border_width = dpi(1)
theme.notification_border_color = "#9fc4dd"
theme.notification_margin       = dpi(12)
theme.notification_font         = "Noto Sans 9"
theme.notification_shape        = function(cr, w, h)
    require("gears.shape").rounded_rect(cr, w, h, dpi(6))
end

theme.hotkeys_bg               = "#eef6fcf7"
theme.hotkeys_fg               = theme.w7_text
theme.hotkeys_border_width     = dpi(1)
theme.hotkeys_border_color     = "#9fc4dd"
theme.hotkeys_modifiers_fg     = theme.aero_mid
theme.hotkeys_label_bg         = theme.aero_accent
theme.hotkeys_label_fg         = "#ffffff"
theme.hotkeys_group_margin     = dpi(8)
theme.hotkeys_font             = "Noto Sans 9"
theme.hotkeys_description_font = "Noto Sans 8"

theme.prompt_bg = "#00000000"
theme.prompt_fg = theme.w7_text_lite

---------------------------------------------------------------
-- Assets
---------------------------------------------------------------
theme.w7_start_orb       = w7 .. "start.png"
theme.w7_start_orb_hover = w7 .. "start-hover.png"
theme.w7_icons           = w7 .. "icons/"
-- rc_windows7.lua sets this with feh; beautiful.wallpaper would be applied
-- before the compositor starts and flash the default grey.
theme.wallpaper = w7 .. "wallpaper.jpg"

theme.layout_tile        = themes_path .. "default/layouts/tilew.png"
theme.layout_floating    = themes_path .. "default/layouts/floatingw.png"
theme.layout_max         = themes_path .. "default/layouts/maxw.png"
theme.layout_fullscreen  = themes_path .. "default/layouts/fullscreenw.png"

theme.awesome_icon = theme_assets.awesome_icon(
    theme.menu_height, theme.aero_accent, "#ffffff")

theme.icon_theme = nil

return theme
