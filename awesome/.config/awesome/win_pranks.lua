-- Fake Windows screens (pranks). Dismiss any of them with Escape.
--   M.update()  -- "Working on updates" screen
--   M.bsod()    -- blue screen of death (does NOT crash anything)
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local M = {}

local overlay, timer, grabber

local function close()
    if timer then timer:stop(); timer = nil end
    if grabber then awful.keygrabber.stop(grabber); grabber = nil end
    if overlay then overlay.visible = false; overlay = nil end
end

-- Create a fullscreen overlay on the focused screen, show it, grab Escape.
local function open(bg, content)
    close()
    local s = awful.screen.focused()
    overlay = wibox({ ontop = true, visible = false, type = "splash" })
    overlay:geometry(s.geometry)
    overlay.bg = bg
    overlay:set_widget(content)
    overlay.visible = true
    grabber = awful.keygrabber.run(function(_, key, event)
        if event == "press" and key == "Escape" then close() end
    end)
    return s
end

local function tb(markup, align)
    return wibox.widget {
        markup = markup, align = align or "left", widget = wibox.widget.textbox,
    }
end

-- "Working on updates" screen (matches the Win10 update look).
function M.update()
    local s = awful.screen.focused()
    local pct = math.random(8, 35)
    local function fmt(p) return "<span font='Noto Sans 22' foreground='#ffffff'>" .. p .. "% complete</span>" end
    local pct_tb = tb(fmt(pct), "center")

    local content = wibox.widget {
        nil,
        {
            tb("<span font='Noto Sans 22' foreground='#ffffff'>Working on updates</span>", "center"),
            pct_tb,
            tb("<span font='Noto Sans 22' foreground='#ffffff'>Don't turn off your computer</span>", "center"),
            spacing = 12,
            layout  = wibox.layout.fixed.vertical,
        },
        nil,
        expand = "outside",
        layout = wibox.layout.align.vertical,
    }

    local bg = gears.color({
        type = "linear", from = { 0, 0 }, to = { 0, s.geometry.height },
        stops = { { 0, "#1773b8" }, { 1, "#2f97d4" } },   -- blue gradient
    })
    open(bg, content)
    timer = gears.timer { timeout = 1.3, autostart = true, callback = function()
        pct = math.min(99, pct + 1)
        pct_tb:set_markup(fmt(pct))
    end }
end

-- Blue Screen of Death (Win10/11 style). Purely cosmetic.
function M.bsod()
    local codes = {
        "CRITICAL_PROCESS_DIED", "IRQL_NOT_LESS_OR_EQUAL",
        "PAGE_FAULT_IN_NONPAGED_AREA", "SYSTEM_SERVICE_EXCEPTION",
        "KERNEL_SECURITY_CHECK_FAILURE", "MEMORY_MANAGEMENT",
    }
    local code = codes[math.random(#codes)]
    local pct = math.random(0, 15)
    local function fmt(p) return "<span font='Noto Sans 18' foreground='#ffffff'>" .. p .. "% complete</span>" end
    local pct_tb = tb(fmt(pct))

    local block = wibox.widget {
        tb("<span font='Noto Sans 96' foreground='#ffffff'>:(</span>"),
        tb("<span font='Noto Sans 17' foreground='#ffffff'>Your PC ran into a problem and needs to restart. We're\n"
            .. "just collecting some error info, and then we'll restart\nfor you.</span>"),
        pct_tb,
        tb("<span font='Noto Sans 11' foreground='#dbe7f4'>For more information about this issue and possible fixes, visit\n"
            .. "https://www.windows.com/stopcode\n\n"
            .. "If you call a support person, give them this info:\n"
            .. "Stop code: " .. code .. "</span>"),
        spacing = 22,
        layout  = wibox.layout.fixed.vertical,
    }

    local content = wibox.widget {
        nil,
        {
            { block, left = 140, right = 140, widget = wibox.container.margin },
            layout = wibox.layout.fixed.horizontal,
        },
        nil,
        expand = "outside",
        layout = wibox.layout.align.vertical,
    }

    open("#0078d7", content)   -- solid BSOD blue
    timer = gears.timer { timeout = 0.8, autostart = true, callback = function()
        pct = math.min(100, pct + 1)
        pct_tb:set_markup(fmt(pct))
    end }
end

return M
