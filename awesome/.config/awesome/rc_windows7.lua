---------------------------------------------------------------
-- Windows 7 (Aero) desktop for AwesomeWM
-- Loaded by rc.lua's dispatcher when active_theme == "windows7".
--
-- A full desktop mimic, not a palette swap. What actually dates a
-- desktop to 2009 — and so what this builds:
--
--   * a round Start orb that OVERHANGS the taskbar (its own wibox:
--     wibar children cannot overflow the bar's height)
--   * WIDE, LABELLED task buttons — Win11 is icon-only and centred,
--     Win7 is left-aligned with text, and that difference alone
--     reads as the era
--   * a quick-launch strip, then a glass divider
--   * a notification area with a two-line clock (time over date)
--   * the "Show desktop" sliver hard against the right edge
--   * Aero glass everywhere: gradients + picom blur, light chrome
--     over a dark blue desktop
--
-- Keys are the ones from rc.lua, including the directional hjkl
-- scheme (shared via lib/nav.lua) — switching desktop look should
-- not retrain your hands.
---------------------------------------------------------------

pcall(require, "luarocks.loader")

local gears     = require("gears")
local awful     = require("awful")
require("awful.autofocus")
local wibox     = require("wibox")
local beautiful = require("beautiful")
local naughty   = require("naughty")
local menubar   = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
local nav       = require("lib.nav")
local startmenu = require("lib.w7_startmenu")
local focus_dir, move_dir = nav.focus_dir, nav.move_dir

-- Configure the DEFAULT hotkeys widget before anything populates it.
local hk_widget = require("awful.hotkeys_popup.widget")
hk_widget.default_widget = hk_widget.new({
    width            = 1860,
    height           = 900,
    group_margin     = 8,
    font             = "Noto Sans 9",
    description_font = "Noto Sans 8",
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
local W7 = os.getenv("HOME") .. "/.config/awesome/themes/windows7/"
beautiful.init(W7 .. "theme.lua")

terminal         = "alacritty"
filemanager      = "dolphin"
screenshot       = "flameshot gui"
browser          = "brave"
password_manager = "keepassxc"
editor           = "vim"
editor_cmd       = terminal .. " -e " .. editor

modkey = "Mod4"

awful.layout.layouts = { awful.layout.suit.tile }
menubar.utils.terminal = terminal
-- }}}

-- {{{ Aero building blocks
local dpi = beautiful.xresources and beautiful.xresources.apply_dpi
    or require("beautiful.xresources").apply_dpi

local BAR_H   = beautiful.taskbar_height or dpi(40)
local ORB_D   = dpi(52)          -- orb diameter
local ORB_LIFT = dpi(6)          -- how far it pokes above the bar
local ICONS   = beautiful.w7_icons or (W7 .. "icons/")

local function rounded(r)
    return function(cr, w, h) gears.shape.rounded_rect(cr, w, h, r) end
end
local shape3 = rounded(dpi(3))

local rofi_w7 = "rofi -show drun -show-icons -theme " .. W7 .. "rofi-windows7.rasi"

-- A glass button: gradient background, 1px light border, brighter on hover.
-- Every clickable thing on the taskbar is one of these, which is what keeps
-- the bar reading as a single sheet of glass rather than a widget collection.
local function aero_button(inner, opts)
    opts = opts or {}
    local bg = wibox.widget {
        {
            inner,
            left = opts.pad or dpi(6), right = opts.pad or dpi(6),
            top = opts.vpad or dpi(4), bottom = opts.vpad or dpi(4),
            widget = wibox.container.margin,
        },
        bg                 = opts.bg or beautiful.taskbtn_normal,
        shape              = shape3,
        shape_border_width = 1,
        shape_border_color = "#ffffff2e",
        widget             = wibox.container.background,
    }
    local normal = opts.bg or beautiful.taskbtn_normal
    bg:connect_signal("mouse::enter", function() bg.bg = beautiful.taskbtn_hover end)
    bg:connect_signal("mouse::leave", function() bg.bg = normal end)
    if opts.on_click then
        bg:buttons(gears.table.join(awful.button({}, 1, opts.on_click)))
    end
    return bg
end

local function tray_icon(file, tooltip, on_click, on_scroll_up, on_scroll_down)
    local img = wibox.widget {
        image = ICONS .. file, resize = true,
        forced_width = dpi(16), forced_height = dpi(16),
        widget = wibox.widget.imagebox,
    }
    local w = wibox.widget {
        { img, valign = "center", halign = "center", widget = wibox.container.place },
        left = dpi(6), right = dpi(6),
        widget = wibox.container.margin,
    }
    local btns = {}
    if on_click then btns[#btns + 1] = awful.button({}, 1, on_click) end
    if on_scroll_up then
        btns[#btns + 1] = awful.button({}, 4, on_scroll_up)
        btns[#btns + 1] = awful.button({}, 5, on_scroll_down)
    end
    if #btns > 0 then w:buttons(gears.table.join(table.unpack(btns))) end
    if tooltip then
        awful.tooltip { objects = { w }, text = tooltip, delay_show = 0.6 }
    end
    return w, img
end

-- Vertical glass divider, as used between quick launch and the task buttons.
-- A childless container.background paints NOTHING (its bg is drawn from
-- before_draw_children, which never runs without children), so this is a
-- separator — the same trap that hid every hairline in rc.lua for months.
local function glass_divider()
    return wibox.widget {
        {
            orientation   = "vertical",
            thickness     = 1,
            color         = "#ffffff33",
            forced_width  = 1,
            forced_height = BAR_H - dpi(14),
            widget        = wibox.widget.separator,
        },
        left = dpi(5), right = dpi(5), top = dpi(7), bottom = dpi(7),
        widget = wibox.container.margin,
    }
end
-- }}}

-- {{{ Taskbar
local tasklist_buttons = gears.table.join(
    awful.button({ }, 1, function (c)
        -- Win7 semantics: clicking the active window's button minimizes it.
        if c == client.focus then
            c.minimized = true
        else
            c:emit_signal("request::activate", "tasklist", { raise = true })
        end
    end),
    awful.button({ }, 3, function() awful.menu.client_list({ theme = { width = 260 } }) end),
    awful.button({ }, 4, function() awful.client.focus.byidx(1) end),
    awful.button({ }, 5, function() awful.client.focus.byidx(-1) end)
)

awful.screen.connect_for_each_screen(function(s)
    for i = 1, 5 do
        awful.tag.add(tostring(i), {
            layout             = awful.layout.suit.tile,
            master_fill_policy = "expand",
            gap_single_client  = false,
            screen             = s,
            selected           = (i == 1),
        })
    end

    s.mypromptbox = awful.widget.prompt()

    ---------------------------------------------------------------
    -- Quick launch
    ---------------------------------------------------------------
    local function ql(icon, cmd, tip)
        local img = wibox.widget {
            image = ICONS .. icon, resize = true,
            -- Win7 SP1's default is LARGE taskbar icons: pinned items nearly
            -- fill the bar's height. At 22px they read as a toolbar, not a
            -- taskbar.
            forced_width = dpi(28), forced_height = dpi(28),
            widget = wibox.widget.imagebox,
        }
        local b = aero_button(img, {
            pad = dpi(4), vpad = dpi(3),
            bg = "#ffffff00",     -- invisible until hovered, like Win7's
            on_click = function() awful.spawn(cmd) end,
        })
        awful.tooltip { objects = { b }, text = tip, delay_show = 0.6 }
        return b
    end

    local quick_launch = wibox.widget {
        ql("ql-browser.png",  browser,     "Internet (Brave)"),
        ql("ql-explorer.png", filemanager, "Windows Explorer (Dolphin)"),
        ql("sm-media.png",    "mpv --player-operation-mode=pseudo-gui", "Media Player (mpv)"),
        spacing = dpi(2),
        layout  = wibox.layout.fixed.horizontal,
    }

    ---------------------------------------------------------------
    -- Taglist — Win7 has no workspaces, so these are small numbered
    -- pips rather than the Arch mode's labelled pills. Kept because
    -- the tag keys still exist and dead keys are worse than pips.
    ---------------------------------------------------------------
    -- Windows 7 has no workspaces, so a row of tag pills is the loudest
    -- non-Windows thing that could sit on this bar. The tag number instead
    -- lives in the notification area as a small indicator, exactly where Win7
    -- put the keyboard-language badge — believable, and the information is
    -- still there. Click cycles, scroll steps.
    local tag_ind = wibox.widget {
        widget = wibox.widget.textbox, align = "center", valign = "center",
        wrap = "none", ellipsize = "none",
    }
    local function refresh_tag_ind()
        local t = s.selected_tag
        tag_ind:set_markup("<span font='Noto Sans 8' foreground='" ..
            beautiful.w7_text_lite_dim .. "'>" .. (t and t.name or "-") .. "</span>")
    end
    refresh_tag_ind()
    s:connect_signal("tag::history::update", refresh_tag_ind)
    local tag_indicator = wibox.widget {
        { tag_ind, forced_width = dpi(14), widget = wibox.container.place },
        left = dpi(4), right = dpi(4),
        widget = wibox.container.margin,
    }
    tag_indicator:buttons(gears.table.join(
        awful.button({}, 1, function() awful.tag.viewnext(s) end),
        awful.button({}, 3, function() awful.tag.viewprev(s) end),
        awful.button({}, 4, function() awful.tag.viewprev(s) end),
        awful.button({}, 5, function() awful.tag.viewnext(s) end)
    ))
    awful.tooltip { objects = { tag_indicator },
                    text = "Desktop (click to switch)", delay_show = 0.6 }

    ---------------------------------------------------------------
    -- Task buttons — the signature Win7 element: wide, labelled,
    -- left-aligned, glass. Width is CONSTRAINED rather than fixed so
    -- eight windows still fit on a 1080p bar.
    ---------------------------------------------------------------
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        layout  = { spacing = dpi(3), layout = wibox.layout.fixed.horizontal },
        widget_template = {
            {
                {
                    {
                        {
                            { id = "icon_role", widget = wibox.widget.imagebox },
                            forced_width  = dpi(16),
                            forced_height = dpi(16),
                            widget        = wibox.container.place,
                        },
                        {
                            { id = "text_role", widget = wibox.widget.textbox },
                            left   = dpi(6),
                            widget = wibox.container.margin,
                        },
                        layout = wibox.layout.fixed.horizontal,
                    },
                    left = dpi(8), right = dpi(8), top = dpi(4), bottom = dpi(4),
                    widget = wibox.container.margin,
                },
                id     = "background_role",
                widget = wibox.container.background,
            },
            -- The constraint lives OUTSIDE background_role: inside, the glass
            -- would be clipped to the text and the buttons would be ragged.
            width    = dpi(190),
            strategy = "max",
            widget   = wibox.container.constraint,
            create_callback = function(self, c)
                self:get_children_by_id("text_role")[1].font = beautiful.font_taskbar
                local _ = c
            end,
        },
    }

    ---------------------------------------------------------------
    -- Notification area
    ---------------------------------------------------------------
    local net_ic = tray_icon("network.png", "Network", function()
        awful.spawn("nm-connection-editor")
    end)

    local vol_ic, vol_img = tray_icon("volume.png", "Volume",
        function() awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end,
        function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%") end,
        function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%") end)
    -- Muted state: dim the icon rather than swap in a second asset — one glyph
    -- to keep in step instead of two.
    local function refresh_vol()
        awful.spawn.easy_async_with_shell(
            "pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null",
            function(out) vol_img.opacity = out:match("yes") and 0.35 or 1.0
                          vol_img:emit_signal("widget::redraw_needed") end)
    end
    refresh_vol()
    gears.timer { timeout = 5, autostart = true, callback = refresh_vol }

    local flag_ic = tray_icon("flag.png", "Action Center — pending updates",
        function() awful.spawn(terminal .. " -e sh -c 'checkupdates; read -n1'") end)

    local systray = wibox.widget {
        wibox.widget.systray(),
        top = dpi(11), bottom = dpi(11), left = dpi(4), right = dpi(4),
        widget = wibox.container.margin,
    }

    -- Two-line clock: time over date, right-aligned. The date line is the
    -- give-away — Win11 stacks them too, but Win7 uses a longer date format.
    local clock = wibox.widget.textclock(
        "<span font='" .. (beautiful.font_clock or "Noto Sans 9") ..
        "' foreground='" .. beautiful.w7_text_lite .. "'>%H:%M</span>\n" ..
        "<span font='" .. (beautiful.font_clock_sub or "Noto Sans 8") ..
        "' foreground='" .. beautiful.w7_text_lite_dim .. "'>%d-%m-%Y</span>", 30)
    clock.align  = "center"
    clock.valign = "center"
    local clock_btn = aero_button(clock, {
        pad = dpi(10), vpad = dpi(2), bg = "#ffffff00",
        on_click = function() awful.spawn("gsimplecal") end,
    })

    -- Show desktop: the thin sliver hard against the right edge. Toggles, so a
    -- second click brings everything back — that is what the real one does.
    local show_desktop_state = false
    local show_desktop = wibox.widget {
        {
            orientation   = "vertical",
            thickness     = 1,
            color         = "#ffffff3d",
            forced_width  = 1,
            forced_height = BAR_H,
            widget        = wibox.widget.separator,
        },
        left   = dpi(5), right = dpi(4),
        widget = wibox.container.margin,
    }
    local show_desktop_btn = wibox.widget {
        show_desktop,
        bg     = "#ffffff0f",
        widget = wibox.container.background,
    }
    show_desktop_btn:connect_signal("mouse::enter",
        function() show_desktop_btn.bg = "#ffffff33" end)
    show_desktop_btn:connect_signal("mouse::leave",
        function() show_desktop_btn.bg = "#ffffff0f" end)
    show_desktop_btn:buttons(gears.table.join(awful.button({}, 1, function()
        local t = s.selected_tag
        if not t then return end
        show_desktop_state = not show_desktop_state
        for _, c in ipairs(t:clients()) do c.minimized = show_desktop_state end
    end)))
    awful.tooltip { objects = { show_desktop_btn }, text = "Show desktop",
                    delay_show = 0.6 }

    ---------------------------------------------------------------
    -- The bar itself
    ---------------------------------------------------------------
    s.mywibox = awful.wibar({
        position = "bottom",
        height   = BAR_H,
        screen   = s,
        bg       = beautiful.taskbar_bg,
        fg       = beautiful.w7_text_lite,
    })

    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        {   -- Left: room for the orb, then quick launch, tags, task buttons
            layout = wibox.layout.fixed.horizontal,
            -- The orb is a separate window on top of this gap (see below).
            { forced_width = ORB_D + dpi(4), widget = wibox.container.place },
            quick_launch,
            glass_divider(),
            s.mytasklist,
        },
        {   -- Middle: prompt only. Task buttons deliberately stay LEFT — a
            -- centred tasklist is the Win11 tell.
            layout = wibox.layout.fixed.horizontal,
            s.mypromptbox,
        },
        {   -- Right: notification area
            layout = wibox.layout.fixed.horizontal,
            glass_divider(),
            tag_indicator,
            flag_ic,
            net_ic,
            vol_ic,
            systray,
            clock_btn,
            show_desktop_btn,
        },
    }

    ---------------------------------------------------------------
    -- Start orb — its own wibox so it can overhang the taskbar.
    ---------------------------------------------------------------
    local orb_img = wibox.widget {
        image  = beautiful.w7_start_orb,
        resize = true,
        widget = wibox.widget.imagebox,
    }
    s.orb = wibox({
        screen  = s,
        width   = ORB_D,
        height  = ORB_D,
        visible = true,
        ontop   = true,
        bg      = "#00000000",
        type    = "utility",
    })
    s.orb:set_widget(orb_img)
    ---------------------------------------------------------------
    -- Start menu. Entries are REAL programs on this machine under the
    -- names Windows used, which is what the left column always was:
    -- recently-used programs, not a fixed set.
    ---------------------------------------------------------------
    s.start_menu = startmenu.new(s, {
        user   = (os.getenv("USER") or "user"):gsub("^%l", string.upper),
        avatar = ICONS .. "avatar.png",
        power_icon = ICONS .. "sm-power.png",
        left = {
            { icon = ICONS .. "ql-browser.png",  label = "Internet",           cmd = browser },
            { icon = ICONS .. "ql-explorer.png", label = "Windows Explorer",   cmd = filemanager },
            { icon = ICONS .. "ql-terminal.png", label = "Command Prompt",     cmd = terminal },
            { icon = ICONS .. "sm-code.png",     label = "Visual Studio Code", cmd = "code" },
            { icon = ICONS .. "sm-snip.png",     label = "Snipping Tool",      cmd = screenshot },
            { icon = ICONS .. "sm-media.png",    label = "Media Player",       cmd = "mpv --player-operation-mode=pseudo-gui" },
            { icon = ICONS .. "sm-key.png",      label = "Passwords",          cmd = password_manager },
        },
        home = filemanager .. " " .. os.getenv("HOME"),
        right = {
            { label = "Documents", cmd = filemanager .. " " .. os.getenv("HOME") .. "/Documents" },
            { label = "Pictures",  cmd = filemanager .. " " .. os.getenv("HOME") .. "/Pictures" },
            { label = "Music",     cmd = filemanager .. " " .. os.getenv("HOME") .. "/Music",
              rule = true },
            { label = "Computer",  cmd = filemanager .. " /" },
            { label = "Control Panel", cmd = terminal .. " -e htop" },
            { label = "Devices and Printers",
              cmd = terminal .. " -e sh -c 'lsblk -o NAME,SIZE,MODEL,MOUNTPOINTS; echo; lsusb; echo; read -n1'",
              rule = true },
            { label = "Help and Support", cmd = "xdg-open https://wiki.archlinux.org" },
        },
        all_programs = rofi_w7,
        search       = rofi_w7,
        power = "rofi -show power -modes 'power:" .. os.getenv("HOME") ..
                "/.config/awesome/scripts/rofi-power-mode.sh' -theme " .. W7 ..
                "rofi-windows7.rasi -theme-str 'window { width: 420px; } " ..
                "listview { columns: 1; lines: 5; } element-icon { size: 0px; }'",
    })

    s.orb:buttons(gears.table.join(awful.button({}, 1, function()
        s.start_menu.toggle()
    end)))
    s.orb:connect_signal("mouse::enter",
        function() orb_img.image = beautiful.w7_start_orb_hover end)
    s.orb:connect_signal("mouse::leave",
        function() orb_img.image = beautiful.w7_start_orb end)

    local function place_orb()
        local g = s.geometry
        s.orb.x = g.x + dpi(2)
        s.orb.y = g.y + g.height - BAR_H - ORB_LIFT
    end
    place_orb()
    s:connect_signal("property::geometry", place_orb)

    ---------------------------------------------------------------
    -- Desktop icons — a column at the top-left, as on any Windows
    -- install. type="desktop" puts them BEHIND every client, which
    -- is exactly where desktop icons belong.
    ---------------------------------------------------------------
    if s == screen.primary then
        local ICON_W, ICON_H, ICON_GAP = dpi(84), dpi(78), dpi(6)

        -- Win7 draws desktop labels with a dark shadow so they survive a light
        -- wallpaper. Pango has no shadow, so this is the same text twice: dark
        -- copy offset by a pixel, bright copy on top.
        local function shadowed_label(text)
            local function tb(colour, font)
                return wibox.widget {
                    markup = "<span font='" .. font .. "' foreground='" .. colour ..
                             "'>" .. text .. "</span>",
                    align  = "center", valign = "top",
                    wrap   = "word",
                    widget = wibox.widget.textbox,
                }
            end
            local f = "Noto Sans 8"
            return wibox.widget {
                { tb("#000000a8", f), left = 1, top = 1, widget = wibox.container.margin },
                tb("#ffffff", f),
                layout = wibox.layout.stack,
            }
        end

        local function desktop_icon(idx, image, label, cmd)
            local box = wibox({
                screen  = s,
                width   = ICON_W,
                height  = ICON_H,
                visible = true,
                ontop   = false,
                type    = "desktop",
                bg      = "#00000000",
            })
            local body = wibox.widget {
                {
                    {
                        {
                            image = image, resize = true,
                            forced_width = dpi(48), forced_height = dpi(48),
                            widget = wibox.widget.imagebox,
                        },
                        halign = "center",
                        widget = wibox.container.place,
                    },
                    { shadowed_label(label), top = dpi(2), widget = wibox.container.margin },
                    layout = wibox.layout.fixed.vertical,
                },
                margins = dpi(4),
                widget  = wibox.container.margin,
            }
            local frame = wibox.widget {
                body,
                bg                 = "#00000000",
                shape              = shape3,
                shape_border_width = 1,
                shape_border_color = "#00000000",
                widget             = wibox.container.background,
            }
            box:set_widget(frame)
            -- Hover/selection is Aero's pale blue wash with a defined edge.
            box:connect_signal("mouse::enter", function()
                frame.bg = "#ffffff2e"
                frame.shape_border_color = "#ffffff6b"
            end)
            box:connect_signal("mouse::leave", function()
                frame.bg = "#00000000"
                frame.shape_border_color = "#00000000"
            end)
            box:buttons(gears.table.join(awful.button({}, 1, function()
                awful.spawn(cmd)
            end)))
            box.w7_index = idx
            return box
        end

        -- A stock Windows 7 desktop has exactly ONE icon. Everything else
        -- lives in the Start menu and quick launch, so that is where the rest
        -- of these went.
        s.desktop_icons = {
            desktop_icon(1, ICONS .. "desk-recycle.png", "Recycle Bin",
                         filemanager .. " trash:/"),
        }

        local function place_desktop_icons()
            local wa = s.workarea
            for i, box in ipairs(s.desktop_icons) do
                box.x = wa.x + dpi(10)
                box.y = wa.y + dpi(10) + (i - 1) * (ICON_H + ICON_GAP)
            end
        end
        place_desktop_icons()
        s:connect_signal("property::geometry", place_desktop_icons)
    end

    -- ontop would otherwise float the orb over fullscreen video. The bar itself
    -- is covered automatically (its strut is ignored by fullscreen clients).
    local function orb_visibility()
        local hide = false
        for _, c in ipairs(s.selected_tag and s.selected_tag:clients() or {}) do
            if c.fullscreen and not c.minimized then hide = true break end
        end
        s.orb.visible = not hide
    end
    for _, sig in ipairs({ "property::fullscreen", "property::minimized",
                           "manage", "unmanage" }) do
        client.connect_signal(sig, orb_visibility)
    end
    s:connect_signal("tag::history::update", orb_visibility)
end)
-- }}}

-- {{{ Key bindings — the same scheme as rc.lua
globalkeys = gears.table.join(
    awful.key({ modkey }, "F1", hotkeys_popup.show_help,
              {description = "show help", group = "awesome"}),

    awful.key({ modkey }, "Escape",
        function()
            awful.spawn.easy_async_with_shell([[
if command -v light-locker-command >/dev/null 2>&1; then
    pgrep -x light-locker >/dev/null || { light-locker --lock-after-screensaver=5 --lock-on-suspend >/dev/null 2>&1 & sleep 0.5; }
    light-locker-command -l 2>&1 && exit 0
fi
command -v dm-tool >/dev/null 2>&1 && dm-tool lock 2>&1
]], function(_, stderr)
                if stderr and stderr ~= "" then
                    naughty.notify({ preset = naughty.config.presets.critical,
                                     title = "Lock failed", text = stderr })
                end
            end)
        end,
        {description = "lock screen", group = "awesome"}),

    -- Hardware / media keys
    awful.key({}, "XF86AudioRaiseVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%") end),
    awful.key({}, "XF86AudioLowerVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%") end),
    awful.key({}, "XF86AudioMute", function() awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86MonBrightnessUp", function() awful.spawn("brightnessctl set 5%+") end),
    awful.key({}, "XF86MonBrightnessDown", function() awful.spawn("brightnessctl set 5%-") end),
    awful.key({}, "XF86AudioPlay", function() awful.spawn("playerctl play-pause") end),
    awful.key({}, "XF86AudioNext", function() awful.spawn("playerctl next") end),
    awful.key({}, "XF86AudioPrev", function() awful.spawn("playerctl previous") end),

    -- Fake Windows screens (pranks); they are dismissed by clicking them.
    awful.key({ modkey, "Shift" }, "u", function() local p = require("win_pranks")
                  if p.is_open() then p.close() else p.update() end end,
              {description = "fake Windows Update overlay", group = "fun"}),
    awful.key({ modkey, "Shift" }, "b", function() local p = require("win_pranks")
                  if p.is_open() then p.close() else p.bsod() end end,
              {description = "fake blue screen of death", group = "fun"}),
    awful.key({ modkey, "Shift" }, "w", function() local p = require("win_pranks")
                  if p.is_open() then p.close() else p.wannacry() end end,
              {description = "fake WannaCry ransom screen", group = "fun"}),

    awful.key({ modkey }, "Left",  awful.tag.viewprev,
              {description = "view previous tag", group = "tag"}),
    awful.key({ modkey }, "Right", awful.tag.viewnext,
              {description = "view next tag", group = "tag"}),

    -- FOCUS: hjkl by direction.
    awful.key({ modkey }, "h", function () focus_dir("left")  end,
              {description = "focus left / down / up / right (hjkl)", group = "client"}),
    awful.key({ modkey }, "j", function () focus_dir("down")  end),
    awful.key({ modkey }, "k", function () focus_dir("up")    end),
    awful.key({ modkey }, "l", function () focus_dir("right") end),

    -- MOVE: same directions, held with Alt.
    awful.key({ modkey, "Mod1" }, "h", function () move_dir("left")  end,
              {description = "move window left / down / up / right (hjkl)", group = "client"}),
    awful.key({ modkey, "Mod1" }, "j", function () move_dir("down")  end),
    awful.key({ modkey, "Mod1" }, "k", function () move_dir("up")    end),
    awful.key({ modkey, "Mod1" }, "l", function () move_dir("right") end),

    awful.key({ modkey, "Shift" }, "n", function () awful.screen.focus_relative(1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),

    awful.key({ modkey }, "x", function () awful.spawn(terminal) end,
              {description = "open Alacritty", group = "launcher"}),
    awful.key({ modkey }, "b", function () awful.spawn(browser) end,
              {description = "open Brave", group = "launcher"}),
    awful.key({ modkey }, "v", function () awful.spawn(password_manager) end,
              {description = "open KeePassXC", group = "launcher"}),
    awful.key({ modkey }, "c", function () awful.spawn(filemanager) end,
              {description = "open Dolphin", group = "launcher"}),
    awful.key({ modkey }, "m", function () awful.spawn(screenshot) end,
              {description = "open Flameshot", group = "launcher"}),

    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Control" }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey, "Shift" }, "t",
        function()
            -- Keep this list identical to rc.lua's: two copies that disagree
            -- make the cycle skip a theme in one direction only.
            local order = { "dr460nized", "arch", "windows7", "win11" }
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
            local home  = os.getenv("HOME")
            local aterm = (next_theme == "dr460nized") and "dr460nized" or "mocha"
            os.execute(("cp %s/.config/alacritty/themes/%s.toml %s/.config/alacritty/theme.toml 2>/dev/null")
                :format(home, aterm, home))
            awesome.restart()
        end,
        {description = "cycle theme (dr460nized/arch/windows7/win11)", group = "awesome"}),

    -- RESIZE: hjkl with Control.
    awful.key({ modkey, "Control" }, "h", function () awful.tag.incmwfact(-0.05) end,
              {description = "resize: master split (h/l), row height (j/k)", group = "layout"}),
    awful.key({ modkey, "Control" }, "l", function () awful.tag.incmwfact( 0.05) end),
    awful.key({ modkey, "Control" }, "j", function ()
                  if client.focus then awful.client.incwfact(-0.10, client.focus) end
              end),
    awful.key({ modkey, "Control" }, "k", function ()
                  if client.focus then awful.client.incwfact( 0.10, client.focus) end
              end),

    awful.key({ modkey, "Shift" }, "period", function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "more master windows", group = "layout"}),
    awful.key({ modkey, "Shift" }, "comma", function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "fewer master windows", group = "layout"}),
    awful.key({ modkey, "Control" }, "period", function () awful.tag.incncol( 1, nil, true) end,
              {description = "more columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "comma", function () awful.tag.incncol(-1, nil, true) end,
              {description = "fewer columns", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
        function ()
            local c = awful.client.restore()
            if c then c:emit_signal("request::activate", "key.unminimize", { raise = true }) end
        end,
        {description = "restore minimized", group = "client"}),

    awful.key({ modkey }, "r",
        function ()
            local sc = awful.screen.focused()
            if sc.start_menu then sc.start_menu.toggle() else awful.spawn(rofi_w7) end
        end,
              {description = "Start menu", group = "launcher"}),
    awful.key({ modkey, "Shift" }, "v",
        function () awful.spawn(os.getenv("HOME") .. "/.config/awesome/scripts/clipboard-menu.sh") end,
              {description = "clipboard history", group = "launcher"}),
    awful.key({ modkey }, "p",
        function ()
            awful.spawn.with_shell(
                "rofi -show power -modes 'power:" .. os.getenv("HOME") ..
                "/.config/awesome/scripts/rofi-power-mode.sh' -theme " .. W7 ..
                "rofi-windows7.rasi -theme-str 'window { width: 420px; } " ..
                "listview { columns: 1; lines: 5; } element-icon { size: 0px; }'")
        end,
              {description = "power actions (lock/logout/suspend/reboot/off)", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey }, "f", function (c) c.fullscreen = not c.fullscreen; c:raise() end,
              {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey }, "q", function (c) c:kill() end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space", awful.client.floating.toggle,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey }, "o", function (c) c:move_to_screen() end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey }, "t", function (c) c.ontop = not c.ontop end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey }, "s", function (c) c.sticky = not c.sticky end,
              {description = "toggle sticky (all tags, for OBS capture)", group = "client"}),
    awful.key({ modkey }, "n", function (c) c.minimized = true end,
              {description = "minimize", group = "client"}),
    awful.key({ modkey }, "i", function (c) c.maximized = not c.maximized; c:raise() end,
              {description = "(un)maximize", group = "client"})
)

for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                      local t = awful.screen.focused().tags[i]
                      if t then t:view_only() end
                  end,
                  {description = "view tag #" .. i, group = "tag"}),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local t = awful.screen.focused().tags[i]
                      if t then awful.tag.viewtoggle(t) end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local t = client.focus.screen.tags[i]
                          if t then client.focus:move_to_tag(t) end
                      end
                  end,
                  {description = "move focused client to tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.resize(c)
    end)
)

root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    { rule = { },
      properties = { border_width  = beautiful.border_width,
                     border_color  = beautiful.border_normal,
                     focus         = awful.client.focus.filter,
                     raise         = true,
                     keys          = clientkeys,
                     buttons       = clientbuttons,
                     screen        = awful.screen.preferred,
                     placement     = awful.placement.no_overlap + awful.placement.no_offscreen,
                     titlebars_enabled = true,
      }
    },
    -- Dialogs float, as they do on Windows.
    { rule_any = { type = { "dialog" }, role = { "pop-up" } },
      properties = { floating = true, placement = awful.placement.centered },
    },
}
-- }}}

-- {{{ Aero titlebars
-- Layout is Windows', not awesome's: icon left, title CENTRED, the three glass
-- controls hard right. The centred title is the strongest single cue after the
-- orb — every other desktop left-aligns it.
client.connect_signal("request::titlebars", function(c)
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.resize(c)
        end),
        -- Double-click to maximize, like every Windows titlebar.
        awful.button({ }, 1, nil, function()
            if c.w7_last_click and (os.clock() - c.w7_last_click) < 0.35 then
                c.maximized = not c.maximized
                c.w7_last_click = nil
            else
                c.w7_last_click = os.clock()
            end
        end)
    )

    local title = awful.titlebar.widget.titlewidget(c)
    title.align  = "center"
    title.font   = beautiful.font_title

    awful.titlebar(c, { size = beautiful.titlebar_height }):setup {
        {   -- Left: icon
            {
                awful.titlebar.widget.iconwidget(c),
                left = dpi(6), right = dpi(4), top = dpi(5), bottom = dpi(5),
                widget = wibox.container.margin,
            },
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal,
        },
        {   -- Middle: centred title, and the drag area
            title,
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal,
        },
        {   -- Right: the glass controls
            {
                {
                    awful.titlebar.widget.minimizebutton(c),
                    awful.titlebar.widget.maximizedbutton(c),
                    awful.titlebar.widget.closebutton(c),
                    spacing = dpi(1),
                    layout  = wibox.layout.fixed.horizontal,
                },
                top = dpi(3), bottom = dpi(4), right = dpi(4), left = dpi(6),
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.horizontal,
        },
        layout = wibox.layout.align.horizontal,
    }
end)
-- }}}

-- {{{ Signals
client.connect_signal("manage", function (c)
    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

client.connect_signal("focus",   function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- {{{ Autostart
awful.spawn.with_shell("xset r rate 300 50")

-- Wallpaper via feh, not beautiful.wallpaper: the latter is applied before the
-- compositor is up and flashes the default grey on every restart.
awful.spawn.with_shell("feh --bg-fill " .. W7 .. "wallpaper.jpg")
awful.spawn.with_shell("pkill -x picom; picom --config " ..
    os.getenv("HOME") .. "/.config/awesome/picom-windows7.conf")
awful.spawn.with_shell("pgrep -x flameshot >/dev/null || flameshot &")
awful.spawn.with_shell("pgrep -x greenclip >/dev/null || greenclip daemon &")
-- This mode has no visualizer, so any cava is a leftover from the arch-family
-- config. SIGKILL because cava does not act on SIGTERM — leaving it running
-- means it keeps feeding frames to a widget that no longer exists.
awful.spawn.with_shell("pkill -9 -x cava >/dev/null 2>&1 || true")

-- Idle lock, matching rc.lua: blanking OFF so the greeter is visible rather
-- than a black screen painted by X itself.
awful.spawn.with_shell(
    "command -v light-locker >/dev/null && { xset s 300 0; xset s noblank; " ..
    "pgrep -x light-locker >/dev/null || light-locker --lock-after-screensaver=1 --lock-on-suspend & }")

-- Aero's window content is LIGHT (Explorer is white), so GTK and Qt apps get a
-- light scheme here — the opposite of the dr460nized/arch modes.
awful.spawn.with_shell(
    "mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0 && " ..
    "printf '[Settings]\\ngtk-theme-name=Adwaita\\ngtk-icon-theme-name=Adwaita\\n" ..
    "gtk-application-prefer-dark-theme=0\\n' " ..
    "| tee ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini >/dev/null; " ..
    "gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null; " ..
    "gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null; " ..
    "command -v kwriteconfig6 >/dev/null && " ..
    "kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeLight; true")
-- }}}
