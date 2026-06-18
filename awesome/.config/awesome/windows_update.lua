-- Fake "Windows Update" fullscreen overlay (prank).
-- Show with the bound hotkey; dismiss with Escape.
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local M = {}

local overlay, timer, grabber
local pct, frame = 0, 1
-- Moving dot "spinner" using widely-supported geometric glyphs (no braille).
local FRAMES = {
    "●  ○  ○  ○  ○  ○",
    "○  ●  ○  ○  ○  ○",
    "○  ○  ●  ○  ○  ○",
    "○  ○  ○  ●  ○  ○",
    "○  ○  ○  ○  ●  ○",
    "○  ○  ○  ○  ○  ●",
}

local spinner_tb, pct_tb

local function make_overlay(s)
    local w = wibox({
        screen  = s,
        x = s.geometry.x, y = s.geometry.y,
        width = s.geometry.width, height = s.geometry.height,
        bg = "#0078D7", fg = "#ffffff",   -- classic Windows-Update blue
        ontop = true, visible = false, type = "splash",
    })
    spinner_tb = wibox.widget {
        markup = "", align = "center",
        font = "FiraCode Nerd Font 24", widget = wibox.widget.textbox,
    }
    pct_tb = wibox.widget {
        markup = "", align = "center", widget = wibox.widget.textbox,
    }
    w:setup {
        nil,
        {
            spinner_tb,
            {
                markup = "<span font='FiraCode Nerd Font 22'>Working on updates</span>",
                align = "center", widget = wibox.widget.textbox,
            },
            pct_tb,
            {
                markup = "<span font='FiraCode Nerd Font 11' foreground='#d6e6fb'>"
                    .. "Don't turn off your PC. This will take a while.</span>",
                align = "center", widget = wibox.widget.textbox,
            },
            spacing = 26,
            layout  = wibox.layout.fixed.vertical,
        },
        nil,
        expand = "outside",
        layout = wibox.layout.align.vertical,
    }
    return w
end

local function tick()
    frame = (frame % #FRAMES) + 1
    spinner_tb:set_markup("<span foreground='#ffffff'>" .. FRAMES[frame] .. "</span>")
    if frame == 1 then pct = (pct + 1) % 100 end
    pct_tb:set_markup(
        "<span font='FiraCode Nerd Font 16' foreground='#eaf2fd'>" .. pct .. "% complete</span>")
end

function M.show()
    local s = awful.screen.focused()
    if not overlay then overlay = make_overlay(s) end
    overlay.screen = s
    overlay:geometry(s.geometry)
    pct = math.random(0, 35)
    frame = 1
    overlay.visible = true
    if timer then timer:stop() end
    timer = gears.timer { timeout = 0.35, autostart = true, call_now = true, callback = tick }
    grabber = awful.keygrabber.run(function(_, key, event)
        if event == "press" and key == "Escape" then M.hide() end
    end)
end

function M.hide()
    if timer then timer:stop() end
    if grabber then awful.keygrabber.stop(grabber); grabber = nil end
    if overlay then overlay.visible = false end
end

return M
