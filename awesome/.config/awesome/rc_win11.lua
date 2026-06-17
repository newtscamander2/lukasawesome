-- Windows 11 Theme for AwesomeWM
-- Loaded by rc.lua's dispatcher when active_theme == "win11".

pcall(require, "luarocks.loader")

local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys")

-- Near-fullscreen popup with small font + tight spacing so every group fits on
-- a single page — no paging. width/height clamp to the screen work area.
local hotkeys_widget = require("awful.hotkeys_popup.widget").new({
    width            = 1860,
    height           = 1040,
    group_margin     = 8,
    font             = "FiraCode Nerd Font 9",
    description_font = "FiraCode Nerd Font 8",
})

-- Informational cheatsheets shown in the super+F1 popup (nvim, claude code).
require("awful.hotkeys_popup.widget").add_hotkeys({
    ["Nvim: Files"] = {{
        modifiers = {},
        keys = {
            ["Space e"]   = "toggle file explorer",
            ["Enter / o"] = "tree: open file",
            ["C-v / C-x"] = "tree: vertical / horizontal split",
            ["C-t"]       = "tree: open in new tab",
            ["Space w"]   = "save (:w)",
            ["Space q"]   = "quit (:q)",
            [":bd"]       = "close current buffer",
        },
    }},
    ["Nvim: Find"] = {{
        modifiers = {},
        keys = {
            ["Space f"]   = "find files (telescope)",
            ["Space g"]   = "live grep across files",
            ["Space b"]   = "list open buffers",
            ["Space fh"]  = "search help tags",
            ["/text"]     = "search in current file",
            ["n / N"]     = "next / previous match",
            ["Space h"]   = "clear search highlight",
        },
    }},
    ["Nvim: Buffers"] = {{
        modifiers = {},
        keys = {
            ["Space 1-9"] = "jump to buffer/tab N",
            ["]b / [b"]   = "next / previous buffer",
            ["C-^"]       = "toggle last two buffers",
            ["C-h/j/k/l"] = "move between splits",
        },
    }},
    ["Nvim: Move/Edit"] = {{
        modifiers = {},
        keys = {
            ["C-d / C-u"] = "half-page down / up (centered)",
            ["x"]         = "delete char without yanking",
            ["za"]        = "toggle fold",
            ["zR / zM"]   = "open all / close all folds",
            ["Space m"]   = "toggle minimap",
        },
    }},
    ["Nvim: Code"] = {{
        modifiers = {},
        keys = {
            ["C-J"]       = "accept Copilot suggestion (insert)",
            ["M-] / M-["] = "Copilot next / previous suggestion",
            [", ll"]      = "VimTeX compile",
            [", lv"]      = "VimTeX view PDF (zathura)",
            ["C-Space"]   = "trigger goat completion",
        },
    }},
    ["claude code"] = {{
        modifiers = {},
        keys = {
            ["claude"]    = "start Claude Code in current dir",
            ["/"]         = "slash commands (skills)",
            ["@"]         = "reference a file",
            ["! cmd"]     = "run a shell command in-session",
            ["Shift-Tab"] = "cycle permission mode (plan/auto)",
            ["Esc Esc"]   = "edit previous message",
            ["/clear"]    = "clear conversation context",
            ["/resume"]   = "resume a previous session",
        },
    }},
})

-- {{{ Error handling
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        if in_error then return end
        in_error = true
        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
beautiful.init(os.getenv("HOME") .. "/.config/awesome/themes/win11/theme.lua")

terminal = "alacritty"
filemanager = "dolphin"
screenshot = "flameshot gui"
browser = "brave"
password_manager = "keepassxc"
editor = "vim"
editor_cmd = terminal .. " -e " .. editor

modkey = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.tile,
}
-- }}}

menubar.utils.terminal = terminal

-- {{{ Wibar (Windows 11 taskbar)
local tasklist_buttons = gears.table.join(
    awful.button({ }, 1, function (c)
        if c == client.focus then
            c.minimized = true
        else
            c:emit_signal("request::activate", "tasklist", {raise = true})
        end
    end),
    awful.button({ }, 3, function()
        awful.menu.client_list({ theme = { width = 250 } })
    end),
    awful.button({ }, 4, function () awful.client.focus.byidx(1) end),
    awful.button({ }, 5, function () awful.client.focus.byidx(-1) end)
)

local rounded6 = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end
local rounded4 = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 4) end
local rofi_win11 = "rofi -show drun -show-icons -theme "
    .. os.getenv("HOME") .. "/.config/awesome/themes/win11/rofi-win11.rasi"
local icon_dir = os.getenv("HOME") .. "/.config/awesome/themes/win11/icons/"

-- Small helper: label widget with an optional leading PNG icon, Win11 text style
local function icon_label(icon_path, initial_text)
    local img = wibox.widget {
        image        = icon_path,
        resize       = true,
        forced_width = 18,
        forced_height = 18,
        widget       = wibox.widget.imagebox,
    }
    local txt = wibox.widget {
        markup = "<span foreground='#1f1f1f' size='small'>" .. (initial_text or "") .. "</span>",
        widget = wibox.widget.textbox,
    }
    local container = wibox.widget {
        {
            {
                img,
                valign = "center",
                widget = wibox.container.place,
            },
            {
                txt,
                left = 6,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.horizontal,
        },
        left = 10, right = 10, top = 6, bottom = 6,
        widget = wibox.container.margin,
    }
    return container, txt
end

awful.screen.connect_for_each_screen(function(s)

    -- Weather: sun icon + two-line "temperature / condition" (Win11 style)
    local weather_widget, weather_text = icon_label(icon_dir .. "sun.png", "")
    awful.widget.watch(
        [[sh -c "curl -s --max-time 5 'wttr.in/?format=%t|%C' 2>/dev/null | head -c 60"]],
        1800,
        function(_, stdout)
            local s_ = (stdout or ""):gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if s_ == "" then
                weather_text:set_markup("")
                return
            end
            local temp, cond = s_:match("^([^|]+)|(.+)$")
            if temp then
                temp = temp:gsub("^%+", "")
                weather_text:set_markup(
                    "<span foreground='#1f1f1f' size='small'>" .. temp ..
                    "\n<span size='x-small'>" .. cond .. "</span></span>"
                )
            else
                weather_text:set_markup("<span foreground='#1f1f1f' size='small'>" .. s_ .. "</span>")
            end
        end
    )

    -- Network: wifi icon only, vertically centered
    local net_widget = wibox.widget {
        {
            {
                image         = icon_dir .. "wifi.png",
                resize        = true,
                forced_width  = 18,
                forced_height = 18,
                widget        = wibox.widget.imagebox,
            },
            valign = "center",
            halign = "center",
            widget = wibox.container.place,
        },
        left = 10, right = 10,
        widget = wibox.container.margin,
    }

    -- Volume: speaker icon only, vertically centered
    local vol_widget = wibox.widget {
        {
            {
                image         = icon_dir .. "volume.png",
                resize        = true,
                forced_width  = 18,
                forced_height = 18,
                widget        = wibox.widget.imagebox,
            },
            valign = "center",
            halign = "center",
            widget = wibox.container.place,
        },
        left = 10, right = 10,
        widget = wibox.container.margin,
    }

    for i = 1, 5 do
        awful.tag.add(tostring(i), {
            layout = awful.layout.suit.tile,
            master_fill_policy = "expand",
            gap_single_client = true,
            gap = 4,
            screen = s,
            selected = (i == 1),
        })
    end

    s.mypromptbox = awful.widget.prompt()

    -- Start button
    local start_icon_path = os.getenv("HOME") .. "/.config/awesome/themes/win11/start.png"
    local start_button_inner
    if gears.filesystem.file_readable(start_icon_path) then
        start_button_inner = wibox.widget {
            {
                image  = start_icon_path,
                resize = true,
                widget = wibox.widget.imagebox,
            },
            top = 10, bottom = 10, left = 14, right = 14,
            widget = wibox.container.margin,
        }
    else
        start_button_inner = wibox.widget {
            markup = "<span size='x-large' foreground='#0078d4'>\u{229E}</span>",
            align  = "center",
            valign = "center",
            widget = wibox.widget.textbox,
        }
    end
    local start_button = wibox.widget {
        start_button_inner,
        bg     = beautiful.bg_normal,
        shape  = rounded6,
        widget = wibox.container.background,
    }
    start_button:buttons(gears.table.join(
        awful.button({}, 1, function() awful.spawn(rofi_win11) end)
    ))
    start_button:connect_signal("mouse::enter", function() start_button.bg = beautiful.bg_focus end)
    start_button:connect_signal("mouse::leave", function() start_button.bg = beautiful.bg_normal end)

    -- Search box (PNG magnifying glass icon + "Search" label)
    local search_box = wibox.widget {
        {
            {
                {
                    {
                        {
                            image        = icon_dir .. "search.png",
                            resize       = true,
                            forced_width = 16,
                            forced_height = 16,
                            widget       = wibox.widget.imagebox,
                        },
                        valign = "center",
                        widget = wibox.container.place,
                    },
                    {
                        {
                            markup = "<span foreground='#6b6b6b'>Search</span>",
                            widget = wibox.widget.textbox,
                        },
                        left = 10,
                        widget = wibox.container.margin,
                    },
                    layout = wibox.layout.fixed.horizontal,
                },
                left = 14, right = 160, top = 6, bottom = 6,
                widget = wibox.container.margin,
            },
            bg                 = "#ffffff",
            shape              = rounded6,
            shape_border_width = 1,
            shape_border_color = "#d1d1d1",
            widget             = wibox.container.background,
        },
        left = 4, right = 4, top = 8, bottom = 8,
        widget = wibox.container.margin,
    }
    search_box:buttons(gears.table.join(
        awful.button({}, 1, function() awful.spawn(rofi_win11) end)
    ))

    -- Icon-only tasklist with rounded hover/active + accent-blue underline pill
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        layout  = { spacing = 4, layout = wibox.layout.fixed.horizontal },
        widget_template = {
            {
                nil,
                {
                    {
                        {
                            id     = "icon_role",
                            widget = wibox.widget.imagebox,
                        },
                        margins = 10,
                        widget  = wibox.container.margin,
                    },
                    id           = "background_role",
                    widget       = wibox.container.background,
                    shape        = rounded6,
                    forced_width = 48,
                },
                {
                    {
                        id            = "underline",
                        bg            = "#0078d4",
                        forced_height = 3,
                        forced_width  = 16,
                        visible       = false,
                        shape         = rounded4,
                        widget        = wibox.container.background,
                    },
                    halign = "center",
                    widget = wibox.container.place,
                },
                layout = wibox.layout.align.vertical,
            },
            widget = wibox.container.background,
            create_callback = function(self, c)
                local ul = self:get_children_by_id("underline")[1]
                ul.visible = (client.focus == c)
                c:connect_signal("focus",   function() ul.visible = true  end)
                c:connect_signal("unfocus", function() ul.visible = false end)
            end,
        },
    }

    -- Two-line Win11-style clock (right-aligned)
    local win11_clock = wibox.widget.textclock(
        "<span foreground='#1f1f1f' size='small'>%H:%M\n%m/%d/%Y</span>", 30)
    win11_clock.align = "right"

    s.mywibox = awful.wibar({
        position = "bottom",
        height   = 48,
        screen   = s,
        bg       = beautiful.bg_normal,
        fg       = beautiful.fg_normal,
    })

    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        expand = "none",
        { -- Left: weather + prompt (slight left padding)
            layout = wibox.layout.fixed.horizontal,
            {
                weather_widget,
                left = 14,
                widget = wibox.container.margin,
            },
            s.mypromptbox,
        },
        { -- Middle: Start + Search + tasklist
            layout = wibox.layout.fixed.horizontal,
            spacing = 4,
            start_button,
            search_box,
            s.mytasklist,
        },
        { -- Right: wifi + volume + systray + clock
            layout = wibox.layout.fixed.horizontal,
            net_widget,
            vol_widget,
            {
                wibox.widget.systray(),
                top = 14, bottom = 14, right = 10, left = 6,
                widget = wibox.container.margin,
            },
            {
                win11_clock,
                left = 10, right = 14,
                widget = wibox.container.margin,
            },
        },
    }
end)
-- }}}

-- {{{ Key bindings (same as Arch mode — including the Super+Shift+T toggle)
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "F1",      function() hotkeys_widget:show_help() end,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "j",
        function () awful.client.focus.byidx( 1) end,
        {description = "focus next by index", group = "client"}),
    awful.key({ modkey,           }, "k",
        function () awful.client.focus.byidx(-1) end,
        {description = "focus previous by index", group = "client"}),

    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then client.focus:raise() end
        end,
        {description = "go back", group = "client"}),

    awful.key({ modkey,           }, "x", function () awful.spawn(terminal) end,
              {description = "open Alacritty", group = "launcher"}),
    awful.key({ modkey,           }, "b", function () awful.spawn(browser) end,
              {description = "open Brave", group = "launcher"}),
    awful.key({ modkey,           }, "v", function () awful.spawn(password_manager) end,
              {description = "open KeepassXC", group = "launcher"}),
    awful.key({ modkey,           }, "c", function () awful.spawn(filemanager) end,
              {description = "open Dolphin", group = "launcher"}),
    awful.key({ modkey,           }, "m", function () awful.spawn(screenshot) end,
              {description = "open Flameshot", group = "launcher"}),

    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Control" }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),
    awful.key({ modkey, "Shift" }, "t",
        function()
            local order = { "arch", "ubuntu", "windows7", "win11" }
            local path = os.getenv("HOME") .. "/.config/awesome/active_theme"
            local f = io.open(path, "r")
            local curr = (f and f:read("*l")) or "arch"
            if f then f:close() end
            local idx = 1
            for i, name in ipairs(order) do
                if name == curr then idx = i break end
            end
            local next_theme = order[(idx % #order) + 1]
            local w = io.open(path, "w")
            w:write(next_theme); w:close()
            awesome.restart()
        end,
        {description = "cycle theme (arch/ubuntu/windows7/win11)", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05) end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05) end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true) end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true) end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1) end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1) end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  if c then
                    c:emit_signal("request::activate", "key.unminimize", {raise = true})
                  end
              end,
              {description = "restore minimized", group = "client"}),

    awful.key({ modkey },            "r",     function () awful.spawn("rofi -show drun -show-icons -theme " .. os.getenv("HOME") .. "/.config/awesome/themes/win11/rofi-win11.rasi") end,
              {description = "open Rofi (Win11 style)", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c) c.fullscreen = not c.fullscreen; c:raise() end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey            }, "q",      function (c) c:kill() end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen() end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c) c.minimized = true end,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "i",
        function (c) c.maximized = not c.maximized; c:raise() end,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c) c.maximized_vertical = not c.maximized_vertical; c:raise() end,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c) c.maximized_horizontal = not c.maximized_horizontal; c:raise() end,
        {description = "(un)maximize horizontally", group = "client"})
)

for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then tag:view_only() end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then awful.tag.viewtoggle(tag) end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then client.focus:move_to_tag(tag) end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then client.focus:toggle_tag(tag) end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
    end)
)

root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen,
                     titlebars_enabled = true,
     }
    },
    { rule_any = { class = { "Brave-browser", "code-oss" } },
      properties = {
                     floating = false,
                     maximized = false,
                     fullscreen = false,
                     placement = awful.placement.no_overlap + awful.placement.no_offscreen,
      }
    },
}
-- }}}

-- Win11-style titlebars (min/max/close on the right)
client.connect_signal("request::titlebars", function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )
    awful.titlebar(c, { size = 30, bg_normal = "#f3f3f3", bg_focus = "#ffffff" }) : setup {
        { -- Left: icon + title
            {
                awful.titlebar.widget.iconwidget(c),
                left = 8, right = 8, top = 6, bottom = 6,
                widget = wibox.container.margin,
            },
            {
                align  = "left",
                widget = awful.titlebar.widget.titlewidget(c),
            },
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal,
        },
        { -- Middle: drag area
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal,
        },
        { -- Right: window controls
            awful.titlebar.widget.minimizebutton(c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.closebutton(c),
            layout = wibox.layout.fixed.horizontal(),
        },
        layout = wibox.layout.align.horizontal,
    }
end)

-- {{{ Signals
client.connect_signal("manage", function (c)
    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- Autostart
local win11_wallpaper = os.getenv("HOME") .. "/.config/awesome/themes/win11/wallpaper.jpg"
if gears.filesystem.file_readable(win11_wallpaper) then
    awful.spawn.with_shell("feh --bg-fill " .. win11_wallpaper)
else
    awful.spawn.with_shell("feh --randomize --bg-fill ~/Media/wallpapers/*")
end
awful.spawn.with_shell("pkill -x picom; picom --config " .. os.getenv("HOME") .. "/.config/awesome/picom-win11.conf")
awful.spawn.with_shell("pgrep -x flameshot >/dev/null || flameshot &")

-- Apply light GTK/system color scheme so Brave and other GTK apps follow Win11 mode
awful.spawn.with_shell(
    "mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0 && " ..
    "printf '[Settings]\\ngtk-theme-name=Adwaita\\ngtk-application-prefer-dark-theme=0\\n' " ..
    "| tee ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini >/dev/null; " ..
    "gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null; " ..
    "gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null; true"
)
