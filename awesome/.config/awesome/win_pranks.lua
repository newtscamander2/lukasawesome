-- Fake Windows screens (pranks). Dismiss any of them with Escape.
--   M.update()    -- "Working on updates" screen
--   M.bsod()      -- blue screen of death (does NOT crash anything)
--   M.wannacry()  -- ransom-note lookalike (encrypts NOTHING; it is a wibox)
-- Every one of these is a picture: no filesystem, network or persistence.
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

-- Ransom-note lookalike. Draws a red overlay with two ticking countdowns —
-- and does absolutely nothing else. No file is read, written or touched.
function M.wannacry()
    local t_pay  = os.time() + 3 * 86400
    local t_lost = os.time() + 7 * 86400

    local function countdown(deadline)
        local left = math.max(0, deadline - os.time())
        return string.format("%02d:%02d:%02d:%02d",
            math.floor(left / 86400),
            math.floor(left % 86400 / 3600),
            math.floor(left % 3600 / 60),
            left % 60)
    end
    local function big(t)  return "<span font='Noto Sans Bold 26' foreground='#ffffff'>" .. t .. "</span>" end
    local function lbl(t)  return "<span font='Noto Sans 13' foreground='#ffd6d6'>" .. t .. "</span>" end
    local function date(t) return "<span font='Noto Sans 12' foreground='#ffffff'>" ..
                                  os.date("%d/%m/%Y %H:%M:%S", t) .. "</span>" end

    local pay_tb  = tb(big(countdown(t_pay)))
    local lost_tb = tb(big(countdown(t_lost)))

    local function panel(title, deadline, value_tb)
        return wibox.widget {
            tb(lbl(title)),
            { tb(date(deadline)), top = 2, widget = wibox.container.margin },
            { value_tb,           top = 6, widget = wibox.container.margin },
            layout = wibox.layout.fixed.vertical,
        }
    end

    local block = wibox.widget {
        tb("<span font='FiraCode Nerd Font 74' foreground='#ffffff'>\u{f023}</span>", "center"),
        tb("<span font='Noto Sans Bold 32' foreground='#ffffff'>Ooops, your files have been encrypted!</span>", "center"),
        {
            {
                panel("Payment will be raised on", t_pay,  pay_tb),
                panel("Your files will be lost on", t_lost, lost_tb),
                spacing = 60,
                layout  = wibox.layout.fixed.horizontal,
            },
            top = 10, bottom = 10,
            widget = wibox.container.margin,
        },
        tb("<span font='Noto Sans 13' foreground='#ffffff'>" ..
           "What happened to my computer?  Nothing at all — this is a prank overlay.\n" ..
           "Can I recover my files?  They were never touched. Press Escape.</span>"),
        tb("<span font='Noto Sans Bold 14' foreground='#f7931a'>Send $300 worth of bitcoin to this address:</span>  " ..
           "<span font='FiraCode Nerd Font 14' foreground='#ffffff'>1PRANKnotREALbTCaDDressXXXXXXXXXX</span>"),
        spacing = 20,
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

    open("#a30f0f", content)   -- WannaCry red
    timer = gears.timer { timeout = 1, autostart = true, callback = function()
        pay_tb:set_markup(big(countdown(t_pay)))
        lost_tb:set_markup(big(countdown(t_lost)))
    end }
end

return M
