---------------------------
-- Windows 11 Light theme --
---------------------------

local theme_assets = require("beautiful.theme_assets")
local xresources = require("beautiful.xresources")
local dpi = xresources.apply_dpi

local gfs = require("gears.filesystem")
local themes_path = gfs.get_themes_dir()

local theme = {}

theme.font          = "Noto Sans 10"

theme.bg_normal     = "#f3f3f3"
theme.bg_focus      = "#e5e5e5"
theme.bg_urgent     = "#c42b1c"
theme.bg_minimize   = "#d9d9d9"
theme.bg_systray    = theme.bg_normal

theme.fg_normal     = "#1f1f1f"
theme.fg_focus      = "#000000"
theme.fg_urgent     = "#ffffff"
theme.fg_minimize   = "#6b6b6b"

theme.useless_gap   = dpi(4)
theme.border_width  = dpi(1)
theme.border_normal = "#d9d9d9"
theme.border_focus  = "#0078d4"
theme.border_marked = "#c42b1c"

theme.taglist_bg_focus    = "#e5e5e5"
theme.taglist_fg_focus    = "#1f1f1f"
theme.taglist_bg_normal   = "#f3f3f3"
theme.taglist_fg_normal   = "#1f1f1f"

theme.tasklist_bg_focus   = "#e5e5e5"
theme.tasklist_fg_focus   = "#1f1f1f"
theme.tasklist_bg_normal  = "#f3f3f3"
theme.tasklist_fg_normal  = "#1f1f1f"
theme.tasklist_bg_urgent  = "#c42b1c"
theme.tasklist_fg_urgent  = "#ffffff"

local taglist_square_size = dpi(4)
theme.taglist_squares_sel = theme_assets.taglist_squares_sel(
    taglist_square_size, theme.fg_normal
)
theme.taglist_squares_unsel = theme_assets.taglist_squares_unsel(
    taglist_square_size, theme.fg_normal
)

theme.menu_submenu_icon = themes_path.."default/submenu.png"
theme.menu_height = dpi(20)
theme.menu_width  = dpi(140)
theme.menu_bg_normal = "#f3f3f3"
theme.menu_bg_focus  = "#e5e5e5"
theme.menu_fg_normal = "#1f1f1f"
theme.menu_fg_focus  = "#000000"
theme.menu_border_color = "#d9d9d9"
theme.menu_border_width = dpi(1)

local win11_tb = os.getenv("HOME") .. "/.config/awesome/themes/win11/titlebar/"

theme.titlebar_close_button_normal = win11_tb .. "close.png"
theme.titlebar_close_button_focus  = win11_tb .. "close.png"

theme.titlebar_minimize_button_normal = win11_tb .. "minimize.png"
theme.titlebar_minimize_button_focus  = win11_tb .. "minimize.png"

theme.titlebar_ontop_button_normal_inactive = win11_tb .. "maximize.png"
theme.titlebar_ontop_button_focus_inactive  = win11_tb .. "maximize.png"
theme.titlebar_ontop_button_normal_active   = win11_tb .. "maximize.png"
theme.titlebar_ontop_button_focus_active    = win11_tb .. "maximize.png"

theme.titlebar_sticky_button_normal_inactive = win11_tb .. "maximize.png"
theme.titlebar_sticky_button_focus_inactive  = win11_tb .. "maximize.png"
theme.titlebar_sticky_button_normal_active   = win11_tb .. "maximize.png"
theme.titlebar_sticky_button_focus_active    = win11_tb .. "maximize.png"

theme.titlebar_floating_button_normal_inactive = win11_tb .. "maximize.png"
theme.titlebar_floating_button_focus_inactive  = win11_tb .. "maximize.png"
theme.titlebar_floating_button_normal_active   = win11_tb .. "maximize.png"
theme.titlebar_floating_button_focus_active    = win11_tb .. "maximize.png"

theme.titlebar_maximized_button_normal_inactive = win11_tb .. "maximize.png"
theme.titlebar_maximized_button_focus_inactive  = win11_tb .. "maximize.png"
theme.titlebar_maximized_button_normal_active   = win11_tb .. "restore.png"
theme.titlebar_maximized_button_focus_active    = win11_tb .. "restore.png"

theme.wallpaper = os.getenv("HOME") .. "/.config/awesome/themes/win11/wallpaper.jpg"

theme.layout_fairh = themes_path.."default/layouts/fairhw.png"
theme.layout_fairv = themes_path.."default/layouts/fairvw.png"
theme.layout_floating  = themes_path.."default/layouts/floatingw.png"
theme.layout_magnifier = themes_path.."default/layouts/magnifierw.png"
theme.layout_max = themes_path.."default/layouts/maxw.png"
theme.layout_fullscreen = themes_path.."default/layouts/fullscreenw.png"
theme.layout_tilebottom = themes_path.."default/layouts/tilebottomw.png"
theme.layout_tileleft   = themes_path.."default/layouts/tileleftw.png"
theme.layout_tile = themes_path.."default/layouts/tilew.png"
theme.layout_tiletop = themes_path.."default/layouts/tiletopw.png"
theme.layout_spiral  = themes_path.."default/layouts/spiralw.png"
theme.layout_dwindle = themes_path.."default/layouts/dwindlew.png"
theme.layout_cornernw = themes_path.."default/layouts/cornernww.png"
theme.layout_cornerne = themes_path.."default/layouts/cornernew.png"
theme.layout_cornersw = themes_path.."default/layouts/cornersww.png"
theme.layout_cornerse = themes_path.."default/layouts/cornersew.png"

theme.awesome_icon = theme_assets.awesome_icon(
    theme.menu_height, theme.bg_focus, theme.fg_focus
)

theme.icon_theme = nil

return theme
