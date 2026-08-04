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

-- Informational cheatsheets shown in the super+F1 popup: these are not real
-- AwesomeWM bindings, just reminders for tools used inside the terminal.
require("awful.hotkeys_popup.widget").add_hotkeys({
    -- Single reference of every Space (leader) operation in Neovim. The rest
    -- (Ctrl splits, Copilot, VimTeX, folds…) is discoverable via which-key
    -- inside nvim, so it's intentionally not duplicated here.
    ["Nvim (Space leader)"] = {{
        modifiers = { "Space" },
        keys = {
            e       = "file explorer (toggle tree)",
            f       = "find files",
            ["/"]   = "live grep across files",
            b       = "list open buffers",
            fh      = "help tags",
            fd      = "list diagnostics (warnings/errors)",
            d       = "show diagnostic on current line",
            ["1-9"] = "jump to buffer N",
            m       = "toggle minimap",
            w       = "write (save)",
            q       = "quit",
            x       = "write and quit",
            H       = "clear search highlight",
            rn      = "LSP rename symbol",
            ca      = "LSP code action",
            gc      = "git commits (repo history)",
            gf      = "git file history",
            gs      = "git status",
            ga      = "git stage hunk",
            gp      = "git preview hunk",
            gb      = "git blame line",
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
}
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

-- {{{ Shape + widget helpers
local function rounded(r)
    return function(cr, w, h) gears.shape.rounded_rect(cr, w, h, r) end
end

-- Rofi theme follows the active arch-family theme (rofi-<theme>.rasi).
local rofi_arch = "rofi -show drun -show-icons -theme "
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
            "<span font='" .. font(24) .. "' foreground='" .. color .. "'>" ..
            glyph .. "</span>")
    end
    -- Mute button reflects state. This runs on every poll, so the state must
    -- live here rather than in the widget definitions.
    if mute_btn_lbl then
        mute_btn_lbl:set_markup(
            "<span font='" .. font(13) .. "' foreground='" ..
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
    markup = "<span font='" .. font(24) .. "' foreground='" .. C.mauve .. "'>\u{f028}</span>",
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
    markup = "<span font='" .. font(13) .. "' foreground='" .. C.mauve .. "'>\u{f028}</span>",
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
                    forced_width = dpi(40),
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
        {
            bg            = C.surface0,
            forced_height = 1,
            widget        = wibox.container.background,
        },
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

local function vol_popup_show(anchor_widget)
    local scr = awful.screen.focused()
    vol_popup.screen = scr
    -- Position: top-right under the wibar
    awful.placement.top_right(vol_popup, { parent = scr, margins = { top = 56, right = 20 } })
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

    -- Pacman updates (shared checkupdates poller)
    local upd_box, upd_txt = stat_cell("\u{f019}", C.yellow, "0")
    upd_box.visible = false
    subscribe_updates(function(n)
        if n > 0 then
            upd_txt:set_markup("<span foreground='" .. C.red .. "'>" .. n .. "</span>")
            upd_box.visible = true
        else
            upd_box.visible = false
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

    -- Taglist: glyph pills (wide enough for nerd-font icons)
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        layout  = { spacing = 4, layout = wibox.layout.fixed.horizontal },
        widget_template = {
            {
                {
                    {
                        {
                            id     = "text_role",
                            widget = wibox.widget.textbox,
                            align  = "center",
                            valign = "center",
                        },
                        forced_width = 24,
                        widget = wibox.container.background,
                    },
                    left = 12, right = 12, top = 5, bottom = 5,
                    widget = wibox.container.margin,
                },
                id           = "background_role",
                shape        = rounded(UI.radius_inner),
                widget       = wibox.container.background,
            },
            widget = wibox.container.background,
        },
    }

    -- Tasklist: rounded pill + underline on focused
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
                                margins = 3,
                                widget  = wibox.container.margin,
                            },
                            {
                                {
                                    id     = "text_role",
                                    widget = wibox.widget.textbox,
                                },
                                left = 6, right = 8,
                                widget = wibox.container.margin,
                            },
                            layout = wibox.layout.fixed.horizontal,
                        },
                        left = 4, top = UI.pill_t, bottom = UI.pill_b,
                        widget = wibox.container.margin,
                    },
                    id           = "background_role",
                    widget       = wibox.container.background,
                    shape        = rounded(UI.radius_inner),
                },
                {
                    {
                        id            = "underline",
                        bg            = C.mauve,
                        forced_height = 2,
                        forced_width  = 26,
                        visible       = false,
                        shape         = rounded(UI.radius_inner),
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
        forced_width  = dpi(28),
        forced_height = dpi(28),
        widget = wibox.container.background,
    }
    local launcher_bg = wibox.widget {
        {
            launcher_glyph,
            left = 9, right = 9, top = UI.pill_t, bottom = UI.pill_b,
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
            forced_width  = 1,
            bg            = C.surface1,
            widget        = wibox.container.background,
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
            border_width = 0, bg_color = "#00000000", fg_color = C.blue,
            markup = function(t) return "<b>" .. t .. "</b>" end,
        },
        style_normal  = {
            border_width = 0, bg_color = "#00000000", fg_color = C.text, padding = 5,
        },
        style_focus   = {
            border_width = 0, bg_color = C.mauve, fg_color = C.base, padding = 5,
            shape = rounded(UI.radius_inner),
            markup = function(t) return "<b>" .. t .. "</b>" end,
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
            { parent = awful.screen.focused(), margins = { top = 56, right = 20 } })
    end
    local function cal_toggle()
        if cal_popup.visible then
            cal_popup.visible = false
            cal_timer:stop()
        else
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
        height   = 50,
        bg       = "#00000000",
        fg       = C.text,
    })

    -- Right-side widget strip; battery only exists on machines that have one.
    local right_widgets = {
        layout  = wibox.layout.fixed.horizontal,
        spacing = 6,
        cpu_box,
        mem_box,
        upd_box,
        make_volume_widget(),
    }
    if BAT_PATH then table.insert(right_widgets, make_battery_widget()) end
    table.insert(right_widgets, tray)
    table.insert(right_widgets, clock_box)

    s.mywibox:setup {
        {
            {
                {
                    {
                        layout  = wibox.layout.fixed.horizontal,
                        spacing = 6,
                        launcher,
                        s.mytaglist,
                        s.mypromptbox,
                    },
                    s.mytasklist,
                    right_widgets,
                    layout = wibox.layout.align.horizontal,
                },
                left = 10, right = 10, top = 4, bottom = 4,
                widget = wibox.container.margin,
            },
            -- Glassy floating strip (blur is excluded for dock windows, so the
            -- alpha alone carries the frosted look over dark wallpapers).
            bg     = C.crust .. "d9",
            shape  = rounded(UI.radius_outer),
            widget = wibox.container.background,
        },
        left = 8, right = 8, top = 4, bottom = 2,
        widget = wibox.container.margin,
    }

    ---------------------------------------------------------------
    -- Desktop tiles (floating wiboxes pinned to the wallpaper)
    ---------------------------------------------------------------

    -- Helper: create a rounded tile wibox in the "desktop" layer.
    -- Border width/color/radius match picom's window rounding + awesome's
    -- border_normal so tiles and windows are visually consistent.
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

    local hero_clock = wibox.widget.textclock(
        "<span font='" .. font(42) .. "' foreground='" .. C.text ..
        "' weight='bold'>%H:%M</span>", 30)

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

    local HERO_W = 520 -- column-aligned with the neofetch tile below
    local hero_tile = make_tile(HERO_W, 270)
    hero_tile:setup {
        {
            {
                -- Greeting block
                {
                    hero_greeting,
                    { hero_greeting_sub, top = 2, widget = wibox.container.margin },
                    spacing = 0,
                    layout  = wibox.layout.fixed.vertical,
                },
                -- Divider
                {
                    {
                        bg = C.surface0,
                        forced_height = 1,
                        widget = wibox.container.background,
                    },
                    top = 10, bottom = 10,
                    widget = wibox.container.margin,
                },
                -- Time
                hero_clock,
                -- Date + weather
                {
                    { hero_date,    top = 6, widget = wibox.container.margin },
                    { hero_weather, top = 2, widget = wibox.container.margin },
                    spacing = 0,
                    layout  = wibox.layout.fixed.vertical,
                },
                spacing = 0,
                layout  = wibox.layout.fixed.vertical,
            },
            halign = "left",
            valign = "center",
            widget = wibox.container.place,
        },
        margins = UI.tile_margin,
        widget  = wibox.container.margin,
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
        markup = "<span foreground='" .. C.subtext1 .. "'>CPU</span>",
        widget = wibox.widget.textbox,
        valign = "center",
    }
    subscribe_cpu(function(pct) dash_cpu_bar:set_value(pct) end)

    local dash_mem_bar = bar_widget(C.green)
    local dash_mem_lbl = wibox.widget {
        markup = "<span foreground='" .. C.subtext1 .. "'>RAM</span>",
        widget = wibox.widget.textbox,
        valign = "center",
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
    local NEO_W = 520
    local NEO_H = 420
    local NEO_LOGO_W = dpi(160)
    -- key cell + value constraint keep the columns aligned and stop long
    -- values (the CPU model) from blowing past the tile edge.
    local NEO_KEY_W = dpi(78)
    local NEO_VAL_W = NEO_W - 2 * 24 - NEO_LOGO_W - 20 - NEO_KEY_W - 10
    local arch_logo = wibox.widget {
        {
            markup = "<span font='" .. font(110) .. "' foreground='" .. C.mauve ..
                     "' weight='bold'>\u{f303}</span>",
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
        local row = wibox.widget {
            {
                {
                    markup = "<span foreground='" .. (key_color or C.mauve) .. "' weight='bold'>" ..
                             key .. "</span>",
                    widget = wibox.widget.textbox,
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
            {
                bg            = C.surface0,
                forced_height = 1,
                widget        = wibox.container.background,
            },
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
        markup = "<span foreground='" .. C.peach .. "' weight='bold'>" ..
            (sys_info.user_host:match("^([^@]+)") or "user") ..
            "</span><span foreground='" .. C.overlay0 .. "'>@</span>" ..
            "<span foreground='" .. C.blue .. "' weight='bold'>" ..
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
        (info_row("packages", sys_info.packages .. " (pacman)")),
        uptime_row,
        divider(),
        dash_row(dash_cpu_lbl, dash_cpu_bar),
        dash_row(dash_mem_lbl, dash_mem_bar),
        { dash_upd, top = 6, widget = wibox.container.margin },
        spacing = 2,
        layout  = wibox.layout.fixed.vertical,
    }

    local neo_tile = make_tile(NEO_W, NEO_H)
    neo_tile:setup {
        {
            {
                { arch_logo, widget = wibox.container.place, valign = "top" },
                { neo_info,  widget = wibox.container.place, valign = "top" },
                spacing = 20,
                layout  = wibox.layout.fixed.horizontal,
            },
            halign = "left",
            valign = "center",
            widget = wibox.container.place,
        },
        margins = UI.tile_margin,
        widget  = wibox.container.margin,
    }

    ---------------------------------------------------------------
    -- Tile placement — single left column (hero above neofetch).
    -- The rest of the screen is deliberate negative space: the
    -- wallpaper subject and the cava bars get room to breathe.
    ---------------------------------------------------------------
    local function place_tiles()
        local wa  = s.workarea -- already excludes the wibar strut
        local m   = 24
        local gap = 16         -- echoes theme.useless_gap dpi(14)

        hero_tile.x = wa.x + m
        hero_tile.y = wa.y + m

        neo_tile.x = hero_tile.x
        neo_tile.y = hero_tile.y + hero_tile.height + gap
    end
    place_tiles()
    s:connect_signal("property::geometry", place_tiles)

    ---------------------------------------------------------------
    -- Music visualizer — cava bars along the bottom edge of the
    -- wallpaper. Resource-frugal: the cava process only runs while
    -- audio is actually playing AND the desktop is visible (no
    -- maximized/fullscreen client on the selected tag).
    ---------------------------------------------------------------
    if s == screen.primary then
        local CAVA_H    = 90
        local CAVA_BARS = 50   -- must match cava/.config/cava/config

        local cava_values = {}
        local cava_widget = wibox.widget.base.make_widget()
        function cava_widget:fit(_, w, h) return w, h end
        function cava_widget:draw(_, cr, w, h)
            local gap = 4
            local bw  = (w - (CAVA_BARS - 1) * gap) / CAVA_BARS
            cr:set_source(gears.color(C.mauve .. "b3"))
            for i = 1, CAVA_BARS do
                local v  = (cava_values[i] or 0) / 100
                local bh = math.max(2, v * (h - 4))
                cr:save()
                cr:translate((i - 1) * (bw + gap), h - bh)
                gears.shape.rounded_rect(cr, bw, bh, math.min(3, bw / 2))
                cr:restore()
            end
            cr:fill()
        end

        local cava_box = wibox({
            screen            = s,
            width             = s.geometry.width - 2 * 24,
            height            = CAVA_H,
            x                 = s.geometry.x + 24,
            y                 = s.geometry.y + s.geometry.height - CAVA_H - 8,
            visible           = false,
            ontop             = false,
            type              = "desktop",
            input_passthrough = true,
            bg                = "#00000000",
        })
        cava_box:setup { cava_widget, layout = wibox.layout.flex.horizontal }
        local function place_cava()
            cava_box.width = s.geometry.width - 2 * 24
            cava_box.x     = s.geometry.x + 24
            cava_box.y     = s.geometry.y + s.geometry.height - CAVA_H - 8
        end
        s:connect_signal("property::geometry", place_cava)

        -- Process lifecycle: track OUR pid (never pkill blindly — the same
        -- self-match trap as the wallpaper fetch guard).
        local cava_pid = nil
        local audio_playing = false

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

        local function stop_cava()
            if cava_pid then awesome.kill(cava_pid, 15) end
            cava_pid = nil
            cava_box.visible = false
        end

        local function update_cava_state()
            local want = audio_playing and desktop_visible()
            if want and not cava_pid and awful.spawn then
                local pid = awful.spawn.with_line_callback("cava", {
                    stdout = function(line)
                        local i = 1
                        for v in line:gmatch("%d+") do
                            cava_values[i] = tonumber(v)
                            i = i + 1
                        end
                        cava_widget:emit_signal("widget::redraw_needed")
                    end,
                    exit = function()
                        cava_pid = nil
                        cava_box.visible = false
                    end,
                })
                if type(pid) == "number" then
                    cava_pid = pid
                    cava_box.visible = true
                end
            elseif not want then
                stop_cava()
            end
        end

        -- Audio state: one cheap pactl poll per 5 s (only uncorked streams count).
        if awful.spawn and gears.filesystem.file_readable(
               os.getenv("HOME") .. "/.config/cava/config") then
            gears.timer {
                timeout = 5, autostart = true, call_now = true,
                callback = function()
                    awful.spawn.easy_async_with_shell(
                        "pactl list sink-inputs 2>/dev/null | grep -c 'Corked: no'",
                        function(out)
                            audio_playing = (tonumber((out or ""):match("%d+")) or 0) > 0
                            update_cava_state()
                        end)
                end,
            }
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
    awful.key({}, "XF86AudioRaiseVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%") end,
              {description="raise volume", group="media"}),
    awful.key({}, "XF86AudioLowerVolume", function() awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%") end,
              {description="lower volume", group="media"}),
    awful.key({}, "XF86AudioMute", function() awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end,
              {description="mute toggle", group="media"}),
    awful.key({}, "XF86MonBrightnessUp", function() awful.spawn("brightnessctl set 5%+") end,
              {description="brightness up", group="media"}),
    awful.key({}, "XF86MonBrightnessDown", function() awful.spawn("brightnessctl set 5%-") end,
              {description="brightness down", group="media"}),
    awful.key({}, "XF86AudioPlay", function() awful.spawn("playerctl play-pause") end,
              {description="play / pause", group="media"}),
    awful.key({}, "XF86AudioNext", function() awful.spawn("playerctl next") end,
              {description="next track", group="media"}),
    awful.key({}, "XF86AudioPrev", function() awful.spawn("playerctl previous") end,
              {description="previous track", group="media"}),

    -- Fake Windows screens (pranks); Escape dismisses them.
    awful.key({ modkey, "Shift" }, "u", function() require("win_pranks").update() end,
              {description="fake Windows Update overlay", group="fun"}),
    awful.key({ modkey, "Shift" }, "b", function() require("win_pranks").bsod() end,
              {description="fake blue screen of death", group="fun"}),

    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),

    -- Layout manipulation
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
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

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

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

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
              {description = "open Rofi", group = "launcher"})
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
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
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
                  {description = "move focused client to tag #"..i, group = "tag"}),
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
            align  = "right",
            widget = wibox.widget.textbox,
        }
        local cap_box = wibox({
            screen            = screen.primary,
            width             = 640,
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
            local g = screen.primary.workarea
            cap_box.x = g.x + g.width  - cap_box.width  - 22
            cap_box.y = g.y + g.height - cap_box.height - 16
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
feh --bg-fill "$dir/$f"
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
-- Screen lock: light-locker VT-switches to the lightdm greeter (the visible,
-- themed lock screen) after 5 min idle and on suspend/lid close. The greeter
-- path is safe again — the malformed Xorg snippet that black-screened it is
-- fixed and validated at install time (services.sh + xorg_conf_valid).
awful.spawn.with_shell(
    "command -v light-locker >/dev/null && { xset s 300 5; " ..
    "pgrep -x light-locker >/dev/null || light-locker --lock-after-screensaver=5 --lock-on-suspend & }")

-- Apply dark GTK/system color scheme for other apps (Brave, GTK-based tools)
awful.spawn.with_shell(
    "mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0 && " ..
    "printf '[Settings]\\ngtk-theme-name=Adwaita-dark\\ngtk-application-prefer-dark-theme=1\\ngtk-cursor-theme-name=catppuccin-mocha-mauve-cursors\\n' " ..
    "| tee ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini >/dev/null; " ..
    "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null; " ..
    "gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null; true"
)
-- Matching cursor theme (catppuccin-cursors-mocha, AUR) — guarded so a
-- machine without the package keeps the default cursor silently.
awful.spawn.with_shell(
    "[ -d /usr/share/icons/catppuccin-mocha-mauve-cursors ] && { " ..
    "echo 'Xcursor.theme: catppuccin-mocha-mauve-cursors' | xrdb -merge; " ..
    "gsettings set org.gnome.desktop.interface cursor-theme 'catppuccin-mocha-mauve-cursors' 2>/dev/null; true; }")
