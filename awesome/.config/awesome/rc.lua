-- Theme dispatcher: arch-family themes (arch/ubuntu/windows7) share this
-- config and only swap palette; win11 has its own bespoke layout.
local ARCH_FAMILY = { arch = true, ubuntu = true, windows7 = true }
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
    ["Nvim: Files & Find"] = {
        { modifiers = { "Space" }, keys = {
            e  = "file explorer",
            f  = "find files",
            g  = "live grep across files",
            b  = "list buffers",
            fh = "help tags",
            h  = "clear search highlight",
        }},
        { modifiers = { "Ctrl" }, keys = {
            v = "tree: vertical split",
            x = "tree: horizontal split",
            t = "tree: new tab",
        }},
        { modifiers = {}, keys = {
            ["Enter / o"] = "tree: open file",
            ["/text"]     = "search in file (n / N = next / prev)",
        }},
    },
    ["Nvim: Edit & Buffers"] = {
        { modifiers = { "Space" }, keys = {
            ["1-9"] = "jump to buffer N",
            w = "save",
            q = "quit",
            m = "toggle minimap",
        }},
        { modifiers = { "Ctrl" }, keys = {
            ["h/j/k/l"] = "move between splits",
            ["d / u"]   = "half-page down / up",
            J           = "accept Copilot suggestion",
            ["^"]       = "toggle last two buffers",
            Space       = "goat completion",
        }},
        { modifiers = { "Alt" }, keys = {
            ["]"] = "Copilot next suggestion",
            ["["] = "Copilot prev suggestion",
        }},
        { modifiers = { "," }, keys = {
            ll = "VimTeX compile",
            lv = "VimTeX view PDF (zathura)",
        }},
        { modifiers = {}, keys = {
            ["]b / [b"] = "next / previous buffer",
            [":bd"]     = "close buffer",
            x           = "delete char (no yank)",
            za          = "toggle fold",
            ["zR / zM"] = "open / close all folds",
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
    green     = beautiful.cat_green    or "#a6e3a1",
    yellow    = beautiful.cat_yellow   or "#f9e2af",
    peach     = beautiful.cat_peach    or "#fab387",
    red       = beautiful.cat_red      or "#f38ba8",
    pink      = beautiful.cat_pink     or "#f5c2e7",
}

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
local function stat_cell(glyph, glyph_color, initial)
    local txt = wibox.widget {
        markup = "<span foreground='" .. C.text .. "'>" .. (initial or "") .. "</span>",
        widget = wibox.widget.textbox,
        valign = "center",
    }
    local icon = wibox.widget {
        {
            markup = "<span foreground='" .. (glyph_color or C.mauve) .. "'>" .. glyph .. "</span>",
            widget = wibox.widget.textbox,
            align  = "center",
            valign = "center",
        },
        forced_width = 22,
        widget = wibox.container.background,
    }
    local body = wibox.widget {
        {
            icon,
            {
                txt,
                left = 8,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.horizontal,
        },
        left = 12, right = 14, top = 4, bottom = 4,
        widget = wibox.container.margin,
    }
    local box = wibox.widget {
        body,
        bg     = C.surface0,
        shape  = rounded(6),
        widget = wibox.container.background,
    }
    return box, txt, icon
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
            "<span foreground='" .. C.text .. "' size='large' weight='bold'>" ..
            label .. "</span>")
    end
    if vol_popup_icon then
        vol_popup_icon:set_markup(
            "<span size='xx-large' foreground='" .. color .. "'>" .. glyph .. "</span>")
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
vol_popup_icon = wibox.widget {
    markup = "<span size='xx-large' foreground='" .. C.mauve .. "'>\u{f57e}</span>",
    widget = wibox.widget.textbox,
    align  = "center", valign = "center",
}
vol_popup_pct = wibox.widget {
    markup = "<span foreground='" .. C.text .. "' size='large' weight='bold'>--%</span>",
    widget = wibox.widget.textbox,
    align  = "center", valign = "center",
}

vol_slider = wibox.widget {
    bar_shape           = rounded(4),
    bar_height          = 8,
    bar_color           = C.surface0,
    bar_active_color    = C.mauve,
    handle_color        = C.mauve,
    handle_shape        = gears.shape.circle,
    handle_width        = 16,
    handle_border_width = 2,
    handle_border_color = C.base,
    value               = 0,
    maximum             = 100,
    forced_width        = 260,
    forced_height       = 28,
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

local mute_btn_bg = wibox.container.background()
mute_btn_bg.bg    = C.surface0
mute_btn_bg.shape = rounded(6)
local mute_btn_lbl = wibox.widget {
    markup = "<span foreground='" .. C.mauve .. "' size='large'>\u{f75f}</span>",
    widget = wibox.widget.textbox,
    align  = "center", valign = "center",
}
mute_btn_bg:set_widget(wibox.widget {
    mute_btn_lbl,
    left = 12, right = 12, top = 6, bottom = 6,
    widget = wibox.container.margin,
})
mute_btn_bg:buttons(gears.table.join(
    awful.button({}, 1, function()
        awful.spawn.easy_async("pactl set-sink-mute @DEFAULT_SINK@ toggle", function()
            refresh_volume()
        end)
    end)
))

local vol_popup = wibox({
    width        = 340,
    height       = 130,
    ontop        = true,
    visible      = false,
    bg           = C.mantle,
    fg           = C.text,
    shape        = rounded(14),
    border_width = 2,
    border_color = C.mauve,
    type         = "notification",
})
vol_popup:setup {
    {
        {
            {
                { vol_popup_icon, widget = wibox.container.place, halign = "center" },
                { vol_popup_pct,  widget = wibox.container.place, halign = "center" },
                spacing = 12,
                layout  = wibox.layout.fixed.horizontal,
            },
            halign = "center",
            widget = wibox.container.place,
        },
        {
            { vol_slider, widget = wibox.container.place, halign = "center" },
            top = 8,
            widget = wibox.container.margin,
        },
        {
            { mute_btn_bg, widget = wibox.container.place, halign = "center" },
            top = 8,
            widget = wibox.container.margin,
        },
        spacing = 4,
        layout  = wibox.layout.fixed.vertical,
    },
    left = 20, right = 20, top = 14, bottom = 14,
    widget = wibox.container.margin,
}

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
    local icon_tb = wibox.widget {
        markup = "<span foreground='" .. C.mauve .. "'>\u{f028}</span>",
        widget = wibox.widget.textbox,
        align  = "center",
        valign = "center",
    }
    local text_tb = wibox.widget {
        markup = "<span foreground='" .. C.text .. "'>--%</span>",
        widget = wibox.widget.textbox,
        valign = "center",
    }
    table.insert(vol_subscribers, { icon_tb = icon_tb, text_tb = text_tb })

    local w = wibox.widget {
        {
            {
                {
                    icon_tb,
                    forced_width = 22,
                    widget = wibox.container.background,
                },
                { text_tb, left = 8, widget = wibox.container.margin },
                layout = wibox.layout.fixed.horizontal,
            },
            left = 12, right = 14, top = 4, bottom = 4,
            widget = wibox.container.margin,
        },
        bg     = C.surface0,
        shape  = rounded(6),
        widget = wibox.container.background,
    }
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
-- }}}

-- {{{ Claude Code usage — local JSONL entry counts only.
-- Source: ~/.claude/projects/**/*.jsonl (per scripts/claude-usage.py).
-- Counts entries where type=user or type=assistant. These are NOT a
-- substitute for Anthropic's rate-limit accounting; no API call is made.
local claude_subs = {} -- { fn({ n5, n7, today, days[1..7] }) }
local function subscribe_claude(fn) table.insert(claude_subs, fn) end

local CLAUDE_CMD = "python3 " ..
    os.getenv("HOME") .. "/.config/awesome/scripts/claude-usage.py"

local function poll_claude()
    awful.spawn.easy_async(CLAUDE_CMD, function(stdout)
        local nums = {}
        for tok in (stdout or ""):gmatch("(%S+)") do
            nums[#nums + 1] = tonumber(tok) or 0
        end
        if #nums < 10 then return end
        local state = {
            n5    = nums[1],
            n7    = nums[2],
            today = nums[3],
            days  = { nums[4], nums[5], nums[6], nums[7], nums[8], nums[9], nums[10] },
        }
        for _, fn in ipairs(claude_subs) do fn(state) end
    end)
end
gears.timer { timeout = 180, autostart = true, call_now = true, callback = poll_claude }
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

    local mem_box, mem_txt = stat_cell("\u{efc5}", C.green, "--%")
    subscribe_mem(function(pct)
        mem_txt:set_markup("<span foreground='" .. C.text .. "'>" .. pct .. "%</span>")
    end)

    -- Pacman updates (checkupdates)
    local upd_box, upd_txt = stat_cell("\u{f019}", C.yellow, "0")
    upd_box.visible = false
    awful.widget.watch(
        [[sh -c "checkupdates 2>/dev/null | wc -l"]], 900,
        function(_, stdout)
            local n = tonumber((stdout or ""):match("%d+")) or 0
            if n > 0 then
                upd_txt:set_markup("<span foreground='" .. C.red .. "'>" .. n .. "</span>")
                upd_box.visible = true
            else
                upd_box.visible = false
            end
        end
    )
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
            gap                = 10,
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
                shape        = rounded(6),
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
                                id     = "icon_role",
                                widget = wibox.widget.imagebox,
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
                    id           = "background_role",
                    widget       = wibox.container.background,
                    shape        = rounded(6),
                },
                {
                    {
                        id            = "underline",
                        bg            = C.mauve,
                        forced_height = 2,
                        forced_width  = 26,
                        visible       = false,
                        shape         = rounded(4),
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
    local launcher_glyph = wibox.widget {
        {
            markup = "<span font='FiraCode Nerd Font 16' foreground='" .. C.base ..
                     "' weight='bold'>\u{f303}</span>",
            widget = wibox.widget.textbox,
            align  = "center",
            valign = "center",
        },
        forced_width  = 28,
        forced_height = 28,
        widget = wibox.container.background,
    }
    local launcher_bg = wibox.widget {
        {
            launcher_glyph,
            left = 10, right = 10, top = 3, bottom = 3,
            widget = wibox.container.margin,
        },
        bg     = C.mauve,
        shape  = rounded(8),
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

    -- Clock
    local clock_txt = wibox.widget.textclock(
        "<span foreground='" .. C.text .. "'>\u{f017}  %H:%M  </span>" ..
        "<span foreground='" .. C.subtext1 .. "'>%a %d %b</span>", 60)
    local clock_box = wibox.widget {
        {
            clock_txt,
            left = 10, right = 10, top = 4, bottom = 4,
            widget = wibox.container.margin,
        },
        bg     = C.surface0,
        shape  = rounded(6),
        widget = wibox.container.background,
    }

    -- Systray
    local tray = wibox.widget {
        {
            wibox.widget.systray(),
            left = 6, right = 6, top = 4, bottom = 4,
            widget = wibox.container.margin,
        },
        bg     = C.surface0,
        shape  = rounded(6),
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
                    {
                        layout  = wibox.layout.fixed.horizontal,
                        spacing = 6,
                        cpu_box,
                        mem_box,
                        upd_box,
                        make_volume_widget(),
                        tray,
                        clock_box,
                    },
                    layout = wibox.layout.align.horizontal,
                },
                left = 10, right = 10, top = 4, bottom = 4,
                widget = wibox.container.margin,
            },
            bg     = C.mantle,
            shape  = rounded(8),
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
            bg                = C.mantle .. "e6", -- translucent via aRGB (requires picom)
            fg                = C.text,
            shape             = rounded(10),
            border_width      = 2,
            border_color      = C.surface0,
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
        markup = "<span font='FiraCode Nerd Font 13' foreground='" .. C.mauve ..
                 "' style='italic'>\u{201c}" .. pango_escape(quote_text) .. "\u{201d}</span>",
        wrap   = "word",
        forced_width = 400,
        widget = wibox.widget.textbox,
    }
    local hero_greeting_sub = wibox.widget {
        markup = "<span font='FiraCode Nerd Font 10' foreground='" .. C.overlay0 ..
                 "'>\u{2014} " .. pango_escape(quote_author) .. "</span>",
        widget = wibox.widget.textbox,
    }
    -- display_name kept for potential reuse elsewhere.
    local _ = display_name

    local hero_clock = wibox.widget.textclock(
        "<span font='FiraCode Nerd Font 42' foreground='" .. C.text ..
        "' weight='bold'>%H:%M</span>", 30)

    local hero_date = wibox.widget.textclock(
        "<span foreground='" .. C.subtext1 .. "'>%A, %d %B %Y</span>", 3600)

    -- Weather line (inline with date)
    local hero_weather = wibox.widget {
        markup = "<span foreground='" .. C.overlay0 .. "'>loading weather…</span>",
        widget = wibox.widget.textbox,
    }
    awful.widget.watch(
        [[sh -c "curl -s --max-time 5 'wttr.in/?format=%t|%C' 2>/dev/null | head -c 80"]],
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
                    "<span foreground='" .. C.subtext1 .. "'>  · " .. cond .. "</span>"
                )
            else
                hero_weather:set_markup("<span foreground='" .. C.text .. "'>" .. s_ .. "</span>")
            end
        end
    )

    local HERO_W = 460
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
        margins = 22,
        widget  = wibox.container.margin,
    }

    local function bar_widget(color)
        return wibox.widget {
            max_value        = 100,
            value            = 0,
            forced_height    = 10,
            forced_width     = 140,
            shape            = rounded(6),
            bar_shape        = rounded(6),
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
    awful.widget.watch(
        [[sh -c "checkupdates 2>/dev/null | wc -l"]], 900,
        function(_, stdout)
            local n = tonumber((stdout or ""):match("%d+")) or 0
            if n > 0 then
                dash_upd:set_markup(
                    "<span foreground='" .. C.yellow .. "'>\u{f019}  </span>" ..
                    "<span foreground='" .. C.red .. "' weight='bold'>" .. n .. "</span>" ..
                    "<span foreground='" .. C.subtext1 .. "'> updates available</span>")
            else
                dash_upd:set_markup(
                    "<span foreground='" .. C.green .. "'>\u{f058}  system up to date</span>")
            end
        end
    )

    -- Neofetch-style tile (Arch logo + system info)
    local NEO_W = 460
    local NEO_H = 380
    local arch_logo = wibox.widget {
        {
            markup = "<span font='FiraCode Nerd Font 100' foreground='" .. C.mauve ..
                     "' weight='bold'>\u{f303}</span>",
            widget = wibox.widget.textbox,
            align  = "center",
            valign = "center",
        },
        forced_width  = 150,
        forced_height = 150,
        widget = wibox.container.background,
    }
    local function info_row(key, val, key_color)
        return wibox.widget {
            {
                markup = "<span foreground='" .. (key_color or C.mauve) .. "' weight='bold'>" ..
                         key .. "</span>",
                widget = wibox.widget.textbox,
            },
            {
                {
                    markup = "<span foreground='" .. C.text .. "'>" .. (val or "") .. "</span>",
                    widget = wibox.widget.textbox,
                },
                left = 10,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.horizontal,
        }
    end

    local uptime_row_txt = wibox.widget {
        markup = "<span foreground='" .. C.text .. "'>…</span>",
        widget = wibox.widget.textbox,
    }
    local function refresh_uptime()
        awful.spawn.easy_async("uptime -p", function(out)
            local s_ = (out or ""):gsub("\n", ""):gsub("^up ", "")
            s_ = s_:gsub(" hours?", "h"):gsub(" minutes?", "m"):gsub(",", "")
            uptime_row_txt:set_markup("<span foreground='" .. C.text .. "'>" .. s_ .. "</span>")
        end)
    end
    refresh_uptime()
    gears.timer { timeout = 60, autostart = true, callback = refresh_uptime }

    local uptime_row = wibox.widget {
        {
            markup = "<span foreground='" .. C.mauve .. "' weight='bold'>uptime</span>",
            widget = wibox.widget.textbox,
        },
        { uptime_row_txt, left = 10, widget = wibox.container.margin },
        layout = wibox.layout.fixed.horizontal,
    }

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
        info_row("os",       sys_info.os_name),
        info_row("kernel",   sys_info.kernel),
        info_row("wm",       sys_info.wm),
        info_row("shell",    sys_info.shell),
        info_row("cpu",      sys_info.cpu ~= "" and sys_info.cpu or "unknown"),
        info_row("packages", sys_info.packages .. " (pacman)"),
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
        margins = 22,
        widget  = wibox.container.margin,
    }

    ---------------------------------------------------------------
    -- CLAUDE TILE — fixed, properly-spaced layout
    ---------------------------------------------------------------
    local cc_title = wibox.widget {
        markup = "<span font='FiraCode Nerd Font 11' foreground='" .. C.mauve ..
                 "' weight='bold'>\u{f02d}  claude code</span>",
        widget = wibox.widget.textbox,
    }
    -- Simple "label: count" rows for rolling windows — no guessed limits.
    local function count_row(label_text)
        local lbl = wibox.widget {
            markup = "<span foreground='" .. C.subtext1 .. "'>" .. label_text .. "</span>",
            widget = wibox.widget.textbox,
            valign = "center",
        }
        local val = wibox.widget {
            markup = "<span foreground='" .. C.text .. "' weight='bold'>–</span>",
            widget = wibox.widget.textbox,
            valign = "center",
            align  = "right",
        }
        local container = wibox.widget {
            {
                lbl,
                val,
                layout = wibox.layout.align.horizontal,
            },
            forced_height = 24,
            widget        = wibox.container.background,
        }
        return container, val
    end

    local cc_5h_row,   cc_5h_val   = count_row("last 5 hours")
    local cc_week_row, cc_week_val = count_row("last 7 days")

    -- 7-day bars — tall vertical bars via rotated progressbars so they fill
    -- the claude tile naturally.
    local SPARK_CELL_W = 46
    local SPARK_GAP    = 8
    local SPARK_H      = 130
    local sparkline_bars   = {}
    local sparkline_labels = {}

    local sparkline_row = wibox.widget {
        layout  = wibox.layout.fixed.horizontal,
        spacing = SPARK_GAP,
    }
    local cc_days_row = wibox.widget {
        layout  = wibox.layout.fixed.horizontal,
        spacing = SPARK_GAP,
    }
    for i = 1, 7 do
        -- Horizontal progressbar that we rotate 90° counter-clockwise,
        -- so visual width = forced_height and fill direction is bottom→top.
        local base_bar = wibox.widget {
            max_value        = 1,
            value            = 0.02,
            forced_height    = SPARK_CELL_W,
            forced_width     = SPARK_H,
            shape            = rounded(5),
            bar_shape        = rounded(5),
            background_color = C.surface0,
            color            = C.mauve,
            widget           = wibox.widget.progressbar,
        }
        local rotated = wibox.widget {
            base_bar,
            direction = "west",
            widget    = wibox.container.rotate,
        }
        sparkline_bars[i] = base_bar
        sparkline_row:add(rotated)

        local lbl = wibox.widget {
            markup = "<span foreground='" .. C.overlay0 .. "'>·</span>",
            widget = wibox.widget.textbox,
            align  = "center",
        }
        local lbl_cell = wibox.widget {
            lbl,
            forced_width = SPARK_CELL_W,
            widget = wibox.container.background,
        }
        sparkline_labels[i] = lbl
        cc_days_row:add(lbl_cell)
    end

    subscribe_claude(function(st)
        cc_5h_val:set_markup(
            "<span foreground='" .. C.text .. "' weight='bold'>" .. st.n5 .. "</span>")
        cc_week_val:set_markup(
            "<span foreground='" .. C.text .. "' weight='bold'>" .. st.n7 .. "</span>")

        -- Sparkline — set each bar's value as a fraction of the week's max.
        local max_val = 1
        for _, c in ipairs(st.days) do if c > max_val then max_val = c end end
        for i, c in ipairs(st.days) do
            sparkline_bars[i].max_value = max_val
            sparkline_bars[i].value     = c > 0 and c or 0
            sparkline_bars[i].color     = (i == 7) and C.mauve or C.blue
        end

        -- Day-of-week labels aligned with bars
        local now = os.time()
        local dow = {"S","M","T","W","T","F","S"}
        for i = 1, 7 do
            local day = os.date("*t", now - (7 - i) * 86400)
            local color = (i == 7) and C.mauve or C.overlay0
            local weight = (i == 7) and "bold" or "normal"
            sparkline_labels[i]:set_markup(
                "<span foreground='" .. color .. "' weight='" .. weight .. "'>" ..
                dow[day.wday] .. "</span>")
        end

    end)

    -- Big "today" hero number inside the tile
    local cc_today_big = wibox.widget {
        markup = "<span font='FiraCode Nerd Font 56' foreground='" .. C.text ..
                 "' weight='bold'>0</span>",
        widget = wibox.widget.textbox,
    }
    local cc_today_sub = wibox.widget {
        markup = "<span foreground='" .. C.subtext1 .. "'>messages today</span>",
        widget = wibox.widget.textbox,
    }

    local cc_spark_title = wibox.widget {
        markup = "<span foreground='" .. C.subtext1 .. "' weight='bold'>last 7 days</span>",
        widget = wibox.widget.textbox,
    }

    -- Stat footer (peak day + 7-day total + daily avg)
    local cc_footer_peak = wibox.widget {
        markup = "<span foreground='" .. C.subtext1 .. "'>peak · --</span>",
        widget = wibox.widget.textbox,
    }
    local cc_footer_total = wibox.widget {
        markup = "<span foreground='" .. C.subtext1 .. "'>week · --</span>",
        widget = wibox.widget.textbox,
    }
    local cc_footer_avg = wibox.widget {
        markup = "<span foreground='" .. C.subtext1 .. "'>avg · --</span>",
        widget = wibox.widget.textbox,
    }

    subscribe_claude(function(st)
        cc_today_big:set_markup(
            "<span font='FiraCode Nerd Font 56' foreground='" .. C.text ..
            "' weight='bold'>" .. st.today .. "</span>")

        local peak = 0
        for _, c in ipairs(st.days) do if c > peak then peak = c end end
        local avg = math.floor(st.n7 / 7 + 0.5)

        local function stat(label, val, color)
            return "<span foreground='" .. C.overlay0 .. "'>" .. label .. "</span>" ..
                   "  <span foreground='" .. (color or C.text) .. "' weight='bold'>" ..
                   val .. "</span>"
        end
        cc_footer_peak:set_markup(stat("peak",  peak,   C.mauve))
        cc_footer_total:set_markup(stat("week", st.n7,  C.blue))
        cc_footer_avg:set_markup(stat("avg",   avg,    C.green))
    end)

    local CC_W = 440
    local CC_H = 664  -- spans hero + gap + neofetch
    local cc_tile = make_tile(CC_W, CC_H)

    local function section_divider(top_m, bot_m)
        return wibox.widget {
            {
                bg = C.surface0, forced_height = 1,
                widget = wibox.container.background,
            },
            top = top_m or 12, bottom = bot_m or 12,
            widget = wibox.container.margin,
        }
    end

    cc_tile:setup {
        {
            {
                -- Header
                { cc_title,   forced_height = 24, widget = wibox.container.background },

                -- Huge today count
                { cc_today_big, top = 10, widget = wibox.container.margin },
                { cc_today_sub, top = 2,  widget = wibox.container.margin },

                section_divider(16, 14),

                -- Rolling-window entry counts (local JSONL only)
                cc_5h_row,
                cc_week_row,

                section_divider(18, 10),

                -- Chart title
                { cc_spark_title, forced_height = 20, widget = wibox.container.background },
                -- Tall sparkline
                { sparkline_row,  top = 6, widget = wibox.container.margin },
                { cc_days_row,    top = 6, widget = wibox.container.margin },

                section_divider(18, 10),

                -- Stat footer (peak / week total / daily avg)
                {
                    cc_footer_peak,
                    cc_footer_total,
                    cc_footer_avg,
                    spacing = 16,
                    layout  = wibox.layout.flex.horizontal,
                },

                spacing = 0,
                layout  = wibox.layout.fixed.vertical,
            },
            halign = "left",
            valign = "top",
            widget = wibox.container.place,
        },
        margins = 24,
        widget  = wibox.container.margin,
    }

    ---------------------------------------------------------------
    -- Tile placement — L-shaped cluster on the left side:
    --   hero (top-left) ──  claude (right of both,
    --   neo  (below hero) ─   spanning hero + neo height)
    ---------------------------------------------------------------
    local function place_tiles()
        local g = s.geometry
        local wibar_h = (s.mywibox and s.mywibox.height or 50) + 12
        local m = 22
        local gap = 14
        local top = g.y + wibar_h + 10

        hero_tile.x = g.x + m
        hero_tile.y = top

        neo_tile.x = hero_tile.x
        neo_tile.y = hero_tile.y + hero_tile.height + gap

        -- Claude sits to the right of the hero+neo column, same top as hero.
        local left_col_width = math.max(HERO_W, NEO_W)
        cc_tile.x = hero_tile.x + left_col_width + gap
        cc_tile.y = hero_tile.y
    end
    place_tiles()
    s:connect_signal("property::geometry", place_tiles)

end)
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "F1",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),

    -- Hardware / media keys (volume via pactl to match the wibar widget)
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

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- Autostart
-- Wallpaper: if the "video_wallpaper" marker file exists, use the looping
-- video wallpaper (which itself falls back to a still image when unsuitable);
-- otherwise set a random still image via feh.
do
    local marker = os.getenv("HOME") .. "/.config/awesome/video_wallpaper"
    local f = io.open(marker, "r")
    if f then
        f:close()
        awful.spawn.with_shell(
            os.getenv("HOME") .. "/.config/awesome/scripts/wallpaper-video.sh")
    else
        awful.spawn.with_shell("feh --randomize --bg-fill ~/Media/wallpapers/*")
    end
end
awful.spawn.with_shell("pkill -x picom; picom --config " .. os.getenv("HOME") .. "/.config/awesome/picom.conf")
awful.spawn.with_shell("pgrep -x flameshot >/dev/null || flameshot &")

-- Apply dark GTK/system color scheme for other apps (Brave, GTK-based tools)
awful.spawn.with_shell(
    "mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0 && " ..
    "printf '[Settings]\\ngtk-theme-name=Adwaita-dark\\ngtk-application-prefer-dark-theme=1\\n' " ..
    "| tee ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini >/dev/null; " ..
    "gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null; " ..
    "gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null; true"
)
