-- Theme dispatcher: arch-family themes (dr460nized/arch/ubuntu/windows7) share
-- this config and only swap palette; win11 has its own bespoke layout.
local ARCH_FAMILY = { dr460nized = true, arch = true, ubuntu = true, windows7 = true }
do
    local path = os.getenv("HOME") .. "/.config/awesome/active_theme"
    local f = io.open(path, "r")
    local t = f and f:read("*l") or "arch"
    if f then f:close() end
    if t == "win11" then
        return dofile(os.getenv("HOME") .. "/.config/awesome/rc_win11.lua")
    end
    -- Unknown themes fall back to arch.
    ACTIVE_THEME = ARCH_FAMILY[t] and t or "arch"
end

-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")

-- Configure the DEFAULT hotkeys widget (the one show_help and add_hotkeys both
-- use) BEFORE anything populates it, with a near-fullscreen size + small font
-- so every group fits on a single page. width/height clamp to the work area.
local hk_widget = require("awful.hotkeys_popup.widget")
hk_widget.default_widget = hk_widget.new({
    width            = 1860,
    height           = 900,
    group_margin     = 8,
    font             = "FiraCode Nerd Font 9",
    description_font = "FiraCode Nerd Font 8",
})

-- NOTE: we deliberately do NOT require("awful.hotkeys_popup.keys"). It loads
-- huge built-in cheatsheets (VIM ~99 entries, Qutebrowser, termite, tmux…) that
-- flood the F1 popup and push the real groups off-page. Our own "Nvim" sections
-- below replace the built-in VIM one.

-- The F1 popup lists real AwesomeWM bindings only: no Neovim or Claude Code
-- cheatsheets (both are discoverable in the tools themselves), and no
-- media/brightness keys (they are printed on the keyboard).

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
beautiful.init(os.getenv("HOME") .. "/.config/awesome/themes/" .. ACTIVE_THEME .. "/theme.lua")

-- Catppuccin palette shortcuts
local C = {
    base      = beautiful.cat_base     or "#1e1e2e",
    mantle    = beautiful.cat_mantle   or "#181825",
    crust     = beautiful.cat_crust    or "#11111b",
    surface0  = beautiful.cat_surface0 or "#313244",
    surface1  = beautiful.cat_surface1 or "#45475a",
    text      = beautiful.cat_text     or "#cdd6f4",
    subtext1  = beautiful.cat_subtext1 or "#bac2de",
    overlay0  = beautiful.cat_overlay0 or "#6c7086",
    mauve     = beautiful.cat_mauve    or "#cba6f7",
    blue      = beautiful.cat_blue     or "#89b4fa",
    sky       = beautiful.cat_sky      or "#89dceb",
    teal      = beautiful.cat_teal     or "#94e2d5",
    green     = beautiful.cat_green    or "#a6e3a1",
    yellow    = beautiful.cat_yellow   or "#f9e2af",
    peach     = beautiful.cat_peach    or "#fab387",
    red       = beautiful.cat_red      or "#f38ba8",
    pink      = beautiful.cat_pink     or "#f5c2e7",
}

-- {{{ UI design tokens — the single source for geometry, radii and fonts.
-- Two radius tiers only (matching picom's corner-radius): outer for large
-- surfaces, inner for pills/chips. All wibar pills share one geometry.
local dpi  = require("beautiful.xresources").apply_dpi
local FONT = "FiraCode Nerd Font"
local function font(size) return FONT .. " " .. size end
local UI = {
    radius_outer = 10,        -- wibar strip, tiles, popups, caption box
    radius_inner = 6,         -- pills, launcher, sliders, progressbars
    icon_w       = dpi(22),   -- icon cell width in every wibar pill
    icon_gap     = dpi(8),    -- icon -> text gap inside pills
    pill_l = dpi(12), pill_r = dpi(14), pill_t = dpi(4), pill_b = dpi(4),
    tile_margin  = dpi(24),   -- inner margin of desktop tiles
    tile_alpha   = "aa",      -- tile bg alpha suffix (~67%, frosted with blur)
    tile_border  = dpi(1),
    -- Wibar chips. The bar is 54 tall: 4+4 outer margin, 3+3 inner, leaving a
    -- 40px content row = chip_h 28 + chip_air 6 above and below. The air is
    -- what gives the focused tag's glow rings somewhere to live.
    chip_h    = dpi(28),
    chip_air  = dpi(6),
    seg_l = dpi(10), seg_r = dpi(10),  -- segment padding inside a grouped chip
    group_gap = dpi(12),               -- gap BETWEEN groups (vs 6 within one)
    div_inset = dpi(7),                -- segment hairline inset -> 14px rule
}

-- Desktop composition: one gutter governs every desktop element, so the three
-- anchors (dash top-left, media bottom-right, caption bottom-left) stay on
-- shared rails at any resolution.
local DESK = { gutter = dpi(24) }
-- }}}

-- This is used later as the default terminal and editor to run.
terminal = "alacritty"
filemanager = "dolphin"
screenshot = "flameshot gui"
browser = "brave"
password_manager = "keepassxc"
editor = "vim"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.tile,
}
-- }}}

-- Menubar configuration
menubar.utils.terminal = terminal

-- Measure rendered text width in pixels via Pango. Character-count heuristics
-- underestimate (they clipped the wallpaper caption), and they are outright
-- wrong for the proportional Propo faces in the type scale.
local _pango_ctx
local function text_width(text, font_desc)
    local lgi = require("lgi")
    if not _pango_ctx then
        _pango_ctx = lgi.PangoCairo.FontMap.get_default():create_context()
    end
    local layout = lgi.Pango.Layout.new(_pango_ctx)
    layout:set_font_description(lgi.Pango.FontDescription.from_string(font_desc))
    layout:set_text(text, -1)
    local _, logical = layout:get_pixel_extents()
    return logical.width
end

-- {{{ Shape + widget helpers
local function rounded(r)
    return function(cr, w, h) gears.shape.rounded_rect(cr, w, h, r) end
end

-- Hairlines. NOT `{ bg = X, forced_height = 1, widget = container.background }`:
-- a background container paints its bg from before_draw_children, which never
-- runs when it has no child — so every divider written that way drew NOTHING.
-- wibox.widget.separator draws itself. Vertical separators need an explicit
-- length: laid out in a fixed.horizontal they otherwise fit to zero height.
local function hline(colour, length)
    return {
        orientation   = "horizontal",
        thickness     = 1,
        color         = colour,
        forced_height = 1,
        forced_width  = length,
        widget        = wibox.widget.separator,
    }
end
local function vline(colour, length)
    return {
        orientation   = "vertical",
        thickness     = 1,
        color         = colour,
        forced_width  = 1,
        forced_height = length,
        widget        = wibox.widget.separator,
    }
end

-- Rofi theme follows the active arch-family theme (rofi-<theme>.rasi).
-- combi mode concatenates its sub-modes in order, so the power actions appear
-- as ordinary entries directly AFTER the apps rather than in a separate menu
-- you have to search. "power" is a rofi script mode (scripts/rofi-power-mode.sh).
local rofi_arch = "rofi -show combi -modes combi -combi-modes "
    .. "'drun,power:" .. os.getenv("HOME") .. "/.config/awesome/scripts/rofi-power-mode.sh'"
    .. " -show-icons -theme "
    .. os.getenv("HOME") .. "/.config/awesome/themes/" .. ACTIVE_THEME
    .. "/rofi-" .. ACTIVE_THEME .. ".rasi"

-- Build a "glyph + text" cell for the wibar right cluster.
-- Returns the widget and its textbox so callers can update the value.
-- Returns the pill, its value textbox and its icon textbox — every wibar
-- pill (cpu/mem/updates/volume/battery) is built from this one factory.
local function stat_cell(glyph, glyph_color, initial)
    local txt = wibox.widget {
        markup = "<span foreground='" .. C.text .. "'>" .. (initial or "") .. "</span>",
        widget = wibox.widget.textbox,
        valign = "center",
    }
    local icon_tb = wibox.widget {
        markup = "<span foreground='" .. (glyph_color or C.mauve) .. "'>" .. glyph .. "</span>",
        widget = wibox.widget.textbox,
        align  = "center",
        valign = "center",
    }
    local body = wibox.widget {
        {
            {
                icon_tb,
                forced_width = UI.icon_w,
                widget = wibox.container.background,
            },
            {
                txt,
                left = UI.icon_gap,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.horizontal,
        },
        left = UI.pill_l, right = UI.pill_r, top = UI.pill_t, bottom = UI.pill_b,
        widget = wibox.container.margin,
    }
    local box = wibox.widget {
        body,
        bg     = C.surface0,
        shape  = rounded(UI.radius_inner),
        widget = wibox.container.background,
    }
    return box, txt, icon_tb
end

-- {{{ Grouped wibar chips
-- Seven identical chips in a row read as a wall. Grouping them into three
-- segmented chips (system / session / time) with hairline dividers inside and
-- a wider gap between groups gives the eye a parse tree. Demoting a stat_cell
-- to a segment mutates the SAME widget the caller already bound buttons and
-- text handles to, so every existing behaviour survives untouched.
local function segment(box)
    box:set_bg(nil)      -- the group chip owns the surface now
    box:set_shape(nil)
    local body = box:get_children()[1]
    body:set_left(UI.seg_l)
    body:set_right(UI.seg_r)
    return box
end

local function seg_divider()
    return wibox.widget {
        vline(C.surface1, UI.chip_h - 2 * UI.div_inset),
        top = UI.div_inset, bottom = UI.div_inset,
        widget = wibox.container.margin,
    }
end

-- shape_clip keeps a segment's hover highlight from poking out past the
-- group's rounded corner.
local function group_chip(row)
    return wibox.widget {
        row,
        bg         = C.surface0,
        shape      = rounded(UI.radius_inner),
        shape_clip = true,
        widget     = wibox.container.background,
    }
end
-- }}}
-- }}}

-- {{{ Volume control — wibar widget + interactive popup slider
-- Font Awesome volume glyphs (reliable across all Nerd Font builds):
--   f026 = volume-off,  f027 = volume-low,  f028 = volume-high
local function vol_glyph(vol, muted)
    if muted or vol == 0 then return "\u{f026}" end
    if vol < 50 then return "\u{f027}" end
    return "\u{f028}"
end

-- Track current state globally.
local vol_state = { vol = 0, muted = false }

-- Wibar widget (one instance; will be created per-screen via factory below)
local vol_subscribers = {} -- list of { icon_tb, text_tb } to update
-- Generic listeners (the media panel shows volume when nothing is playing).
local vol_extra_subs = {}
function subscribe_volume(fn) table.insert(vol_extra_subs, fn) end

-- Guard against feedback loop: when render_volume programmatically sets the
-- slider, we must not treat that as a user-initiated change (which would
-- push a new pactl command).
local _updating_slider_programmatically = false
-- User is actively interacting with the popup (hovering/dragging).
-- When true, don't overwrite the slider from polls — let the user drive.
local _user_interacting = false

-- Forward declarations: render_volume() below restyles the mute button on
-- every poll, so it needs these names in scope before they are built.
local mute_btn_bg, mute_btn_lbl

-- Only one wibar popup may be open at a time. Each popup registers a closer
-- here and calls close_other_popups(its_own_tag) before showing itself.
local popup_closers = {}
function close_other_popups(except)
    for tag, fn in pairs(popup_closers) do
        if tag ~= except then fn() end
    end
end

local function render_volume()
    local glyph = vol_glyph(vol_state.vol, vol_state.muted)
    local color = vol_state.muted and C.red or C.mauve
    local label = vol_state.muted and "muted" or (vol_state.vol .. "%")
    for _, sub in ipairs(vol_subscribers) do
        sub.icon_tb:set_markup(
            "<span foreground='" .. color .. "'>" .. glyph .. "</span>")
        sub.text_tb:set_markup(
            "<span foreground='" .. C.text .. "'>" .. label .. "</span>")
    end
    for _, fn in ipairs(vol_extra_subs) do fn(vol_state.vol, vol_state.muted) end
    if vol_slider and not _user_interacting then
        _updating_slider_programmatically = true
        vol_slider:set_value(vol_state.vol)
        _updating_slider_programmatically = false
    end
    if vol_popup_pct then
        vol_popup_pct:set_markup(
            "<span font='" .. font(15) .. "' foreground='" .. C.text ..
            "' weight='bold'>" .. label .. "</span>")
    end
    if vol_popup_icon then
        vol_popup_icon:set_markup(
            "<span font='" .. font(20) .. "' foreground='" .. color .. "'>" ..
            glyph .. "</span>")
    end
    -- Mute button reflects state. This runs on every poll, so the state must
    -- live here rather than in the widget definitions.
    if mute_btn_lbl then
        mute_btn_lbl:set_markup(
            "<span font='" .. font(12) .. "' foreground='" ..
            (vol_state.muted and C.red or C.mauve) .. "'>" ..
            (vol_state.muted and "\u{f026}" or "\u{f028}") .. "</span>")
    end
    if mute_btn_bg and not mute_btn_bg._hovered then
        mute_btn_bg.bg = vol_state.muted and (C.red .. "26") or C.surface0
    end
end

local VOL_QUERY = "sh -c \"v=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '/Volume:/{print $5; exit}' | tr -d %); m=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}'); echo \\\"${v:-0} ${m:-no}\\\"\""

local function refresh_volume(then_cb)
    awful.spawn.easy_async(VOL_QUERY, function(stdout)
        local v_str, m_str = stdout:match("^(%S+)%s+(%S+)")
        vol_state.vol = tonumber(v_str) or 0
        vol_state.muted = (m_str == "yes")
        render_volume()
        if then_cb then then_cb() end
    end)
end

-- Poll every 5s to catch external volume changes (e.g. other apps)
gears.timer {
    timeout = 5, autostart = true, call_now = true,
    callback = function() refresh_volume() end,
}

-- {{ Volume popup (interactive slider)
local VOL_POPUP_W      = 360
local VOL_POPUP_BASE_H = 184 -- height with the device dropdown collapsed
local VOL_POPUP_PAD    = 16
local VOL_ROW_H        = dpi(32)
local VOL_ROW_STRIDE   = VOL_ROW_H + 4 -- row height + sink_rows spacing

vol_popup_icon = wibox.widget {
    markup = "<span font='" .. font(20) .. "' foreground='" .. C.mauve .. "'>\u{f028}</span>",
    widget = wibox.widget.textbox,
    align  = "center", valign = "center",
}
vol_popup_pct = wibox.widget {
    markup = "<span font='" .. font(15) .. "' foreground='" .. C.text .. "' weight='bold'>--%</span>",
    widget = wibox.widget.textbox,
    valign = "center",
}
-- Current output device, shown under the percentage.
local vol_popup_dev = wibox.widget {
    markup    = "<span font='" .. font(9) .. "' foreground='" .. C.subtext1 .. "'>…</span>",
    widget    = wibox.widget.textbox,
    valign    = "center",
    ellipsize = "end",
}

vol_slider = wibox.widget {
    bar_shape           = rounded(UI.radius_inner),
    bar_height          = 10,
    bar_color           = C.surface0,
    bar_active_color    = C.mauve,
    handle_color        = C.text,
    handle_shape        = gears.shape.circle,
    handle_width        = 18,
    handle_border_width = 2,
    handle_border_color = C.mauve,
    value               = 0,
    maximum             = 100,
    forced_width        = VOL_POPUP_W - 2 * VOL_POPUP_PAD,
    forced_height       = 24,
    widget              = wibox.widget.slider,
}

-- User-driven slider changes push to pactl; programmatic updates are ignored.
-- We also debounce so that rapid drags only push every ~80ms.
local _vol_push_pending = false
local _vol_last_pushed  = -1
vol_slider:connect_signal("property::value", function(self)
    if _updating_slider_programmatically then return end
    local v = math.floor(self.value or 0)
    if vol_popup_timer and vol_popup_timer.started then vol_popup_timer:again() end
    if _vol_push_pending then return end
    _vol_push_pending = true
    gears.timer.start_new(0.08, function()
        _vol_push_pending = false
        -- Use the latest slider value at flush time (coalesce rapid drags)
        local final_v = math.floor(vol_slider.value or 0)
        if final_v == _vol_last_pushed then return false end
        _vol_last_pushed = final_v
        -- Update local state so subsequent render_volume calls don't fight
        vol_state.vol = final_v
        awful.spawn.easy_async(
            "pactl set-sink-volume @DEFAULT_SINK@ " .. final_v .. "%",
            function() end)
        return false
    end)
end)

-- Square 36x36 mute button (assignment, not declaration — see forward decl).
mute_btn_bg = wibox.container.background()
mute_btn_bg.bg    = C.surface0
mute_btn_bg.shape = rounded(UI.radius_inner)
mute_btn_lbl = wibox.widget {
    markup = "<span font='" .. font(12) .. "' foreground='" .. C.mauve .. "'>\u{f028}</span>",
    widget = wibox.widget.textbox,
    align  = "center", valign = "center",
}
mute_btn_bg:set_widget(wibox.widget {
    mute_btn_lbl,
    width    = dpi(36),
    height   = dpi(36),
    strategy = "exact",
    widget   = wibox.container.constraint,
})
mute_btn_bg:buttons(gears.table.join(
    awful.button({}, 1, function()
        awful.spawn.easy_async("pactl set-sink-mute @DEFAULT_SINK@ toggle", function()
            refresh_volume()
        end)
    end)
))
mute_btn_bg:connect_signal("mouse::enter", function()
    mute_btn_bg._hovered = true
    mute_btn_bg.bg = vol_state.muted and (C.red .. "40") or C.surface1
end)
mute_btn_bg:connect_signal("mouse::leave", function()
    mute_btn_bg._hovered = false
    render_volume()
end)

-- {{ Output device selector (dropdown inside the volume popup)
local sink_state = { list = {}, default = nil }
local sink_dropdown_open = false
local refresh_sinks -- forward declaration; defined below vol_popup

-- One line default sink name, then alternating Name/Description per sink.
local SINK_QUERY = [[sh -c 'pactl get-default-sink; pactl list sinks | sed -n "s/^\tName: //p;s/^\tDescription: //p"']]

local sink_btn_lbl = wibox.widget {
    markup = "<span foreground='" .. C.subtext1 .. "'>Output device</span>",
    widget = wibox.widget.textbox,
    valign = "center",
}
local sink_btn_chev = wibox.widget {
    markup = "<span foreground='" .. C.overlay0 .. "'>\u{f078}</span>",
    widget = wibox.widget.textbox,
    valign = "center",
    align  = "center",
}
local sink_btn_bg = wibox.container.background()
sink_btn_bg.bg    = C.surface0
sink_btn_bg.shape = rounded(UI.radius_inner)
sink_btn_bg:set_widget(wibox.widget {
    {
        {
            {
                markup = "<span foreground='" .. C.mauve .. "'>\u{f025}</span>",
                widget = wibox.widget.textbox,
                valign = "center",
            },
            {
                sink_btn_lbl,
                left = 8, right = 8,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.horizontal,
        },
        nil,
        sink_btn_chev,
        layout = wibox.layout.align.horizontal,
    },
    left = 12, right = 12, top = 6, bottom = 6,
    widget = wibox.container.margin,
})
sink_btn_bg:buttons(gears.table.join(
    awful.button({}, 1, function()
        sink_dropdown_open = not sink_dropdown_open
        refresh_sinks()
    end)
))

local sink_rows = wibox.widget {
    spacing = 4,
    layout  = wibox.layout.fixed.vertical,
}
-- }}

local vol_popup = wibox({
    width        = VOL_POPUP_W,
    height       = VOL_POPUP_BASE_H,
    ontop        = true,
    visible      = false,
    bg           = C.mantle .. "e6", -- shaped wibox -> picom blurs behind it
    fg           = C.text,
    shape        = rounded(UI.radius_outer),
    border_width = 2,
    border_color = C.mauve,
    type         = "notification",
})
vol_popup:setup {
    {
        {
            -- Header: big icon, then percent over the device name, mute right.
            {
                {
                    vol_popup_icon,
                    forced_width  = dpi(44),
                    forced_height = dpi(44),
                    widget = wibox.container.background,
                },
                {
                    {
                        vol_popup_pct,
                        {
                            vol_popup_dev,
                            width    = dpi(190),
                            strategy = "max",
                            widget   = wibox.container.constraint,
                        },
                        layout = wibox.layout.fixed.vertical,
                    },
                    left = 12,
                    widget = wibox.container.margin,
                },
                layout = wibox.layout.fixed.horizontal,
            },
            nil,
            mute_btn_bg,
            layout = wibox.layout.align.horizontal,
        },
        vol_slider,
        hline(C.surface0),
        sink_btn_bg,
        sink_rows,
        spacing = 12,
        layout  = wibox.layout.fixed.vertical,
    },
    margins = VOL_POPUP_PAD,
    widget  = wibox.container.margin,
}

-- {{ Output device selector logic (needs vol_popup to exist)

local function vol_popup_resize()
    local extra = 0
    if sink_dropdown_open and #sink_state.list > 0 then
        extra = #sink_state.list * VOL_ROW_STRIDE
    end
    vol_popup.height = VOL_POPUP_BASE_H + extra
end

local function make_sink_row(sink)
    local active = (sink.name == sink_state.default)
    local fg     = active and C.mauve or C.text
    local mark   = active and "\u{f00c}  " or ""
    local row = wibox.widget {
        {
            {
                markup    = "<span foreground='" .. fg .. "'>" .. mark ..
                            gears.string.xml_escape(sink.desc) .. "</span>",
                widget    = wibox.widget.textbox,
                valign    = "center",
                ellipsize = "end",
            },
            left = 12, right = 12,
            widget = wibox.container.margin,
        },
        bg            = active and (C.mauve .. "33") or C.surface0,
        shape         = rounded(UI.radius_inner),
        forced_height = VOL_ROW_H,
        widget        = wibox.container.background,
    }
    row:connect_signal("mouse::enter", function() row.bg = C.surface1 end)
    row:connect_signal("mouse::leave", function()
        row.bg = active and (C.mauve .. "33") or C.surface0
    end)
    row:buttons(gears.table.join(
        awful.button({}, 1, function()
            -- Switch the default sink and move already-playing streams over,
            -- so the change is audible immediately.
            awful.spawn.easy_async(
                "sh -c 'pactl set-default-sink " .. sink.name ..
                "; pactl list short sink-inputs | cut -f1 | " ..
                "while read i; do pactl move-sink-input \"$i\" " .. sink.name .. "; done'",
                function()
                    sink_dropdown_open = false
                    refresh_sinks()
                    refresh_volume()
                end)
        end)
    ))
    return row
end

refresh_sinks = function()
    awful.spawn.easy_async(SINK_QUERY, function(stdout)
        local lines = {}
        for l in stdout:gmatch("[^\r\n]+") do lines[#lines + 1] = l end
        sink_state.default = table.remove(lines, 1)
        sink_state.list = {}
        for i = 1, #lines - 1, 2 do
            table.insert(sink_state.list, { name = lines[i], desc = lines[i + 1] })
        end
        local cur_desc = "no output device"
        for _, s in ipairs(sink_state.list) do
            if s.name == sink_state.default then cur_desc = s.desc end
        end
        vol_popup_dev:set_markup("<span font='" .. font(9) .. "' foreground='" ..
            C.subtext1 .. "'>" .. gears.string.xml_escape(cur_desc) .. "</span>")
        sink_btn_chev:set_markup("<span foreground='" .. C.overlay0 .. "'>" ..
            (sink_dropdown_open and "\u{f077}" or "\u{f078}") .. "</span>")
        sink_rows:reset()
        if sink_dropdown_open then
            for _, s in ipairs(sink_state.list) do
                sink_rows:add(make_sink_row(s))
            end
        end
        vol_popup_resize()
    end)
end
-- }}

-- Auto-hide popup on inactivity. Mouse hover pauses the timer so the
-- user can drag the slider for as long as they want.
vol_popup_timer = gears.timer {
    timeout = 4, single_shot = true,
    callback = function() vol_popup.visible = false end,
}
vol_popup:connect_signal("mouse::enter", function()
    _user_interacting = true
    if vol_popup_timer.started then vol_popup_timer:stop() end
end)
vol_popup:connect_signal("mouse::leave", function()
    _user_interacting = false
    vol_popup_timer:again()
    -- Reconcile slider with actual volume once the user is done
    refresh_volume()
end)

popup_closers.volume = function() vol_popup.visible = false end

local function vol_popup_show(anchor_widget)
    close_other_popups("volume")
    local scr = awful.screen.focused()
    vol_popup.screen = scr
    -- Position: top-right under the wibar
    awful.placement.top_right(vol_popup, { parent = scr, margins = { top = 60, right = 20 } })
    vol_popup.visible = true
    render_volume()
    -- Re-scan outputs on every open so hotplugged devices show up
    sink_dropdown_open = false
    refresh_sinks()
    if vol_popup_timer.started then vol_popup_timer:again() else vol_popup_timer:start() end
end
local function vol_popup_toggle()
    if vol_popup.visible then
        vol_popup.visible = false
    else
        vol_popup_show()
    end
end

-- Factory: make a wibar volume widget for a given screen.
local function make_volume_widget()
    local w, text_tb, icon_tb = stat_cell("\u{f028}", C.mauve, "--%")
    table.insert(vol_subscribers, { icon_tb = icon_tb, text_tb = text_tb })
    w:buttons(gears.table.join(
        awful.button({}, 1, function() vol_popup_toggle() end),
        awful.button({}, 3, function()
            awful.spawn.easy_async("pactl set-sink-mute @DEFAULT_SINK@ toggle", refresh_volume)
        end),
        awful.button({}, 4, function()
            awful.spawn.easy_async("pactl set-sink-volume @DEFAULT_SINK@ +5%", refresh_volume)
        end),
        awful.button({}, 5, function()
            awful.spawn.easy_async("pactl set-sink-volume @DEFAULT_SINK@ -5%", refresh_volume)
        end)
    ))
    return w
end
-- }}}

-- {{{ Native CPU / RAM polling (replaces vicious — no flicker)
local cpu_subs = {}  -- { setter = function(pct) end, ... }
local mem_subs = {}

local function subscribe_cpu(fn) table.insert(cpu_subs, fn) end
local function subscribe_mem(fn) table.insert(mem_subs, fn) end

local _cpu_last
local function poll_cpu()
    local f = io.open("/proc/stat", "r")
    if not f then return end
    local line = f:read("*l"); f:close()
    local n = {}
    for v in (line or ""):gmatch("%d+") do n[#n+1] = tonumber(v) end
    if #n < 4 then return end
    local user, nice, system, idle = n[1], n[2], n[3], n[4]
    local iowait, irq, softirq, steal = n[5] or 0, n[6] or 0, n[7] or 0, n[8] or 0
    local total = user + nice + system + idle + iowait + irq + softirq + steal
    local busy  = total - idle - iowait
    if _cpu_last then
        local dt = total - _cpu_last.total
        local db = busy  - _cpu_last.busy
        if dt > 0 then
            local pct = math.floor(db * 100 / dt + 0.5)
            if pct < 0 then pct = 0 end
            if pct > 100 then pct = 100 end
            for _, fn in ipairs(cpu_subs) do fn(pct) end
        end
    end
    _cpu_last = { total = total, busy = busy }
end

local function poll_mem()
    local f = io.open("/proc/meminfo", "r")
    if not f then return end
    local total, avail
    for l in f:lines() do
        local k, v = l:match("^(%w+):%s*(%d+)")
        if k == "MemTotal" then total = tonumber(v)
        elseif k == "MemAvailable" then avail = tonumber(v) end
        if total and avail then break end
    end
    f:close()
    if total and avail and total > 0 then
        local pct = math.floor((total - avail) * 100 / total + 0.5)
        for _, fn in ipairs(mem_subs) do fn(pct) end
    end
end

gears.timer { timeout = 2, autostart = true, call_now = true, callback = poll_cpu }
gears.timer { timeout = 3, autostart = true, call_now = true, callback = poll_mem }

-- Pacman updates — ONE checkupdates poller feeding every subscriber
-- (wibar pill + neofetch tile line), instead of a watcher per widget
-- per screen.
local upd_subs = {}
local function subscribe_updates(fn) table.insert(upd_subs, fn) end
gears.timer {
    timeout = 900, autostart = true, call_now = true,
    callback = function()
        awful.spawn.easy_async_with_shell("checkupdates 2>/dev/null | wc -l", function(out)
            local n = tonumber((out or ""):match("%d+")) or 0
            for _, fn in ipairs(upd_subs) do fn(n) end
        end)
    end,
}

-- {{{ Battery (laptop only — widget is skipped entirely when no battery)
local BAT_PATH
for _, name in ipairs({ "BAT0", "BAT1", "BATT" }) do
    local probe = io.open("/sys/class/power_supply/" .. name .. "/capacity", "r")
    if probe then probe:close(); BAT_PATH = "/sys/class/power_supply/" .. name; break end
end

local bat_subs = {}

local function read_sys(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local v = f:read("*l"); f:close()
    return v
end

-- Material Design battery glyphs (Nerd Fonts v3 range) — single-cell width,
-- unlike the Font Awesome f240-f244 set which is ~1.5em and clips in the cell.
local function bat_glyph(cap, charging)
    if charging then return "\u{f0084}" end -- battery-charging
    if cap >= 90 then return "\u{f0079}" end -- full
    if cap >= 65 then return "\u{f0081}" end -- 80
    if cap >= 40 then return "\u{f007e}" end -- 50
    if cap >= 15 then return "\u{f007c}" end -- 30
    return "\u{f007a}"                       -- 10
end

local function poll_battery()
    if not BAT_PATH then return end
    local cap    = tonumber(read_sys(BAT_PATH .. "/capacity")) or 0
    local status = read_sys(BAT_PATH .. "/status") or "Unknown"
    -- energy_* (µWh/µW) on most laptops, charge_* (µAh/µA) on some.
    local now  = tonumber(read_sys(BAT_PATH .. "/energy_now"))  or tonumber(read_sys(BAT_PATH .. "/charge_now"))
    local full = tonumber(read_sys(BAT_PATH .. "/energy_full")) or tonumber(read_sys(BAT_PATH .. "/charge_full"))
    local rate = tonumber(read_sys(BAT_PATH .. "/power_now"))   or tonumber(read_sys(BAT_PATH .. "/current_now"))
    local charging = (status == "Charging")

    -- Time to empty (discharging) or to full (charging). rate is 0/absent
    -- for a moment right after plugging/unplugging — show no estimate then.
    local hours
    if rate and rate > 0 and now then
        if status == "Discharging" then
            hours = now / rate
        elseif charging and full then
            hours = (full - now) / rate
        end
    end
    local time_str = ""
    if hours then
        local mins = math.floor(hours * 60 + 0.5)
        time_str = string.format(" %d:%02d", math.floor(mins / 60), mins % 60)
    end

    local color = charging and C.green
        or (cap <= 15 and C.red or (cap <= 30 and C.peach or C.sky))
    local label = ("%d%%%s"):format(cap, time_str)
    if status == "Full" then label = cap .. "%" end

    for _, sub in ipairs(bat_subs) do
        sub.icon:set_markup("<span foreground='" .. color .. "'>" .. bat_glyph(cap, charging) .. "</span>")
        sub.text:set_markup("<span foreground='" .. C.text .. "'>" .. label .. "</span>")
    end
end

if BAT_PATH then
    gears.timer { timeout = 30, autostart = true, call_now = true, callback = poll_battery }
end

local function make_battery_widget()
    local w, text, icon = stat_cell(bat_glyph(0, false), C.sky, "--")
    table.insert(bat_subs, { icon = icon, text = text })
    poll_battery()
    return w
end
-- }}}
-- }}}

-- {{{ Random philosopher quote (English, rotates per awesome restart)
math.randomseed(os.time())
local quotes = {
    { q = "The unexamined life is not worth living.",                                  a = "Socrates" },
    { q = "We are what we repeatedly do. Excellence, then, is not an act, but a habit.", a = "Aristotle" },
    { q = "He who has a why to live can bear almost any how.",                         a = "Friedrich Nietzsche" },
    { q = "I think, therefore I am.",                                                  a = "René Descartes" },
    { q = "Happiness depends upon ourselves.",                                         a = "Aristotle" },
    { q = "The only true wisdom is in knowing you know nothing.",                      a = "Socrates" },
    { q = "Man is condemned to be free.",                                              a = "Jean-Paul Sartre" },
    { q = "There is nothing permanent except change.",                                 a = "Heraclitus" },
    { q = "He who is not contented with what he has, would not be contented with what he would like to have.", a = "Socrates" },
    { q = "The life of money-making is one undertaken under compulsion.",              a = "Aristotle" },
    { q = "That which does not kill us makes us stronger.",                            a = "Friedrich Nietzsche" },
    { q = "Whereof one cannot speak, thereof one must be silent.",                     a = "Ludwig Wittgenstein" },
    { q = "The function of prayer is not to influence God, but rather to change the nature of the one who prays.", a = "Søren Kierkegaard" },
    { q = "Life can only be understood backwards; but it must be lived forwards.",     a = "Søren Kierkegaard" },
    { q = "Liberty consists in doing what one desires.",                               a = "John Stuart Mill" },
    { q = "It is not death that a man should fear, but he should fear never beginning to live.", a = "Marcus Aurelius" },
    { q = "You have power over your mind — not outside events. Realize this, and you will find strength.", a = "Marcus Aurelius" },
    { q = "We suffer more often in imagination than in reality.",                      a = "Seneca" },
    { q = "Wonder is the beginning of wisdom.",                                        a = "Socrates" },
    { q = "Entities should not be multiplied without necessity.",                      a = "William of Ockham" },
    { q = "God is dead, and we have killed him.",                                      a = "Friedrich Nietzsche" },
    { q = "The greatest happiness of the greatest number is the foundation of morals and legislation.", a = "Jeremy Bentham" },
    { q = "One cannot step twice in the same river.",                                  a = "Heraclitus" },
    { q = "Knowledge is power.",                                                       a = "Francis Bacon" },
    { q = "Hell is other people.",                                                     a = "Jean-Paul Sartre" },
}
local pick = quotes[math.random(#quotes)]
local quote_text = pick.q
local quote_author = pick.a
-- }}}

-- {{{ Neofetch-style static info (read directly from /proc & /etc)
local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local l = f:read("*l") or ""
    f:close()
    return l
end

local function read_proc_field(path, key)
    local f = io.open(path, "r")
    if not f then return "" end
    for line in f:lines() do
        local v = line:match("^" .. key .. "%s*:%s*(.+)$")
        if v then f:close(); return v end
    end
    f:close()
    return ""
end

local function read_os_pretty()
    local f = io.open("/etc/os-release", "r")
    if not f then return "Linux" end
    for line in f:lines() do
        local name = line:match('^PRETTY_NAME="([^"]+)"')
        if not name then name = line:match("^PRETTY_NAME=(.+)$") end
        if name then f:close(); return name end
    end
    f:close()
    return "Linux"
end

local function count_pacman_packages()
    local n = 0
    local p = io.popen("ls -1 /var/lib/pacman/local 2>/dev/null")
    if not p then return "?" end
    for _ in p:lines() do n = n + 1 end
    p:close()
    -- ALPM_DB_VERSION file takes one slot
    if n > 0 then n = n - 1 end
    return tostring(n)
end

local function hostname()
    local h = read_first_line("/etc/hostname")
    if h ~= "" then return h end
    local p = io.popen("hostname")
    if p then h = p:read("*l") or ""; p:close() end
    return h ~= "" and h or "host"
end

local _cpu_model = read_proc_field("/proc/cpuinfo", "model name")
_cpu_model = _cpu_model:gsub("%(R%)", ""):gsub("%(TM%)", "")
_cpu_model = _cpu_model:gsub("%s*CPU%s*@.*$", ""):gsub("%s*@.*$", "")
_cpu_model = _cpu_model:gsub("%s+%- .*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
_cpu_model = _cpu_model:gsub("%s+", " ")

-- GPU model from lspci (blocking, once at load — same as the other probes).
local function read_gpu()
    local p = io.popen("lspci -mm 2>/dev/null | grep -iE 'vga|3d controller' | head -1")
    if not p then return "" end
    local line = p:read("*l") or ""; p:close()
    -- lspci -mm quotes the fields: slot "class" "vendor" "device" ...
    local fields = {}
    for f in line:gmatch('"([^"]*)"') do fields[#fields + 1] = f end
    local vendor, device = fields[2] or "", fields[3] or ""
    vendor = vendor:gsub("Advanced Micro Devices.*", "AMD")
                   :gsub("NVIDIA Corporation", "NVIDIA")
                   :gsub("Intel Corporation", "Intel")
    -- Prefer the marketing name inside brackets: "Navi 33 [Radeon RX 7600 …]"
    local pretty = device:match("%[([^%]]+)%]") or device
    pretty = pretty:gsub("%s*/%s*.*$", "")          -- drop "/7600 XT/7600M…" tails
                   :gsub("%s*%(rev.*$", "")
                   :gsub("^%s+", ""):gsub("%s+$", "")
    if pretty == "" then return "" end
    return (vendor ~= "" and (vendor .. " ") or "") .. pretty
end

local function read_mem_total()
    local f = io.open("/proc/meminfo", "r")
    if not f then return "" end
    for l in f:lines() do
        local kb = l:match("^MemTotal:%s*(%d+)")
        if kb then f:close(); return string.format("%.1f GiB", tonumber(kb) / 1048576) end
    end
    f:close(); return ""
end

local sys_info = {
    user_host = (os.getenv("USER") or "user") .. "@" .. hostname(),
    os_name   = read_os_pretty(),
    kernel    = (function()
        local p = io.popen("uname -r")
        if not p then return "" end
        local v = p:read("*l") or ""; p:close()
        return v
    end)(),
    shell     = (os.getenv("SHELL") or ""):match("([^/]+)$") or "sh",
    wm        = "AwesomeWM",
    packages  = count_pacman_packages(),
    cpu       = _cpu_model,
    gpu       = read_gpu(),
    mem       = read_mem_total(),
}
-- }}}

-- {{{ Taglist / Tasklist mouse bindings
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))
-- }}}

-- {{{ Per-screen setup: tags, wibar, desktop tiles
-- Tag glyphs (FiraCode Nerd Font)
local tag_glyphs = { "\u{f489}", "\u{f0ac}", "\u{f11b}", "\u{f121}", "\u{f025}" }

awful.screen.connect_for_each_screen(function(s)

    -- CPU/RAM — subscribe to native polling (no vicious, no flicker)
    local cpu_box, cpu_txt = stat_cell("\u{f4bc}", C.peach, "--%")
    subscribe_cpu(function(pct)
        cpu_txt:set_markup("<span foreground='" .. C.text .. "'>" .. pct .. "%</span>")
    end)

    local mem_box, mem_txt = stat_cell("\u{f2db}", C.green, "--%")
    subscribe_mem(function(pct)
        mem_txt:set_markup("<span foreground='" .. C.text .. "'>" .. pct .. "%</span>")
    end)

    -- Pacman updates (shared checkupdates poller). upd_seg is forward-declared
    -- because the poller closure below captures it, but the segment itself can
    -- only be built once the grouping helpers run further down.
    local upd_seg
    local upd_box, upd_txt = stat_cell("\u{f019}", C.yellow, "0")
    subscribe_updates(function(n)
        if n > 0 then
            upd_txt:set_markup("<span foreground='" .. C.red .. "'>" .. n .. "</span>")
            -- toggle the segment: it carries its own leading divider, so hiding
            -- it removes the rule too and leaves no orphan hairline
            if upd_seg then upd_seg.visible = true end
        else
            if upd_seg then upd_seg.visible = false end
        end
    end)
    upd_box:buttons(gears.table.join(
        awful.button({}, 1, function()
            awful.spawn(terminal .. " -e sh -c 'sudo pacman -Syu; echo; echo Press Enter to close; read'")
        end)
    ))

    -- Create tags with nerd-font glyph names
    for i = 1, 5 do
        awful.tag.add(tag_glyphs[i], {
            layout             = awful.layout.suit.tile,
            master_fill_policy = "expand",
            gap_single_client  = true,
            -- gap comes from theme.useless_gap — one source of truth
            screen             = s,
            selected           = (i == 1),
        })
    end

    s.mypromptbox = awful.widget.prompt()

    -- Taglist. Per tag, a 56x40 stack inside the 40px content row:
    --   glow_1/2/3  concentric accent rings; each radius steps down in lockstep
    --               with its inset so every outline stays parallel to the pill,
    --               which is what makes three flat rects read as one soft bloom.
    --               Composited alpha ramps 8 -> 25 -> 51 -> 100%.
    --   pill        background_role; awesome drives its bg/fg/shape from the
    --               theme, so the shape MUST come from the theme/style table —
    --               awful.widget.common overwrites background_role.shape on
    --               every list update, which silently kills a template shape.
    --   occupied    2px tick at the pill's bottom edge = "this tag has windows".
    -- The empty rings cost no space (background:fit returns 0,0 without a child
    -- and stack:fit takes the max), so switching tags never shifts the layout.
    local function tag_state(self, t)
        local sel = t.selected
        for _, id in ipairs({ "glow_1", "glow_2", "glow_3" }) do
            self:get_children_by_id(id)[1].visible = sel
        end
        -- Hidden while selected: the glow already says "you are here", and a
        -- tick on a solid accent pill is just noise.
        self:get_children_by_id("occupied")[1].visible = (#t:clients() > 0) and not sel
    end

    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        layout  = { spacing = 0, layout = wibox.layout.fixed.horizontal },
        style   = {
            -- Shapes belong here, not in the template: awful.widget.common
            -- assigns background_role.shape from the theme on every update, so
            -- a shape set in the template is silently overwritten.
            shape                    = rounded(UI.radius_inner),
            shape_focus              = rounded(UI.radius_inner),
            shape_empty              = rounded(UI.radius_inner),
            shape_border_width_empty = 1,
        },
        widget_template = {
            {
                id      = "glow_1",
                visible = false,
                bg      = C.mauve .. "14",
                shape   = rounded(UI.radius_inner + 6),
                widget  = wibox.container.background,
            },
            {
                {
                    id      = "glow_2",
                    visible = false,
                    bg      = C.mauve .. "2e",
                    shape   = rounded(UI.radius_inner + 4),
                    widget  = wibox.container.background,
                },
                margins = dpi(2),
                widget  = wibox.container.margin,
            },
            {
                {
                    id      = "glow_3",
                    visible = false,
                    bg      = C.mauve .. "59",
                    shape   = rounded(UI.radius_inner + 2),
                    widget  = wibox.container.background,
                },
                margins = dpi(4),
                widget  = wibox.container.margin,
            },
            {
                {
                    {
                        {
                            {
                                { id = "text_role", widget = wibox.widget.textbox,
                                  align = "center", valign = "center" },
                                -- separator, not a childless background: the
                                -- latter never paints (see hline/vline).
                                { { id = "occupied", color = C.mauve,
                                    orientation = "horizontal", thickness = dpi(2),
                                    forced_width = dpi(12), forced_height = dpi(2),
                                    visible = false,
                                    widget = wibox.widget.separator },
                                  valign = "bottom", halign = "center",
                                  widget = wibox.container.place },
                                layout = wibox.layout.stack,
                            },
                            forced_width  = dpi(26),
                            forced_height = dpi(22),
                            widget = wibox.container.background,
                        },
                        left = 9, right = 9, top = 3, bottom = 3,
                        widget = wibox.container.margin,
                    },
                    id     = "background_role",
                    widget = wibox.container.background,
                },
                -- This 6px inset IS the glow gutter: the rings paint into it,
                -- which is why the bar's content row is 40px and not 28.
                margins = dpi(6),
                widget  = wibox.container.margin,
            },
            layout = wibox.layout.stack,
            create_callback = tag_state,
            update_callback = tag_state,
        },
    }

    -- Tasklist: icon-only pills; the focused client also shows its title (a
    -- second, free emphasis cue) with the underline. Always-on titles turn the
    -- middle of the bar into a wall of text that competes with the tag accent.
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        layout  = { spacing = 4, layout = wibox.layout.fixed.horizontal },
        style   = {
            -- see the taglist note: shapes must come from style, not the template
            shape       = rounded(UI.radius_inner),
            shape_focus = rounded(UI.radius_inner),
        },
        widget_template = {
            {
                {
                    {
                        {
                            {
                                -- Fixed 20x20 icon cell: clients supply icons at
                                -- arbitrary sizes; unsized they dictate pill height.
                                {
                                    {
                                        id     = "icon_role",
                                        widget = wibox.widget.imagebox,
                                    },
                                    width    = dpi(20),
                                    height   = dpi(20),
                                    strategy = "exact",
                                    widget   = wibox.container.constraint,
                                },
                                margins = 4,
                                widget  = wibox.container.margin,
                            },
                            {
                                {
                                    {
                                        id     = "text_role",
                                        widget = wibox.widget.textbox,
                                    },
                                    -- textbox ellipsizes at "end" by default, so a
                                    -- long page title truncates instead of pushing
                                    -- the whole cluster sideways
                                    width    = dpi(180),
                                    strategy = "max",
                                    widget   = wibox.container.constraint,
                                },
                                id     = "title",
                                left   = 2, right = 8,
                                widget = wibox.container.margin,
                            },
                            layout = wibox.layout.fixed.horizontal,
                        },
                        left = 4, top = 3, bottom = 3,
                        widget = wibox.container.margin,
                    },
                    id     = "background_role",
                    widget = wibox.container.background,
                },
                {
                    {
                        id            = "underline",
                        bg            = C.mauve,
                        forced_height = 2,
                        forced_width  = dpi(26),
                        visible       = false,
                        shape         = gears.shape.rounded_bar,
                        widget        = wibox.container.background,
                    },
                    halign = "center",
                    widget = wibox.container.place,
                },
                layout = wibox.layout.fixed.vertical,
            },
            widget = wibox.container.background,
            create_callback = function(self, c)
                local ul = self:get_children_by_id("underline")[1]
                local tw = self:get_children_by_id("title")[1]
                local function set(focused)
                    ul.visible = focused
                    tw.visible = focused
                end
                set(client.focus == c)
                c:connect_signal("focus",   function() set(true)  end)
                c:connect_signal("unfocus", function() set(false) end)
            end,
        },
    }

    -- Launcher button (Arch logo — distinctive: mauve fill, inverted glyph)
    -- No bold: it distorts the Arch glyph. The cell needs an explicit height
    -- too — without one the textbox line box decides, and the glyph (which has
    -- a lot of top bearing) rides high in the pill.
    local launcher_glyph = wibox.widget {
        {
            markup = "<span font='" .. font(13) .. "' foreground='" .. C.base ..
                     "'>\u{f303}</span>",
            widget = wibox.widget.textbox,
            align  = "center",
            valign = "center",
        },
        forced_width  = dpi(22),
        forced_height = dpi(22),
        widget = wibox.container.background,
    }
    local launcher_bg = wibox.widget {
        {
            launcher_glyph,
            left = 9, right = 9, top = 3, bottom = 3,
            widget = wibox.container.margin,
        },
        bg     = C.mauve,
        shape  = rounded(UI.radius_inner),
        widget = wibox.container.background,
    }
    -- Right-side separator to visually divide launcher from tags
    local launcher = wibox.widget {
        {
            launcher_bg,
            right = 8,
            widget = wibox.container.margin,
        },
        {
            vline(C.surface1, UI.chip_h + 2 * UI.chip_air - 2 * dpi(9)),
            top = dpi(9), bottom = dpi(9),
            widget = wibox.container.margin,
        },
        {
            forced_width = 8,
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.fixed.horizontal,
    }
    launcher_bg:buttons(gears.table.join(
        awful.button({}, 1, function() awful.spawn(rofi_arch) end)
    ))
    launcher_bg:connect_signal("mouse::enter", function() launcher_bg.bg = C.pink end)
    launcher_bg:connect_signal("mouse::leave", function() launcher_bg.bg = C.mauve end)

    -- Clock — same icon-cell/text anatomy as every other pill.
    local clock_icon = wibox.widget {
        {
            markup = "<span foreground='" .. C.mauve .. "'>\u{f017}</span>",
            widget = wibox.widget.textbox,
            align  = "center",
            valign = "center",
        },
        forced_width = UI.icon_w,
        widget = wibox.container.background,
    }
    local clock_txt = wibox.widget.textclock(
        "<span foreground='" .. C.text .. "'>%H:%M  </span>" ..
        "<span foreground='" .. C.subtext1 .. "'>%a %d %b</span>", 60)
    local clock_box = wibox.widget {
        {
            {
                clock_icon,
                { clock_txt, left = UI.icon_gap, widget = wibox.container.margin },
                layout = wibox.layout.fixed.horizontal,
            },
            left = UI.pill_l, right = UI.pill_r, top = UI.pill_t, bottom = UI.pill_b,
            widget = wibox.container.margin,
        },
        bg     = C.surface0,
        shape  = rounded(UI.radius_inner),
        widget = wibox.container.background,
    }

    -- Calendar popup: click the clock for a month grid, scroll to page months.
    -- Styled to match the volume popup (frosted, accent border, rounded).
    local cal_popup = awful.widget.calendar_popup.month({
        screen        = s,
        start_sunday  = false,
        week_numbers  = false,
        long_weekdays = false,
        style_month   = { border_width = 0, bg_color = "#00000000", padding = 10 },
        style_header  = {
            border_width = 0, bg_color = "#00000000",
            fg_color = C.mauve,
            markup = function(t) return "<b>" .. t .. "</b>" end,
        },
        style_weekday = {
            border_width = 0, bg_color = "#00000000", fg_color = C.blue, padding = 6,
            markup = function(t) return "<b>" .. string.format("%2s", t) .. "</b>" end,
        },
        style_normal  = {
            border_width = 0, bg_color = "#00000000", fg_color = C.text, padding = 6,
            -- Cells auto-size to their text, so "1" and "11" produced ragged
            -- columns. Padding to a fixed width in a monospace font fixes it.
            markup = function(t) return string.format("%2s", t) end,
        },
        style_focus   = {
            border_width = 0, bg_color = C.mauve, fg_color = C.base, padding = 6,
            shape = rounded(UI.radius_inner),
            markup = function(t) return "<b>" .. string.format("%2s", t) .. "</b>" end,
        },
    })
    cal_popup.bg           = C.mantle .. "e6"
    cal_popup.fg           = C.text
    cal_popup.shape        = rounded(UI.radius_outer)
    cal_popup.border_width = 2
    cal_popup.border_color = C.mauve
    cal_popup.ontop        = true

    local cal_timer = gears.timer {
        timeout = 6, single_shot = true,
        callback = function() cal_popup.visible = false end,
    }
    local function cal_place()
        awful.placement.top_right(cal_popup,
            { parent = awful.screen.focused(), margins = { top = 60, right = 20 } })
    end
    popup_closers.calendar = function()
        cal_popup.visible = false
        cal_timer:stop()
    end
    local function cal_toggle()
        if cal_popup.visible then
            cal_popup.visible = false
            cal_timer:stop()
        else
            close_other_popups("calendar")
            cal_popup:call_calendar(0)   -- always open on the current month
            cal_popup.visible = true
            cal_place()
            cal_timer:again()
        end
    end
    cal_popup:connect_signal("mouse::enter", function() cal_timer:stop() end)
    cal_popup:connect_signal("mouse::leave", function() cal_timer:again() end)

    clock_box:buttons(gears.table.join(
        awful.button({}, 1, cal_toggle),
        awful.button({}, 4, function() cal_popup:call_calendar(-1); cal_place() end),
        awful.button({}, 5, function() cal_popup:call_calendar(1);  cal_place() end)
    ))
    clock_box:connect_signal("mouse::enter", function() clock_box.bg = C.surface1 end)
    clock_box:connect_signal("mouse::leave", function() clock_box.bg = C.surface0 end)

    -- Systray. Fixed base size so xembed icons (Brave etc.) render crisp on
    -- the chip background instead of scaling to the bar height with a stale
    -- background pixmap (the "black square" artifact). bg comes from the
    -- theme so all arch-family themes stay in sync.
    local systray_widget = wibox.widget.systray()
    systray_widget:set_base_size(dpi(20))
    local tray = wibox.widget {
        {
            systray_widget,
            left = 8, right = 8, top = UI.pill_t, bottom = UI.pill_b,
            widget = wibox.container.margin,
        },
        bg     = beautiful.bg_systray or C.surface0,
        shape  = rounded(UI.radius_inner),
        widget = wibox.container.background,
    }

    -- Wibar (floating rounded bar — transparent outer, rounded inner)
    s.mywibox = awful.wibar({
        position = "top",
        screen   = s,
        height   = 54,
        bg       = "#00000000",
        fg       = C.text,
    })

    -- Right cluster: three grouped chips instead of seven identical ones.
    -- Intra-group spacing is 0 (hairlines do the separating), which also fixes
    -- a phantom gap: fixed.horizontal adds its spacing even for an invisible
    -- child, so hiding the updates pill used to leave 12px of dead air.
    upd_seg = wibox.widget {
        seg_divider(),
        segment(upd_box),
        layout = wibox.layout.fixed.horizontal,
    }
    upd_seg.visible = false   -- no pending updates until the poller says so

    local sys_group = group_chip {
        segment(cpu_box),
        seg_divider(),
        segment(mem_box),
        upd_seg,
        layout = wibox.layout.fixed.horizontal,
    }

    local session_row = {
        segment(make_volume_widget()),
        layout = wibox.layout.fixed.horizontal,
    }
    if BAT_PATH then
        table.insert(session_row, seg_divider())
        table.insert(session_row, segment(make_battery_widget()))
    end
    local session_group = group_chip(session_row)

    local right_widgets = {
        layout  = wibox.layout.fixed.horizontal,
        spacing = UI.group_gap,
        sys_group,
        session_group,
        {
            layout  = wibox.layout.fixed.horizontal,
            spacing = 6,
            tray,        -- own surface: xembed icons paint their own background
            clock_box,
        },
    }

    s.mywibox:setup {
        {
            {
                {
                    {
                        layout  = wibox.layout.fixed.horizontal,
                        spacing = 6,
                        { launcher, top = UI.chip_air, bottom = UI.chip_air,
                          widget = wibox.container.margin },
                        s.mytaglist,
                        s.mypromptbox,
                    },
                    s.mytasklist,
                    { right_widgets, top = UI.chip_air, bottom = UI.chip_air,
                      widget = wibox.container.margin },
                    layout = wibox.layout.align.horizontal,
                },
                left = 10, right = 10, top = 3, bottom = 3,
                widget = wibox.container.margin,
            },
            -- Glassy floating strip (blur is excluded for dock windows, so the
            -- alpha alone carries the frosted look over dark wallpapers).
            bg     = C.crust .. "d9",
            shape  = rounded(UI.radius_outer),
            widget = wibox.container.background,
        },
        left = 8, right = 8, top = 4, bottom = 4,
        widget = wibox.container.margin,
    }

    ---------------------------------------------------------------
    -- Desktop tiles (floating wiboxes pinned to the wallpaper)
    ---------------------------------------------------------------

    -- Helper: create a rounded tile wibox in the "desktop" layer.
    -- Border width/color/radius match picom's window rounding + awesome's
    -- border_normal so tiles and windows are visually consistent.
    -- Glass rim: a 1px highlight on the tile's top edge. Real glass catches
    -- light along its upper edge; this is the cue that separates "pane of
    -- glass" from "dark rectangle". Wrap the margined content, not the content
    -- itself, or the line floats 24px inside the tile.
    local function glass(margined)
        return wibox.widget {
            hline(C.text .. "24"),
            margined,
            layout = wibox.layout.fixed.vertical,
        }
    end

    local function make_tile(width, height)
        return wibox({
            screen            = s,
            width             = width,
            height            = height,
            visible           = true,
            ontop             = false,
            type              = "desktop",
            input_passthrough = true,
            bg                = C.mantle .. UI.tile_alpha, -- translucent via aRGB (requires picom)
            fg                = C.text,
            shape             = rounded(UI.radius_outer),
            border_width      = UI.tile_border,
            border_color      = C.mauve .. "66", -- neon edge, pairs with picom's glow
        })
    end

    ---------------------------------------------------------------
    -- HERO TILE — greeting + clock + date + weather (all-in-one)
    ---------------------------------------------------------------
    local user_name = os.getenv("USER") or "friend"
    -- Capitalize first letter of username nicely
    local display_name = user_name:sub(1,1):upper() .. user_name:sub(2)

    -- Escape any pango-significant characters in the quote text.
    local function pango_escape(s)
        return (s:gsub("[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
    end
    local hero_greeting = wibox.widget {
        markup = "<span font='" .. font(13) .. "' foreground='" .. C.mauve ..
                 "' style='italic'>\u{201c}" .. pango_escape(quote_text) .. "\u{201d}</span>",
        wrap   = "word",
        forced_width = 400,
        widget = wibox.widget.textbox,
    }
    local hero_greeting_sub = wibox.widget {
        markup = "<span font='" .. font(10) .. "' foreground='" .. C.overlay0 ..
                 "'>\u{2014} " .. pango_escape(quote_author) .. "</span>",
        widget = wibox.widget.textbox,
    }
    -- display_name kept for potential reuse elsewhere.
    local _ = display_name

    -- The one statement element. No weight= override: the font description
    -- already carries Light, and fighting it makes pango synthesise a face.
    local hero_clock = wibox.widget.textclock(
        "<span font='" .. (beautiful.font_display or font(48)) ..
        "' foreground='" .. C.text .. "'>%H:%M</span>", 30)

    local hero_date = wibox.widget.textclock(
        "<span foreground='" .. C.subtext1 .. "'>%A, %d %B %Y</span>", 3600)

    -- Weather line (inline with date). City is fixed — IP geolocation would
    -- silently follow VPN exits; this desk lives in Aarhus.
    local WEATHER_CITY = "Aarhus"
    local hero_weather = wibox.widget {
        markup = "<span foreground='" .. C.overlay0 .. "'>loading weather…</span>",
        widget = wibox.widget.textbox,
    }
    awful.widget.watch(
        [[sh -c "curl -s --max-time 5 'wttr.in/]] .. WEATHER_CITY .. [[?format=%t|%C' 2>/dev/null | head -c 80"]],
        1800,
        function(_, stdout)
            local s_ = (stdout or ""):gsub("\n", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if s_ == "" then
                hero_weather:set_markup("<span foreground='" .. C.overlay0 .. "'>weather offline</span>")
                return
            end
            local temp, cond = s_:match("^([^|]+)|(.+)$")
            if temp then
                temp = temp:gsub("^%+", "")
                hero_weather:set_markup(
                    "<span foreground='" .. C.yellow .. "'>\u{f185}</span>" ..
                    "<span foreground='" .. C.text .. "' weight='bold'>  " .. temp .. "</span>" ..
                    "<span foreground='" .. C.subtext1 .. "'>  · " .. cond .. "</span>" ..
                    "<span foreground='" .. C.overlay0 .. "'>  \u{f041} " .. WEATHER_CITY .. "</span>"
                )
            else
                hero_weather:set_markup("<span foreground='" .. C.text .. "'>" .. s_ .. "</span>")
            end
        end
    )

    -- Hero block: quote / clock / date / weather. Top half of the single
    -- dashboard tile assembled further down.
    local hero_block = wibox.widget {
        hero_greeting,
        { hero_greeting_sub, top = 2, widget = wibox.container.margin },
        { hero_clock,        top = 8, widget = wibox.container.margin },
        { hero_date,         top = 4, widget = wibox.container.margin },
        { hero_weather,      top = 2, widget = wibox.container.margin },
        layout = wibox.layout.fixed.vertical,
    }

    local function bar_widget(color)
        return wibox.widget {
            max_value        = 100,
            value            = 0,
            forced_height    = 10,
            forced_width     = 200,
            shape            = rounded(UI.radius_inner),
            bar_shape        = rounded(UI.radius_inner),
            background_color = C.surface0,
            color            = color,
            widget           = wibox.widget.progressbar,
        }
    end

    -- CPU/RAM bars + updates (merged into neofetch tile below)
    local dash_cpu_bar = bar_widget(C.peach)
    local dash_cpu_lbl = wibox.widget {
        markup = (beautiful.micro_markup and beautiful.micro_markup("cpu", C.subtext1))
            or "<span foreground='" .. C.subtext1 .. "'>CPU</span>",
        widget = wibox.widget.textbox,
        valign = "center",
        wrap = "none", ellipsize = "none",
    }
    subscribe_cpu(function(pct) dash_cpu_bar:set_value(pct) end)

    local dash_mem_bar = bar_widget(C.green)
    local dash_mem_lbl = wibox.widget {
        markup = (beautiful.micro_markup and beautiful.micro_markup("ram", C.subtext1))
            or "<span foreground='" .. C.subtext1 .. "'>RAM</span>",
        widget = wibox.widget.textbox,
        valign = "center",
        wrap = "none", ellipsize = "none",
    }
    subscribe_mem(function(pct) dash_mem_bar:set_value(pct) end)

    local dash_upd = wibox.widget {
        markup = "<span foreground='" .. C.green .. "'>\u{f058}  system up to date</span>",
        widget = wibox.widget.textbox,
    }
    subscribe_updates(function(n)
        if n > 0 then
            dash_upd:set_markup(
                "<span foreground='" .. C.yellow .. "'>\u{f019}  </span>" ..
                "<span foreground='" .. C.red .. "' weight='bold'>" .. n .. "</span>" ..
                "<span foreground='" .. C.subtext1 .. "'> updates available</span>")
        else
            dash_upd:set_markup(
                "<span foreground='" .. C.green .. "'>\u{f058}  system up to date</span>")
        end
    end)

    -- Neofetch-style tile (Arch logo + system info)
    local TILE_W = 560
    local NEO_W = TILE_W
    -- The glyph needs a box comfortably larger than its point size or the
    -- Arch logo's ascender gets clipped (font 110 in a 160px box did).
    local NEO_LOGO_W = dpi(150)
    -- key cell + value constraint keep the columns aligned and stop long
    -- values (the CPU model) from blowing past the tile edge.
    local NEO_KEY_W = dpi(78)
    local NEO_VAL_W = NEO_W - 2 * 24 - NEO_LOGO_W - 20 - NEO_KEY_W - 10
    local arch_logo = wibox.widget {
        {
            markup = "<span font='" .. font(88) .. "' foreground='" .. C.mauve ..
                     "'>\u{f303}</span>",
            widget = wibox.widget.textbox,
            align  = "center",
            valign = "center",
        },
        forced_width  = NEO_LOGO_W,
        forced_height = NEO_LOGO_W,
        widget = wibox.container.background,
    }
    -- Returns the row and its value textbox (for rows that update, e.g. uptime).
    local function info_row(key, val, key_color)
        local val_tb = wibox.widget {
            markup    = "<span foreground='" .. C.text .. "'>" .. (val or "") .. "</span>",
            widget    = wibox.widget.textbox,
            ellipsize = "end",
        }
        local micro = beautiful.micro_markup
        local row = wibox.widget {
            {
                {
                    markup = micro and micro(key, key_color or C.mauve)
                        or ("<span foreground='" .. (key_color or C.mauve) ..
                            "' weight='bold'>" .. key .. "</span>"),
                    widget = wibox.widget.textbox,
                    wrap   = "none",
                    ellipsize = "none",
                },
                forced_width = NEO_KEY_W,
                widget = wibox.container.background,
            },
            {
                {
                    val_tb,
                    width    = NEO_VAL_W,
                    strategy = "max",
                    widget   = wibox.container.constraint,
                },
                left = 10,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.horizontal,
        }
        return row, val_tb
    end

    local uptime_row, uptime_row_txt = info_row("uptime", "…")
    local function refresh_uptime()
        awful.spawn.easy_async("uptime -p", function(out)
            local s_ = (out or ""):gsub("\n", ""):gsub("^up ", "")
            s_ = s_:gsub(" hours?", "h"):gsub(" minutes?", "m"):gsub(",", "")
            uptime_row_txt:set_markup("<span foreground='" .. C.text .. "'>" .. s_ .. "</span>")
        end)
    end
    refresh_uptime()
    gears.timer { timeout = 60, autostart = true, callback = refresh_uptime }

    local divider = function()
        return wibox.widget {
            hline(C.surface0),
            top = 8, bottom = 8,
            widget = wibox.container.margin,
        }
    end

    -- System stats strip (CPU / RAM / updates) — merged into the neofetch tile
    local function dash_row(lbl_widget, bar)
        return wibox.widget {
            {
                { lbl_widget, forced_width = 40, widget = wibox.container.background },
                { bar, left = 10, widget = wibox.container.margin },
                layout = wibox.layout.fixed.horizontal,
            },
            top = 3, bottom = 3,
            widget = wibox.container.margin,
        }
    end

    local user_host_row = wibox.widget {
        markup = "<span font='" .. (beautiful.font_h2 or font(13)) ..
            "' foreground='" .. C.peach .. "'>" ..
            (sys_info.user_host:match("^([^@]+)") or "user") ..
            "</span><span font='" .. (beautiful.font_h2 or font(13)) ..
            "' foreground='" .. C.overlay0 .. "'>@</span>" ..
            "<span font='" .. (beautiful.font_h2 or font(13)) ..
            "' foreground='" .. C.blue .. "'>" ..
            (sys_info.user_host:match("@(.+)$") or "host") .. "</span>",
        widget = wibox.widget.textbox,
    }

    local neo_info = wibox.widget {
        user_host_row,
        divider(),
        (info_row("os",       sys_info.os_name)),
        (info_row("kernel",   sys_info.kernel)),
        (info_row("wm",       sys_info.wm)),
        (info_row("shell",    sys_info.shell)),
        (info_row("cpu",      sys_info.cpu ~= "" and sys_info.cpu or "unknown")),
        (info_row("gpu",      sys_info.gpu ~= "" and sys_info.gpu or "unknown")),
        (info_row("memory",   sys_info.mem)),
        (info_row("packages", sys_info.packages .. " (pacman)")),
        uptime_row,
        divider(),
        dash_row(dash_cpu_lbl, dash_cpu_bar),
        dash_row(dash_mem_lbl, dash_mem_bar),
        { dash_upd, top = 6, widget = wibox.container.margin },
        spacing = 2,
        layout  = wibox.layout.fixed.vertical,
    }

    -- Dashboard tile: hero block over the system info. FIXED height forever —
    -- the visualizer used to live here and swung this tile's bottom edge 63px
    -- whenever audio started, which broke its alignment with the caption.
    -- 470 clipped the last info rows once gpu/memory were added: the content
    -- is ~560 tall (hero 200 + divider 29 + 9 info rows + 2 bars + updates).
    local TILE_H    = 588
    local dash_tile = make_tile(TILE_W, TILE_H)
    dash_tile:set_widget(glass {
        {
            hero_block,
            {
                hline(C.surface0),
                top = 14, bottom = 14,
                widget = wibox.container.margin,
            },
            {
                { arch_logo, widget = wibox.container.place, valign = "top" },
                { neo_info,  widget = wibox.container.place, valign = "top" },
                spacing = 18,
                layout  = wibox.layout.fixed.horizontal,
            },
            layout = wibox.layout.fixed.vertical,
        },
        margins = UI.tile_margin,
        widget  = wibox.container.margin,
    })

    ---------------------------------------------------------------
    -- Media panel (primary screen only) — anchors the bottom-right
    -- corner that the composition was missing. Always present with a
    -- fixed size: content degrades, geometry never moves. Holds the
    -- cava visualizer, so the bars work with zero extra packages.
    ---------------------------------------------------------------
    local media_tile, set_cava_active, poll_media, cava_smooth =
        nil, function() end, function() end, function() end
    -- Right-hand column, primary screen only. Declared out here so
    -- place_tiles() can reach them; assigned inside the primary block.
    local cal_tile, stats_tile = nil, nil

    if s == screen.primary then
        local CAVA_BARS = 44   -- must match cava/.config/cava/config
        local NP_W      = math.min(720, math.max(420, s.geometry.width - TILE_W - 3 * DESK.gutter))
        local NP_H      = 232   -- 48 margins + 14 eyebrow + 50 title row + 16 gaps + 104 bars
        local NP_ART    = 44   -- small badge beside the title, not a slab
        local cava_live = false
        local cava_values = {}

        local CAVA_H = 104
        local cava_widget = wibox.widget.base.make_widget()
        -- Report our own height: returning the available height made the widget
        -- absorb all the panel's slack and pushed the bars to the very bottom.
        function cava_widget:fit(_, w, _) return w, CAVA_H end
        function cava_widget:draw(_, cr, w, h)
            -- Mirrored around the centre line: reads as a real audio meter
            -- rather than a bar chart, and the resting state degrades to a
            -- clean dotted rule instead of a row of stubs.
            local gap   = 3
            local pitch = math.floor(w / CAVA_BARS)
            local bw    = pitch - gap
            if bw <= 0 then return end
            local x0  = math.floor((w - (CAVA_BARS * pitch - gap)) / 2)
            local mid = h / 2
            for i = 1, CAVA_BARS do
                local v  = math.min(1, (cava_values[i] or 0) / 100)
                local bh = math.max(2, v * (h - 4))
                -- Brighter with amplitude, so loud bands glow and quiet ones
                -- recede: one accent that moves instead of a flat pink block.
                local a = cava_live and (0.40 + 0.60 * v) or 0.34
                cr:set_source(gears.color(C.mauve .. string.format("%02x", math.floor(a * 255))))
                cr:save()
                cr:translate(x0 + (i - 1) * pitch, mid - bh / 2)
                gears.shape.rounded_rect(cr, bw, bh, math.min(bw / 2, 3))
                cr:restore()
                cr:fill()
            end
        end

        -- Resting state is free: every value at 0 draws 44 evenly spaced 2px
        -- dashes, which reads as "a waveform at rest" rather than a gap.
        set_cava_active = function(v)
            cava_live = v
            if not v then for i = 1, CAVA_BARS do cava_values[i] = 0 end end
            cava_widget:emit_signal("widget::redraw_needed")
        end
        cava_smooth = function(line)
            local i = 1
            for val in line:gmatch("%d+") do
                local target = tonumber(val) or 0
                local prev   = cava_values[i] or 0
                -- rise fast, fall slow: raw frames jitter at 30fps
                cava_values[i] = prev + (target - prev) * ((target > prev) and 0.50 or 0.14)
                i = i + 1
            end
            cava_widget:emit_signal("widget::redraw_needed")
        end

        local BF = function(k, fb) return beautiful[k] or fb end
        local media_sigil = wibox.widget {
            markup = "<span font='" .. font(17) .. "' foreground='" .. C.overlay0 .. "'>\u{f001}</span>",
            align = "center", valign = "center", widget = wibox.widget.textbox,
        }
        local media_art = wibox.widget {
            image = nil, resize = true, visible = false,
            clip_shape = rounded(UI.radius_inner), widget = wibox.widget.imagebox,
        }
        local media_sigil_box = wibox.widget {
            { media_sigil, media_art, layout = wibox.layout.stack },
            forced_width  = NP_ART,
            forced_height = NP_ART,   -- height governor: rows may hide without resizing the panel
            bg            = C.surface0,
            shape         = rounded(UI.radius_inner),
            widget        = wibox.container.background,
        }

        -- ellipsize="none": pango's letter_spacing is not accounted for in the
        -- textbox's fit, so with the default "end" the label truncated itself
        -- ("AUDI…") despite having hundreds of spare pixels.
        local media_eyebrow_l = wibox.widget {
            ellipsize = "none", wrap = "none", widget = wibox.widget.textbox }
        local media_eyebrow_r = wibox.widget {
            align = "right", ellipsize = "none", wrap = "none",
            widget = wibox.widget.textbox }
        local media_title     = wibox.widget { ellipsize = "end", widget = wibox.widget.textbox }
        local media_sub       = wibox.widget { ellipsize = "end", widget = wibox.widget.textbox }
        local media_pos       = wibox.widget { widget = wibox.widget.textbox }
        local media_len       = wibox.widget { align = "right", widget = wibox.widget.textbox }
        local media_prog = wibox.widget {
            max_value = 100, value = 0, forced_height = 4,
            shape = rounded(UI.radius_inner), bar_shape = rounded(UI.radius_inner),
            background_color = C.surface0, color = C.mauve,
            widget = wibox.widget.progressbar,
        }
        local media_prog_row = wibox.widget {
            { media_pos, forced_width = 38, widget = wibox.container.background },
            { media_prog, left = 8, right = 8, widget = wibox.container.margin },
            { media_len, forced_width = 38, widget = wibox.container.background },
            visible = false,
            layout  = wibox.layout.align.horizontal,
        }

        local micro = beautiful.micro_markup
        local function eyebrow(text, col)
            return micro and micro(text, col)
                or ("<span font='" .. font(8) .. "' foreground='" .. col .. "'>" ..
                    tostring(text):upper() .. "</span>")
        end

        local media = { avail = true, status = nil, player = nil, artist = nil,
                        title = nil, album = nil, len = 0, pos = 0, pos_at = 0 }

        local function mmss(sec)
            sec = math.max(0, math.floor(sec or 0))
            return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
        end

        -- Idle content is the volume state: always true, always useful, and it
        -- reframes the panel as "audio" rather than "an empty now-playing box".
        -- "playerctl missing" is deliberately indistinguishable from "nothing
        -- playing" — a missing dependency must not look like breakage.
        local function render_media()
            local playing = (media.status == "Playing")
            local paused  = (media.status == "Paused")
            if playing or paused then
                media_eyebrow_l:set_markup(eyebrow(playing and "now playing" or "paused",
                                                   playing and C.mauve or C.yellow))
                media_eyebrow_r:set_markup(eyebrow(media.player or "", C.overlay0))
                media_title:set_markup("<span font='" .. BF("font_h1", font(15)) ..
                    "' foreground='" .. (playing and C.text or C.subtext1) .. "'>" ..
                    pango_escape(media.title or "unknown track") .. "</span>")
                local sub = "<span font='" .. BF("font_body", font(10)) .. "' foreground='" ..
                    (playing and C.mauve or C.overlay0) .. "'>" ..
                    pango_escape(media.artist or "unknown artist") .. "</span>"
                if media.album and media.album ~= "" then
                    sub = sub .. "<span font='" .. BF("font_body", font(10)) ..
                        "' foreground='" .. C.overlay0 .. "'>  ·  " ..
                        pango_escape(media.album) .. "</span>"
                end
                media_sub:set_markup(sub)
                if media.len > 0 then
                    local pos = math.min(media.len, media.pos + (os.time() - media.pos_at))
                    media_prog_row.visible = true
                    media_prog.value = pos / media.len * 100
                    media_pos:set_markup("<span font='" .. BF("font_label", font(9)) ..
                        "' foreground='" .. C.subtext1 .. "'>" .. mmss(pos) .. "</span>")
                    media_len:set_markup("<span font='" .. BF("font_label", font(9)) ..
                        "' foreground='" .. C.overlay0 .. "'>" .. mmss(media.len) .. "</span>")
                else
                    media_prog_row.visible = false
                end
            else
                media_eyebrow_l:set_markup(eyebrow("audio", C.overlay0))
                media_eyebrow_r:set_markup(eyebrow("idle", C.overlay0))
                local muted = vol_state.muted
                media_title:set_markup("<span font='" .. BF("font_h1", font(15)) ..
                    "' foreground='" .. (muted and C.red or C.subtext1) .. "'>" ..
                    (muted and "\u{f026}  muted" or ("\u{f028}  " .. vol_state.vol .. "%")) .. "</span>")
                media_sub:set_markup("<span font='" .. BF("font_body", font(10)) ..
                    "' foreground='" .. C.overlay0 .. "'>system output</span>")
                media_prog_row.visible = false
            end
        end

        media_tile = make_tile(NP_W, NP_H)
        media_tile:set_widget(glass {
            {
                {
                    media_eyebrow_l,
                    media_eyebrow_r,
                    layout = wibox.layout.flex.horizontal,
                },
                {
                    {
                        { media_sigil_box, right = 14, widget = wibox.container.margin },
                        {
                            media_title,
                            { media_sub, top = 1, widget = wibox.container.margin },
                            layout = wibox.layout.fixed.vertical,
                        },
                        layout = wibox.layout.align.horizontal,
                    },
                    top = 6,
                    widget = wibox.container.margin,
                },
                { media_prog_row, top = 6, widget = wibox.container.margin },
                { cava_widget, top = 10, widget = wibox.container.margin },
                layout = wibox.layout.fixed.vertical,
            },
            margins = UI.tile_margin,
            widget  = wibox.container.margin,
        })

        -- playerctl is optional. Exit 9 == not installed: stop polling for the
        -- session and stay in the idle state rather than nagging.
        local PL_FMT = "{{status}}\t{{playerName}}\t{{artist}}\t{{title}}\t{{album}}\t{{mpris:length}}\t{{position}}"
        local PL_CMD = "sh -c \"command -v playerctl >/dev/null 2>&1 || exit 9; " ..
                       "playerctl -a metadata --format '" .. PL_FMT .. "' 2>/dev/null\""

        -- Keeps EMPTY fields: a plain gmatch over non-tab runs silently shifts
        -- every later column when e.g. album is blank.
        local function tsplit(line)
            local f = {}
            for v in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
            return f
        end

        poll_media = function()
            if not media.avail then return end
            awful.spawn.easy_async(PL_CMD, function(stdout, _, _, code)
                if code == 9 then media.avail = false; render_media(); return end
                local pick
                for line in (stdout or ""):gmatch("[^\r\n]+") do
                    local f = tsplit(line)
                    if f[1] == "Playing" then pick = f; break end
                    pick = pick or f
                end
                if not pick or not pick[1] or pick[1] == "" then
                    media.status = nil
                else
                    media.status = pick[1]
                    media.player = pick[2]
                    media.artist = pick[3]
                    media.title  = pick[4]
                    media.album  = pick[5]
                    media.len    = (tonumber(pick[6]) or 0) / 1000000   -- µs -> s
                    media.pos    = (tonumber(pick[7]) or 0) / 1000000
                    media.pos_at = os.time()
                end
                render_media()
            end)
        end

        -- Advance the elapsed time locally; never poll for position.
        gears.timer {
            timeout = 1, autostart = true,
            callback = function()
                if media.status == "Playing" and media.len > 0 then render_media() end
            end,
        }
        subscribe_volume(function()
            if media.status ~= "Playing" then render_media() end
        end)
        render_media()

        -----------------------------------------------------------
        -- SYSTEM STRIP — storage + network, right-aligned directly
        -- above the media panel so the two share both side rails.
        -- Same width as the media panel; deliberately short, it is a
        -- readout, not a tile.
        -----------------------------------------------------------
        local STATS_H = 116

        local function hbytes(n)
            local u, i = { "B", "K", "M", "G", "T" }, 1
            while n >= 1024 and i < #u do n = n / 1024; i = i + 1 end
            return string.format((n < 10 and i > 1) and "%.1f%s" or "%.0f%s", n, u[i])
        end

        -- label | bar | value. The value cell is a FIXED width: sized to fit,
        -- the two bars in a column would end at different x for "44G / 49G"
        -- vs "283G / 866G" and the strip would look broken.
        local function meter_row(label, colour)
            local lbl = wibox.widget {
                markup = "<span font='" .. font(9) .. "' foreground='" ..
                         C.subtext1 .. "'>" .. label .. "</span>",
                widget = wibox.widget.textbox,
                valign = "center", wrap = "none", ellipsize = "none",
            }
            local bar = bar_widget(colour)
            bar.forced_height = 8
            bar.forced_width  = nil   -- the align layout's centre slot governs
            local val = wibox.widget {
                widget = wibox.widget.textbox,
                align  = "right", valign = "center",
                wrap   = "none", ellipsize = "none",
            }
            return {
                lbl = lbl, bar = bar, val = val,
                w = wibox.widget {
                    { lbl, forced_width = 54, widget = wibox.container.background },
                    { bar, left = 4, right = 12, widget = wibox.container.margin },
                    { val, forced_width = 96, widget = wibox.container.background },
                    forced_height = 22,
                    layout = wibox.layout.align.horizontal,
                },
            }
        end

        local disk_rows = { meter_row("/", C.blue), meter_row("/home", C.teal) }
        local net_rows  = { meter_row("\u{f01a}  down", C.green),
                            meter_row("\u{f01b}  up",   C.peach) }
        -- Throughput has no "capacity", so an opaque track reads as an empty
        -- input box. The disk rows keep theirs: there, unfilled IS free space.
        for _, r in ipairs(net_rows) do r.bar.background_color = C.surface0 .. "55" end

        local disk_eyebrow = wibox.widget {
            markup = eyebrow("storage", C.overlay0),
            widget = wibox.widget.textbox, wrap = "none", ellipsize = "none",
        }
        local net_eyebrow = wibox.widget {
            markup = eyebrow("network", C.overlay0),
            widget = wibox.widget.textbox, wrap = "none", ellipsize = "none",
        }

        local function stat_col(eb, rows)
            return wibox.widget {
                { eb, bottom = 6, widget = wibox.container.margin },
                rows[1].w,
                rows[2].w,
                layout = wibox.layout.fixed.vertical,
            }
        end

        -- Halves need explicit widths: fixed.horizontal would size each column
        -- to its content and the divider would drift with the longest value.
        local STATS_COL_W = math.floor((NP_W - 2 * UI.tile_margin - 45) / 2)
        local function half(w)
            return wibox.widget {
                w, width = STATS_COL_W, strategy = "exact",
                widget = wibox.container.constraint,
            }
        end

        stats_tile = make_tile(NP_W, STATS_H)
        stats_tile:set_widget(glass {
            {
                { half(stat_col(disk_eyebrow, disk_rows)), right = 22,
                  widget = wibox.container.margin },
                vline(C.surface1, STATS_H - 2 * UI.tile_margin - 6),
                { half(stat_col(net_eyebrow, net_rows)), left = 22,
                  widget = wibox.container.margin },
                layout = wibox.layout.fixed.horizontal,
            },
            margins = UI.tile_margin,
            widget  = wibox.container.margin,
        })

        -- Storage. df once every two minutes: mount usage does not move fast
        -- enough to justify a shorter interval, and this spawns a process.
        local DISK_LABELS = { "/", "/home" }
        local function poll_disk()
            -- pcent comes from df rather than used/size: the two disagree by
            -- several points on ext4 (reserved-for-root blocks), and the number
            -- people cross-check against is the one df prints.
            awful.spawn.easy_async_with_shell(
                "df -B1 --output=target,used,size,pcent / /home 2>/dev/null | tail -n +2",
                function(stdout)
                    local seen, i = {}, 0
                    for line in (stdout or ""):gmatch("[^\r\n]+") do
                        local target, used, size, pcent =
                            line:match("^%s*(%S+)%s+(%d+)%s+(%d+)%s+(%d+)%%")
                        -- /home on the same filesystem as / makes df print "/"
                        -- twice; showing the same numbers on both rows would
                        -- read as a bug, so drop the duplicate row instead.
                        if target and not seen[target] then
                            seen[target] = true
                            i = i + 1
                            local r = disk_rows[i]
                            if r then
                                used, size = tonumber(used), tonumber(size)
                                local pct = tonumber(pcent)
                                    or (size > 0 and (used / size * 100)) or 0
                                r.w.visible = true
                                r.lbl:set_markup("<span font='" .. font(9) ..
                                    "' foreground='" .. C.subtext1 .. "'>" ..
                                    (DISK_LABELS[i] or target) .. "</span>")
                                r.bar:set_value(pct)
                                -- >90% full is the one storage fact worth
                                -- shouting about; recolour the bar, not just
                                -- the text, so it is visible at a glance.
                                r.bar.color = pct >= 90 and C.red
                                    or (pct >= 75 and C.yellow)
                                    or (i == 1 and C.blue or C.teal)
                                r.val:set_markup("<span font='" .. font(9) ..
                                    "' foreground='" ..
                                    (pct >= 90 and C.red or C.overlay0) .. "'>" ..
                                    hbytes(used) .. " / " .. hbytes(size) .. "</span>")
                            end
                        end
                    end
                    for j = i + 1, #disk_rows do disk_rows[j].w.visible = false end
                end)
        end
        poll_disk()
        gears.timer { timeout = 120, autostart = true, callback = poll_disk }

        -- Network. Both readings are procfs, so this stays in-process — no
        -- shell every two seconds. The interface is resolved per tick from the
        -- default route, so wifi/VPN switches follow without a restart.
        local function default_iface()
            local f = io.open("/proc/net/route", "r")
            if not f then return nil end
            local iface
            for line in f:lines() do
                local name, dest = line:match("^(%S+)%s+(%S+)")
                if name and name ~= "Iface" and dest == "00000000" then
                    iface = name
                    break
                end
            end
            f:close()
            return iface
        end

        local function iface_bytes(iface)
            local f = io.open("/proc/net/dev", "r")
            if not f then return nil end
            local rx, tx
            for line in f:lines() do
                local name, rest = line:match("^%s*([^:%s]+):%s*(.+)$")
                if name == iface then
                    local fld = {}
                    for v in rest:gmatch("%S+") do fld[#fld + 1] = v end
                    rx, tx = tonumber(fld[1]), tonumber(fld[9])
                    break
                end
            end
            f:close()
            return rx, tx
        end

        local NET_INTERVAL = 2
        local net_prev_rx, net_prev_tx, net_prev_if
        -- Throughput has no natural full-scale, so the bars are scaled to the
        -- session peak (floor 256 KB/s). Self-calibrating: a 1 Gbit transfer
        -- and an idle link both read sensibly.
        local net_peak = 256 * 1024
        local function poll_net()
            local iface = default_iface()
            if not iface then
                net_eyebrow:set_markup(eyebrow("network · offline", C.red))
                for _, r in ipairs(net_rows) do
                    r.bar:set_value(0)
                    r.val:set_markup("<span font='" .. font(9) .. "' foreground='" ..
                        C.overlay0 .. "'>—</span>")
                end
                net_prev_rx, net_prev_tx, net_prev_if = nil, nil, nil
                return
            end
            net_eyebrow:set_markup(eyebrow("network · " .. iface, C.overlay0))
            local rx, tx = iface_bytes(iface)
            if not rx then return end
            -- A different interface (or a counter reset) makes the delta
            -- meaningless: re-seed and show nothing for one tick.
            if iface ~= net_prev_if or not net_prev_rx
                or rx < net_prev_rx or tx < net_prev_tx then
                net_prev_rx, net_prev_tx, net_prev_if = rx, tx, iface
                return
            end
            local drx = (rx - net_prev_rx) / NET_INTERVAL
            local dtx = (tx - net_prev_tx) / NET_INTERVAL
            net_prev_rx, net_prev_tx = rx, tx
            net_peak = math.max(net_peak, drx, dtx)
            local rates = { drx, dtx }
            for i, r in ipairs(net_rows) do
                r.bar:set_value(rates[i] / net_peak * 100)
                r.val:set_markup("<span font='" .. font(9) .. "' foreground='" ..
                    (rates[i] > 1024 and C.subtext1 or C.overlay0) .. "'>" ..
                    hbytes(rates[i]) .. "/s</span>")
            end
        end
        poll_net()
        gears.timer { timeout = NET_INTERVAL, autostart = true, callback = poll_net }

        -----------------------------------------------------------
        -- CALENDAR COLUMN — top-right anchor: month grid over the
        -- next seven days. Narrow on purpose; it holds the right
        -- edge without closing the open centre where the band
        -- photo's subject sits.
        -----------------------------------------------------------
        local CAL_W = 340
        -- Height is whatever is left once the strip and the media panel have
        -- taken their share of the right column, so all four gaps stay equal.
        local CAL_H = math.max(420, math.min(760,
            s.workarea.height - 4 * DESK.gutter - STATS_H - NP_H))

        local cal_month = wibox.widget {
            widget = wibox.widget.textbox, wrap = "none", ellipsize = "none",
        }
        local cal_year = wibox.widget {
            widget = wibox.widget.textbox, align = "right", valign = "bottom",
            wrap = "none", ellipsize = "none",
        }

        -- 42 cells built once and rewritten in place. Rebuilding the tree each
        -- midnight would drop 42 layouts on the floor every day.
        local CAL_CELLS = 42
        local cal_cells = {}
        for i = 1, CAL_CELLS do
            local tb = wibox.widget {
                align = "center", valign = "center",
                widget = wibox.widget.textbox,
            }
            local bg = wibox.widget {
                tb,
                forced_height = 30,
                shape         = rounded(UI.radius_inner),
                widget        = wibox.container.background,
            }
            cal_cells[i] = {
                tb = tb, bg = bg,
                w  = wibox.widget { bg, margins = 2, widget = wibox.container.margin },
            }
        end

        local cal_grid = wibox.widget { spacing = 0, layout = wibox.layout.fixed.vertical }
        for row = 0, 5 do
            local line = wibox.widget { layout = wibox.layout.flex.horizontal }
            for col = 1, 7 do line:add(cal_cells[row * 7 + col].w) end
            cal_grid:add(line)
        end

        -- Monday-first, two letters: locale %a is three and would not fit a
        -- 41px cell at this size.
        local WD = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }
        local cal_head = wibox.widget { layout = wibox.layout.flex.horizontal }
        for i, name in ipairs(WD) do
            cal_head:add(wibox.widget {
                markup = "<span font='" .. font(8) .. "' foreground='" ..
                         (i >= 6 and C.overlay0 or C.blue) .. "'>" .. name .. "</span>",
                align = "center", widget = wibox.widget.textbox,
                wrap = "none", ellipsize = "none",
            })
        end

        local cal_days_eyebrow = wibox.widget {
            markup = eyebrow("next 7 days", C.overlay0),
            widget = wibox.widget.textbox, wrap = "none", ellipsize = "none",
        }
        local cal_day_rows = {}
        for i = 1, 7 do
            local wd  = wibox.widget { widget = wibox.widget.textbox, valign = "center",
                                       wrap = "none", ellipsize = "none" }
            local dt  = wibox.widget { widget = wibox.widget.textbox, valign = "center",
                                       wrap = "none", ellipsize = "none" }
            local rel = wibox.widget { widget = wibox.widget.textbox, valign = "center",
                                       align = "right", wrap = "none", ellipsize = "none" }
            cal_day_rows[i] = {
                wd = wd, dt = dt, rel = rel,
                w  = wibox.widget {
                    { wd, forced_width = 42, widget = wibox.container.background },
                    { dt, widget = wibox.container.background },
                    { rel, widget = wibox.container.background },
                    forced_height = 26,
                    layout = wibox.layout.align.horizontal,
                },
            }
        end

        local function refresh_calendar()
            local now = os.date("*t")
            cal_month:set_markup("<span font='" .. BF("font_h1", font(20)) ..
                "' foreground='" .. C.text .. "'>" .. os.date("%B") .. "</span>")
            cal_year:set_markup("<span font='" .. BF("font_body", font(10)) ..
                "' foreground='" .. C.overlay0 .. "'>" ..
                os.date("%Y  ·  w%V") .. "</span>")

            -- wday is 1=Sunday; this rotates it to a Monday-first column index
            -- and yields the number of blank leading cells.
            local first = os.date("*t", os.time {
                year = now.year, month = now.month, day = 1, hour = 12 })
            local lead  = (first.wday + 5) % 7
            -- day 0 of next month == last day of this one (mktime normalises
            -- month 13, so December needs no special case).
            local ndays = os.date("*t", os.time {
                year = now.year, month = now.month + 1, day = 0, hour = 12 }).day

            for i = 1, CAL_CELLS do
                local c, d = cal_cells[i], i - lead
                if d < 1 or d > ndays then
                    c.tb:set_markup("")
                    c.bg.bg = nil
                elseif d == now.day then
                    c.tb:set_markup("<span font='" .. font(11) .. "' foreground='" ..
                        C.crust .. "' weight='bold'>" .. d .. "</span>")
                    c.bg.bg = C.mauve
                else
                    local weekend = ((i - 1) % 7) >= 5
                    c.tb:set_markup("<span font='" .. font(11) .. "' foreground='" ..
                        (d < now.day and C.overlay0
                         or (weekend and C.subtext1 or C.text)) .. "'>" .. d .. "</span>")
                    c.bg.bg = nil
                end
            end

            for i = 1, 7 do
                -- day + n overflows the month on purpose: mktime normalises it,
                -- which is what makes the list cross month and year ends.
                local t = os.time { year = now.year, month = now.month,
                                    day = now.day + (i - 1), hour = 12 }
                local d       = os.date("*t", t)
                local today   = (i == 1)
                local weekend = (d.wday == 1 or d.wday == 7)
                local r = cal_day_rows[i]
                r.wd:set_markup("<span font='" .. font(10) .. "' foreground='" ..
                    (today and C.mauve or (weekend and C.overlay0 or C.subtext1)) ..
                    "'>" .. os.date("%a", t) .. "</span>")
                r.dt:set_markup("<span font='" .. font(10) .. "' foreground='" ..
                    (today and C.text or C.subtext1) .. "'>" ..
                    os.date("%d %b", t) .. "</span>")
                r.rel:set_markup("<span font='" .. font(9) .. "' foreground='" ..
                    (today and C.mauve or C.overlay0) .. "'>" ..
                    (today and "today" or (i == 2 and "tomorrow")
                     or ("in " .. (i - 1) .. " days")) .. "</span>")
            end
        end

        -- align.vertical, EXACTLY three children: grid at the top, day list
        -- pinned to the bottom, an empty expander between them. A fixed.vertical
        -- would leave the height slack as extra padding under the last row, so
        -- the tile looked bottom-heavy at every resolution but one.
        cal_tile = make_tile(CAL_W, CAL_H)
        cal_tile:set_widget(glass {
            {
                {
                    {
                        cal_month,
                        cal_year,
                        layout = wibox.layout.align.horizontal,
                    },
                    { cal_head, top = 12, bottom = 4, widget = wibox.container.margin },
                    cal_grid,
                    layout = wibox.layout.fixed.vertical,
                },
                { widget = wibox.container.background },   -- expander
                {
                    { hline(C.surface0), bottom = 12, widget = wibox.container.margin },
                    cal_days_eyebrow,
                    {
                        {
                            cal_day_rows[1].w, cal_day_rows[2].w, cal_day_rows[3].w,
                            cal_day_rows[4].w, cal_day_rows[5].w, cal_day_rows[6].w,
                            cal_day_rows[7].w,
                            layout = wibox.layout.fixed.vertical,
                        },
                        top = 6, widget = wibox.container.margin,
                    },
                    layout = wibox.layout.fixed.vertical,
                },
                -- forced_height is what makes the bottom anchor work at all:
                -- glass() stacks in a fixed.vertical, which hands this layout
                -- its CONTENT height, so without it there is no slack for the
                -- expander to take and the day list floats mid-tile.
                forced_height = CAL_H - 2 * UI.tile_margin - 1,
                layout = wibox.layout.align.vertical,
            },
            margins = UI.tile_margin,
            widget  = wibox.container.margin,
        })
        refresh_calendar()
        -- One cheap tick a minute, rewriting only when the date actually rolls
        -- over. A "sleep until midnight" timer does not survive suspend.
        local cal_day_key = os.date("%Y-%j")
        gears.timer {
            timeout = 60, autostart = true,
            callback = function()
                local key = os.date("%Y-%j")
                if key ~= cal_day_key then
                    cal_day_key = key
                    refresh_calendar()
                end
            end,
        }
    end

    ---------------------------------------------------------------
    -- Tile placement — three anchors on one 24px gutter grid:
    --   dash_tile   top-left      (primary weight)
    --   media_tile  bottom-right  (secondary, primary screen only)
    --   cap_box     bottom-left   (tertiary, placed by the wallpaper block)
    -- The open centre/right is deliberate: that is where the band photo's
    -- subject lives, and it counterweights the dash tile.
    ---------------------------------------------------------------
    local function place_tiles()
        local wa = s.workarea      -- already excludes the wibar strut
        local g  = DESK.gutter
        dash_tile.x = wa.x + g
        dash_tile.y = wa.y + g

        if not media_tile then return end
        media_tile.x = wa.x + wa.width  - g - media_tile.width
        media_tile.y = wa.y + wa.height - g - media_tile.height

        -- Small screens: clamp, then move the panel off the dash tile.
        if media_tile.x < wa.x + g then media_tile.x = wa.x + g end
        if media_tile.y < wa.y + g then media_tile.y = wa.y + g end
        local dash_r = dash_tile.x + dash_tile.width
        local dash_b = dash_tile.y + dash_tile.height
        if media_tile.x < dash_r + g and media_tile.y < dash_b + g then
            if (wa.y + wa.height - g) - (dash_b + g) >= media_tile.height then
                media_tile.y = dash_b + g
            else
                media_tile.x = dash_r + g
            end
        end

        -- Right column: calendar at the top edge, system strip stacked on the
        -- media panel. All three share the right rail, so the column reads as
        -- one element regardless of the differing widths.
        if cal_tile then
            cal_tile.x = wa.x + wa.width - g - cal_tile.width
            cal_tile.y = wa.y + g
        end
        if stats_tile then
            stats_tile.x = wa.x + wa.width - g - stats_tile.width
            stats_tile.y = media_tile.y - g - stats_tile.height
            -- Anchored to the panel above it, so on a short screen it would
            -- ride off the top: fall back to hiding rather than overlapping.
            stats_tile.visible = stats_tile.y >= wa.y + g
        end
    end
    place_tiles()
    s:connect_signal("property::geometry", place_tiles)

    ---------------------------------------------------------------
    -- Music visualizer — drives the cava strip inside the dashboard
    -- tile. Resource-frugal: the cava process only runs while audio
    -- is actually playing AND the desktop is visible (no maximized
    -- or fullscreen client on the selected tag).
    ---------------------------------------------------------------
    if s == screen.primary then
        -- Process lifecycle: track OUR pid (never pkill blindly — the same
        -- self-match trap as the wallpaper fetch guard).
        local cava_pid = nil
        local cava_starting = false   -- latch: two spawns in flight = duplicate bars
        local audio_playing = false
        local cava_error_shown = false -- notify once per session, not per retry

        local function desktop_visible()
            local t = s.selected_tag
            if not t then return false end
            for _, c in ipairs(t:clients()) do
                if not c.minimized and (c.maximized or c.fullscreen) then
                    return false
                end
            end
            return true
        end

        -- Kill strays SYNCHRONOUSLY before anything can spawn a new one: an
        -- async pkill raced the audio timer's call_now, so every restart left
        -- its cava behind and they all wrote to the same widget (11 at once,
        -- which is what "glitchy" actually was).
        os.execute("pkill -x cava >/dev/null 2>&1")

        local function stop_cava()
            if cava_pid then awesome.kill(cava_pid, 15) end
            cava_pid = nil
            cava_starting = false
            set_cava_active(false)   -- also zeroes the bars and repaints
        end

        local function update_cava_state()
            local want = audio_playing and desktop_visible()
            if want and not cava_pid and not cava_starting and awful.spawn then
                cava_starting = true
                local pid = awful.spawn.with_line_callback("cava", {
                    stdout = function(line) cava_smooth(line) end,
                    exit = function()
                        cava_pid = nil
                        cava_starting = false
                        set_cava_active(false)
                    end,
                })
                cava_starting = false
                if type(pid) == "number" then
                    cava_pid = pid
                    set_cava_active(true)
                elseif not cava_error_shown then
                    -- with_line_callback returns an error STRING when the
                    -- binary is missing. Say so once instead of retrying
                    -- invisibly every 5 s forever.
                    cava_error_shown = true
                    naughty.notify({
                        preset = naughty.config.presets.critical,
                        title  = "Music visualizer unavailable",
                        text   = tostring(pid) ..
                                 "\nInstall it with: make packages",
                    })
                end
            elseif not want then
                stop_cava()
            end
        end

        -- Audio state: one cheap pactl poll per 5 s (only uncorked streams
        -- count). This runs unconditionally — the media panel needs
        -- audio_playing for its own cadence, so gating the whole timer on a
        -- cava config would freeze the panel permanently when cava is absent.
        local have_cava_cfg = gears.filesystem.file_readable(
            os.getenv("HOME") .. "/.config/cava/config")
        if awful.spawn then
            local media_tick = 0
            gears.timer {
                timeout = 5, autostart = true, call_now = true,
                callback = function()
                    awful.spawn.easy_async_with_shell(
                        "pactl list sink-inputs 2>/dev/null | grep -c 'Corked: no'",
                        function(out)
                            audio_playing = (tonumber((out or ""):match("%d+")) or 0) > 0
                            if have_cava_cfg then update_cava_state() end
                            -- Poll metadata every tick while audio plays, else
                            -- every 8th (40s) just to catch a player starting.
                            media_tick = media_tick + 1
                            if audio_playing or media_tick % 8 == 0 then poll_media() end
                        end)
                end,
            }
        end
        if have_cava_cfg then
            -- Desktop visibility is event-driven — no polling needed.
            tag.connect_signal("property::selected", function(t)
                if t.screen == s then update_cava_state() end
            end)
            for _, sig in ipairs({ "property::maximized", "property::fullscreen",
                                   "property::minimized", "manage", "unmanage" }) do
                client.connect_signal(sig, update_cava_state)
            end
            -- Never leak the process across restarts.
            awesome.connect_signal("exit", stop_cava)
        end
    end

end)
-- }}}

-- {{{ Directional window navigation
-- awesome's built-in focus.bydirection only compares the top-left edge of
-- windows and ignores columns, so from a full-height master "up" matches
-- nothing (it is already the topmost window) while "down" jumps sideways into
-- the stack. This walks the actual neighbours instead: a candidate must
-- overlap on the perpendicular axis (same column for up/down, same row for
-- left/right) and lie beyond the current edge; nearest wins.
local function neighbour(dir)
    local cur = client.focus
    if not cur then return nil end
    local vertical = (dir == "up" or dir == "down")
    local a = cur:geometry()
    local best, best_d
    for _, c in ipairs(awful.client.visible(cur.screen)) do
        if c ~= cur and not c.minimized then
            local b = c:geometry()
            local overlaps, delta
            if vertical then
                overlaps = (b.x < a.x + a.width) and (b.x + b.width > a.x)
                delta    = (dir == "up") and (a.y - b.y) or (b.y - a.y)
            else
                overlaps = (b.y < a.y + a.height) and (b.y + b.height > a.y)
                delta    = (dir == "left") and (a.x - b.x) or (b.x - a.x)
            end
            if overlaps and delta > 0 and (not best_d or delta < best_d) then
                best, best_d = c, delta
            end
        end
    end
    return best
end

local function focus_dir(dir)
    local target = neighbour(dir)
    if target then
        target:emit_signal("request::activate", "focus_dir", { raise = false })
    elseif dir == "up" or dir == "down" then
        -- Nothing in this column (e.g. the full-height master): walk the client
        -- list so j/k are never dead keys.
        awful.client.focus.byidx(dir == "down" and 1 or -1)
    end
end

local function move_dir(dir)
    local target = neighbour(dir)
    if target then
        client.focus:swap(target)
    elseif dir == "up" or dir == "down" then
        awful.client.swap.byidx(dir == "down" and 1 or -1)
    end
end
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "F1",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),

    -- Hardware / media keys (volume via pactl to match the wibar widget)
    awful.key({ modkey }, "Escape",
              function()
                  -- Lock to the lightdm greeter. Self-healing: start
                  -- light-locker if installed-but-not-running, fall back to
                  -- dm-tool, and surface the reason on screen when neither works.
                  awful.spawn.easy_async_with_shell([[
if command -v light-locker-command >/dev/null 2>&1; then
    pgrep -x light-locker >/dev/null || { light-locker --lock-after-screensaver=5 --lock-on-suspend >/dev/null 2>&1 & sleep 0.5; }
    light-locker-command -l 2>&1 && exit 0
fi
dm-tool lock 2>&1 && exit 0
echo "No working screen locker: install light-locker (make packages) and make sure the session runs under lightdm."
exit 1
]], function(stdout, stderr, _, exit_code)
                      if exit_code ~= 0 then
                          naughty.notify({
                              preset = naughty.config.presets.critical,
                              title  = "Screen lock failed",
                              text   = ((stdout or "") .. " " .. (stderr or "")):gsub("%s+$", ""),
                          })
                      end
                  end)
              end,
              {description="lock screen (lightdm greeter)", group="awesome"}),
    awful.key({}, "XF86AudioRaiseVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%") end),
    awful.key({}, "XF86AudioLowerVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%") end),
    awful.key({}, "XF86AudioMute", function() awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86MonBrightnessUp", function() awful.spawn("brightnessctl set 5%+") end),
    awful.key({}, "XF86MonBrightnessDown", function() awful.spawn("brightnessctl set 5%-") end),
    awful.key({}, "XF86AudioPlay", function() awful.spawn("playerctl play-pause") end),
    awful.key({}, "XF86AudioNext", function() awful.spawn("playerctl next") end),
    awful.key({}, "XF86AudioPrev", function() awful.spawn("playerctl previous") end),

    -- Fake Windows screens (pranks); Escape dismisses them.
    awful.key({ modkey, "Shift" }, "u", function() local p = require("win_pranks")
                  if p.is_open() then p.close() else p.update() end end,
              {description="fake Windows Update overlay", group="fun"}),
    awful.key({ modkey, "Shift" }, "b", function() local p = require("win_pranks")
                  if p.is_open() then p.close() else p.bsod() end end,
              {description="fake blue screen of death", group="fun"}),
    awful.key({ modkey, "Shift" }, "w", function() local p = require("win_pranks")
                  if p.is_open() then p.close() else p.wannacry() end end,
              {description="fake WannaCry ransom screen", group="fun"}),

    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    -- Directional hjkl: h=left, j=down, k=up, l=right in every combination.
    --   Super             -> FOCUS the neighbour
    --   Super+Alt(Mod1)   -> MOVE the window there
    --   Super+Control     -> RESIZE it
    awful.key({ modkey }, "h", function () focus_dir("left")  end,
              {description = "focus window left/down/up/right (hjkl)", group = "client"}),
    awful.key({ modkey }, "j", function () focus_dir("down")  end),
    awful.key({ modkey }, "k", function () focus_dir("up")    end),
    awful.key({ modkey }, "l", function () focus_dir("right") end),

    awful.key({ modkey, "Mod1" }, "h", function () move_dir("left")  end,
              {description = "move window left/down/up/right (Alt+hjkl)", group = "client"}),
    awful.key({ modkey, "Mod1" }, "j", function () move_dir("down")  end),
    awful.key({ modkey, "Mod1" }, "k", function () move_dir("up")    end),
    awful.key({ modkey, "Mod1" }, "l", function () move_dir("right") end),

    awful.key({ modkey, "Shift" }, "n", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    -- Standard program
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
    awful.key({ modkey, "Control"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),
    awful.key({ modkey, "Shift" }, "t",
        function()
            local order = { "dr460nized", "arch", "ubuntu", "windows7", "win11" }
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
            -- Terminal palette follows the WM theme. Alacritty live-reloads on
            -- config change, so open terminals recolour without a restart.
            local home  = os.getenv("HOME")
            local aterm = (next_theme == "dr460nized") and "dr460nized" or "mocha"
            os.execute(("cp %s/.config/alacritty/themes/%s.toml %s/.config/alacritty/theme.toml 2>/dev/null")
                :format(home, aterm, home))
            awesome.restart()
        end,
        {description = "cycle theme (dr460nized/arch/ubuntu/windows7/win11)", group = "awesome"}),

    -- RESIZE: same hjkl directions, held with Control.
    -- h/l move the master split; j/k grow/shrink the focused client's row.
    awful.key({ modkey, "Control" }, "h", function () awful.tag.incmwfact(-0.05) end,
              {description = "resize window (Ctrl+hjkl)", group = "layout"}),
    awful.key({ modkey, "Control" }, "l", function () awful.tag.incmwfact( 0.05) end),
    awful.key({ modkey, "Control" }, "j", function ()
                  if client.focus then awful.client.incwfact(-0.10, client.focus) end
              end),
    awful.key({ modkey, "Control" }, "k", function ()
                  if client.focus then awful.client.incwfact( 0.10, client.focus) end
              end),
    awful.key({ modkey, "Shift"   }, "period", function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "more master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "comma", function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "fewer master clients", group = "layout"}),
    -- Columns in the STACK area. The stack is one column by default, so the
    -- screen reads as two columns (master + stack); ncol 2 gives three.
    awful.key({ modkey, "Control" }, "period", function () awful.tag.incncol( 1, nil, true) end,
              {description = "more stack columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "comma", function () awful.tag.incncol(-1, nil, true) end,
              {description = "fewer stack columns", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.spawn(rofi_arch) end,
              {description = "open Rofi (apps, then power actions)", group = "launcher"}),
    awful.key({ modkey, "Shift" },   "v",
        function () awful.spawn(os.getenv("HOME") .. "/.config/awesome/scripts/clipboard-menu.sh") end,
              {description = "clipboard history", group = "launcher"}),
    -- Same script mode the launcher lists, shown on its own: one definition of
    -- the actions, two ways in. (Super+R for "with everything else", Super+P
    -- for "just these five".)
    awful.key({ modkey },            "p",
        function ()
            awful.spawn.with_shell(
                "rofi -show power -modes 'power:" .. os.getenv("HOME") ..
                "/.config/awesome/scripts/rofi-power-mode.sh' -theme " ..
                os.getenv("HOME") .. "/.config/awesome/themes/" .. ACTIVE_THEME ..
                "/rofi-" .. ACTIVE_THEME .. ".rasi " ..
                "-theme-str 'window { width: 420px; } " ..
                "listview { columns: 1; lines: 5; } element-icon { size: 0px; }'")
        end,
              {description = "power actions (lock/logout/suspend/reboot/off)", group = "launcher"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey            }, "q",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    -- Sticky = show on every tag, so the window stays mapped and OBS can
    -- capture it from any tag (off-tag windows are unmapped -> black otherwise).
    awful.key({ modkey,           }, "s",      function (c) c.sticky = not c.sticky          end,
              {description = "toggle sticky (visible on all tags, for OBS capture)", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "i",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  i == 1 and {description = "view tag #1-9", group = "tag"} or nil),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  i == 1 and {description = "toggle tag #1-9 into view", group = "tag"} or nil),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  i == 1 and {description = "move window to tag #1-9", group = "tag"} or nil),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  i == 1 and {description = "also show window on tag #1-9", group = "tag"} or nil)
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

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen,
     }
    },
    { rule_any = { class = { "Brave-browser", "code-oss" } },
      properties = {
                     floating = false,
                     maximized = false,
                     fullscreen = false,
                     placement = awful.placement.no_overlap + awful.placement.no_offscreen
    }
},
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c)
    c.border_color = beautiful.border_focus
    c.border_width = beautiful.border_width_focus or beautiful.border_width
end)
client.connect_signal("unfocus", function(c)
    c.border_color = beautiful.border_normal
    c.border_width = beautiful.border_width
end)
-- }}}

-- Autostart
-- Faster keyboard autorepeat (300 ms delay, 50 chars/sec) so holding j/k etc.
-- moves quickly — matches Luke Smith's `xset r rate 300 50`.
awful.spawn.with_shell("xset r rate 300 50")

-- Wallpaper: if the "video_wallpaper" marker file exists, use the looping
-- video wallpaper (which itself falls back to a still image when unsuitable);
-- otherwise rotate random band stills (Rammstein / MoonSun) via feh.
-- Populate/refresh the folder with scripts/wallpaper-fetch-bands.sh.
do
    -- Random band wallpaper with a small caption box (bottom-right) showing
    -- where/when the picture was taken. Captions come from
    -- ~/Media/wallpapers/bands/.captions.tsv, written by
    -- scripts/wallpaper-fetch-bands.sh (auto-run when the folder is empty);
    -- fallback is the file name.
    local function start_band_wallpaper()
        local function esc(s)
            return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
        end

        local cap_text = wibox.widget {
            markup = "",
            align  = "left",
            widget = wibox.widget.textbox,
        }
        -- Width is recomputed per caption below; a fixed 640px box left a wide
        -- empty bar next to short captions.
        local cap_box = wibox({
            screen            = screen.primary,
            width             = 320,
            height            = 30,
            visible           = false,
            ontop             = false,
            type              = "desktop",
            input_passthrough = true,
            bg                = C.mantle .. UI.tile_alpha,
            fg                = C.subtext1,
            shape             = rounded(UI.radius_outer),
        })
        cap_box:setup {
            cap_text,
            left = 14, right = 14, top = 5, bottom = 5,
            widget = wibox.container.margin,
        }
        local function place_caption()
            -- Bottom-left: shares dash_tile's left rail and media_tile's
            -- baseline, so three of the four rails carry ink. The old 22/16
            -- insets were off the 24px grid in both axes.
            local g = screen.primary.workarea
            cap_box.x = g.x + DESK.gutter
            cap_box.y = g.y + g.height - cap_box.height - DESK.gutter
        end
        screen.primary:connect_signal("property::geometry", place_caption)

        -- Pick a random image, set it, and print its caption on stdout.
        local ROTATE_CMD = [[bash -c '
dir="$HOME/Media/wallpapers/bands"
f=$(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -printf "%f\n" | shuf -n1)
if [ -z "$f" ]; then
    # Fresh machine: no wallpapers downloaded yet — fetch in the background
    # (needs network + jq); the retry below picks them up when done.
    # flock (not pgrep -f: it would match this very command line) keeps
    # concurrent retries from stacking fetches.
    nohup flock -n /tmp/.lukas-wallpaper-fetch.lock \
        "$HOME/.config/awesome/scripts/wallpaper-fetch-bands.sh" >/dev/null 2>&1 &
    exit 0
fi
# Post-process into a quiet backdrop (darken/desaturate/blur) so the photo
# stops competing with the UI. Cached, ~10ms on a hit; any failure falls back
# to the untouched original so the desktop always gets a wallpaper.
img="$dir/$f"
prep="$HOME/.config/awesome/scripts/wallpaper-prep.sh"
if [ -x "$prep" ]; then
    prepped=$("$prep" "$img" 2>/dev/null) && [ -n "$prepped" ] && img="$prepped"
fi
feh --bg-fill "$img"
cap=$(awk -F"\t" -v k="$f" "\$1==k{print \$2; exit}" "$dir/.captions.tsv" 2>/dev/null)
if [ -z "$cap" ]; then cap="${f%.*}"; cap="${cap//_/ }"; fi
echo "$cap"
']]

        local function rotate_wallpaper()
            awful.spawn.easy_async(ROTATE_CMD, function(stdout)
                local cap = (stdout or ""):gsub("%s+$", "")
                if cap == "" then
                    -- No image was set (first boot: downloads still running) —
                    -- retry soon instead of waiting for the 10-minute timer.
                    cap_box.visible = false
                    gears.timer.start_new(90, function()
                        rotate_wallpaper()
                        return false
                    end)
                    return
                end
                cap_text:set_markup("<span font='" .. font(9) .. "'>\u{f03e}  " ..
                                    esc(cap) .. "</span>")
                -- Measure the string that is actually drawn (icon + two spaces
                -- + caption), then add the 14/14 side margins and a little
                -- slack. The old character-count guess was ~8px short, which is
                -- exactly why the caption ellipsised. Capped so a long caption
                -- can never run under the media panel.
                cap_box.width = math.min(1080,
                    36 + text_width("\u{f03e}  " .. cap, font(9)))
                place_caption()
                cap_box.visible = true
            end)
        end

        rotate_wallpaper()
        gears.timer {
            timeout   = 600, -- new random wallpaper every 10 minutes
            autostart = true,
            callback  = rotate_wallpaper,
        }
    end

    local marker = os.getenv("HOME") .. "/.config/awesome/video_wallpaper"
    local f = io.open(marker, "r")
    if f then
        f:close()
        -- The script exits 3 when it can't/won't run the video (no video
        -- file, on battery, multi-monitor, missing tools) — in that case
        -- run the band-still rotation instead of leaving the default.
        awful.spawn.easy_async_with_shell(
            os.getenv("HOME") .. "/.config/awesome/scripts/wallpaper-video.sh",
            function(_, _, _, exit_code)
                if exit_code ~= 0 then start_band_wallpaper() end
            end)
    else
        start_band_wallpaper()
    end
end
awful.spawn.with_shell("pkill -x picom; picom --config " .. os.getenv("HOME") .. "/.config/awesome/picom.conf")
awful.spawn.with_shell("pgrep -x flameshot >/dev/null || flameshot &")
-- NetworkManager tray applet (wifi picker; eduroam setup in docs/eduroam-au.md)
awful.spawn.with_shell("pgrep -x nm-applet >/dev/null || nm-applet &")
-- Clipboard history daemon (Super+Shift+V opens the picker). It only records
-- while running, so a dead daemon means an empty list forever.
awful.spawn.with_shell(
    "command -v greenclip >/dev/null && { pgrep -x greenclip >/dev/null || greenclip daemon & }")
-- Screen lock: light-locker VT-switches to the lightdm greeter (the visible,
-- themed lock screen) after 5 min idle and on suspend/lid close. The greeter
-- path is safe again — the malformed Xorg snippet that black-screened it is
-- fixed and validated at install time (services.sh + xorg_conf_valid).
-- 'xset s noblank' is the important part: with X's own blanking enabled (the
-- default) X paints the screen BLACK at the idle timeout, and that black is
-- what you see -- not the greeter. light-locker still gets the screensaver
-- activation and locks; it just no longer sits behind a blanked X screen.
-- cycle 0 stops X re-triggering, and locking 1s after activation keeps the
-- gap between "idle" and "greeter visible" as short as possible.
awful.spawn.with_shell(
    "command -v light-locker >/dev/null && { xset s 300 0; xset s noblank; " ..
    "pgrep -x light-locker >/dev/null || light-locker --lock-after-screensaver=1 --lock-on-suspend & }")

-- GTK / icon / cursor theme for non-awesome apps (Brave, GTK tools, Qt via
-- the icon name). This runs on every start and overwrites settings.ini, so it
-- has to follow ACTIVE_THEME or it would drag the desktop back to Mocha.
-- Every value is applied only if it is actually installed.
do
    local looks = {
        dr460nized = { gtk = "Sweet-Dark",   icon = "candy-icons",
                       cursor = "Sweet-cursors" },
        default    = { gtk = "Adwaita-dark", icon = "Papirus-Dark",
                       cursor = "catppuccin-mocha-mauve-cursors" },
    }
    local look = looks[ACTIVE_THEME] or looks.default
    awful.spawn.with_shell(([[
gtk=%s; icon=%s; cursor=%s
[ -d "/usr/share/themes/$gtk" ] || gtk=Adwaita-dark
[ -d "/usr/share/icons/$icon" ] || icon=Papirus-Dark
[ -d "/usr/share/icons/$icon" ] || icon=Adwaita
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0
{
  printf '[Settings]\n'
  printf 'gtk-theme-name=%%s\n' "$gtk"
  printf 'gtk-icon-theme-name=%%s\n' "$icon"
  printf 'gtk-application-prefer-dark-theme=1\n'
  [ -d "/usr/share/icons/$cursor" ] && printf 'gtk-cursor-theme-name=%%s\n' "$cursor"
} | tee ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini >/dev/null
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
gsettings set org.gnome.desktop.interface gtk-theme "$gtk" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "$icon" 2>/dev/null
if [ -d "/usr/share/icons/$cursor" ]; then
    echo "Xcursor.theme: $cursor" | xrdb -merge
    gsettings set org.gnome.desktop.interface cursor-theme "$cursor" 2>/dev/null
fi
true
]]):format(look.gtk, look.icon, look.cursor))
end
