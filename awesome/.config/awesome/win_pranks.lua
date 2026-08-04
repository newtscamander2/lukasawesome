-- Fake Windows screens (pranks), for your own amusement on your own machine.
--   M.update()    -- "Working on updates" screen
--   M.bsod()      -- blue screen of death (does NOT crash anything)
--   M.wannacry()  -- Wana Decrypt0r lookalike (encrypts NOTHING; it is a wibox)
--
-- Each one only ever draws pixels: no filesystem, no network, no persistence.
--
-- SAFETY (learned the hard way — an earlier version trapped a live session):
--   * NO keyboard grab. Your keybindings keep working while an overlay is up,
--     so Super+Shift+<key> can always toggle it away and nothing can swallow
--     your input even if this file has a bug.
--   * A click anywhere on the overlay (or its backdrop) closes it.
--   * A 20 s failsafe timer closes it unconditionally.
--   * M.close() / M.is_open() are exported, so `awesome-client
--     'require("win_pranks").close()'` is always an escape hatch.
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local M = {}

-- All shared state declared ONCE, before any function that touches it — an
-- earlier version declared `backdrop` after close(), so close() silently
-- referenced a nil global and left the backdrop covering the screen forever.
local overlay, backdrop, timer, failsafe

local function close()
    if timer    then timer:stop();    timer = nil    end
    if failsafe then failsafe:stop(); failsafe = nil end
    -- pcall so a widget error can never leave a layer stuck on screen.
    if overlay  then pcall(function() overlay.visible  = false end); overlay  = nil end
    if backdrop then pcall(function() backdrop.visible = false end); backdrop = nil end
end

function M.is_open() return overlay ~= nil or backdrop ~= nil end

-- Click-to-close on every layer + an unconditional failsafe. Deliberately no
-- keygrabber: grabbing the keyboard is what made a bug here catastrophic.
local function arm_dismissal(...)
    local click = gears.table.join(
        awful.button({}, 1, close),
        awful.button({}, 2, close),
        awful.button({}, 3, close))
    for _, w in ipairs({ ... }) do
        if w then w:buttons(click) end
    end
    failsafe = gears.timer {
        timeout = 20, single_shot = true, autostart = true, callback = close,
    }
end

local function hint_widget()
    return wibox.widget {
        nil, nil,
        {
            {
                markup = "<span font='Noto Sans 10' foreground='#ffffffcc'>" ..
                         "click anywhere, press Super+Shift+W, or wait 20s to close" ..
                         "</span>",
                align  = "center",
                widget = wibox.widget.textbox,
            },
            bottom = 14,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.align.vertical,
    }
end

-- Fullscreen overlay (update / bsod).
local function open(bg, content)
    close()
    local s = awful.screen.focused()
    overlay = wibox({ ontop = true, visible = false, type = "splash" })
    overlay:geometry(s.geometry)
    overlay.bg = bg
    overlay:set_widget(content)
    overlay.visible = true
    arm_dismissal(overlay)
    return s
end

-- Centred fake application window on a dimmed backdrop (wannacry).
local function open_window(w, h, content, border)
    close()
    local s = awful.screen.focused()

    backdrop = wibox({ ontop = true, visible = false, type = "splash" })
    backdrop:geometry(s.geometry)
    backdrop.bg = "#00000099"
    -- Exit hint lives on the backdrop, outside the fake window, so the mock
    -- itself stays screenshot-clean while the way out is always visible.
    backdrop:set_widget(hint_widget())
    backdrop.visible = true

    overlay = wibox({
        ontop        = true,
        visible      = false,
        type         = "splash",
        bg           = "#c11f1f",
        border_width = 1,
        border_color = border or "#7a0c0c",
    })
    overlay:geometry({
        x = s.geometry.x + math.floor((s.geometry.width  - w) / 2),
        y = s.geometry.y + math.floor((s.geometry.height - h) / 2),
        width = w, height = h,
    })
    overlay:set_widget(content)
    overlay.visible = true

    arm_dismissal(overlay, backdrop)
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

-- Wana Decrypt0r 2.0 lookalike: a faithful mock of the 2017 window, purely
-- cosmetic. It reads nothing, writes nothing, sends nothing and survives
-- nothing — Escape closes it and the machine is exactly as it was.
function M.wannacry()
    local RED, RED_DK = "#c11f1f", "#a11414"
    local PANEL       = "#cf4444"   -- countdown panel fill
    local YELLOW      = "#ffe066"
    local WHITE       = "#ffffff"
    local PAPER       = "#f4f4f4"   -- right-hand text area
    local INK         = "#101010"

    local t_pay  = os.time() + 3 * 86400
    local t_lost = os.time() + 7 * 86400

    local function countdown(deadline)
        local left = math.max(0, deadline - os.time())
        return string.format("%02d:%02d:%02d:%02d",
            math.floor(left / 86400), math.floor(left % 86400 / 3600),
            math.floor(left % 3600 / 60), left % 60)
    end
    local function digits(t)
        return "<span font='FiraCode Nerd Font Bold 19' foreground='" .. WHITE .. "'>" .. t .. "</span>"
    end

    local pay_tb, lost_tb = tb(digits(countdown(t_pay)), "center"), tb(digits(countdown(t_lost)), "center")

    -- rounded box helper
    local function box(child, bg, radius, pad)
        return wibox.widget {
            { child, margins = pad or 8, widget = wibox.container.margin },
            bg     = bg,
            shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, radius or 3) end,
            widget = wibox.container.background,
        }
    end

    -- ---- title bar ---------------------------------------------------------
    local titlebar = wibox.widget {
        {
            {
                tb("<span font='Noto Sans 9' foreground='#f0c9c9'>\u{f023}</span>"),
                { tb("<span font='Noto Sans 9' foreground='" .. WHITE .. "'>Wana Decrypt0r 2.0</span>"),
                  left = 8, widget = wibox.container.margin },
                layout = wibox.layout.fixed.horizontal,
            },
            nil,
            tb("<span font='Noto Sans Bold 10' foreground='" .. WHITE .. "'>  \u{2715}  </span>", "right"),
            layout = wibox.layout.align.horizontal,
        },
        left = 8, right = 4, top = 4, bottom = 4,
        widget = wibox.container.margin,
    }

    -- ---- left column -------------------------------------------------------
    local lock_art = box(
        tb("<span font='Noto Sans 46' foreground='" .. WHITE .. "'>\u{1f512}</span>", "center"),
        "#d95757", 4, 14)

    local function timer_panel(title, deadline, value_tb)
        local body = wibox.widget {
            tb("<span font='Noto Sans Bold 9' foreground='" .. YELLOW .. "'>" .. title .. "</span>", "center"),
            { tb("<span font='Noto Sans 8' foreground='" .. WHITE .. "'>" ..
                 os.date("%d/%m/%Y %H:%M:%S", deadline) .. "</span>", "center"),
              top = 4, widget = wibox.container.margin },
            { tb("<span font='Noto Sans 8' foreground='" .. WHITE .. "'>Time Left</span>", "center"),
              top = 6, widget = wibox.container.margin },
            { value_tb, top = 2, widget = wibox.container.margin },
            layout = wibox.layout.fixed.vertical,
        }
        -- the little green->red gradient strip on the right of each panel
        local strip = wibox.widget {
            forced_width = 7,
            bg = {
                type = "linear", from = { 0, 0 }, to = { 0, 70 },
                stops = { { 0, "#39d353" }, { 0.55, "#e8d44d" }, { 1, "#d13b3b" } },
            },
            widget = wibox.container.background,
        }
        return box(wibox.widget {
            body, nil, strip,
            layout = wibox.layout.align.horizontal,
        }, PANEL, 3, 8)
    end

    local function link(text)
        return tb("<span font='Noto Sans 8' foreground='#dfe9ff' underline='single'>" .. text .. "</span>")
    end

    local left_col = wibox.widget {
        lock_art,
        { timer_panel("Payment will be raised on", t_pay,  pay_tb),  top = 10, widget = wibox.container.margin },
        { timer_panel("Your files will be lost on", t_lost, lost_tb), top = 8,  widget = wibox.container.margin },
        {
            {
                link("About bitcoin"),
                { link("How to buy bitcoins?"), top = 6, widget = wibox.container.margin },
                { tb("<span font='Noto Sans Bold 10' foreground='" .. WHITE ..
                     "' underline='single'>Contact Us</span>"), top = 10, widget = wibox.container.margin },
                layout = wibox.layout.fixed.vertical,
            },
            top = 14,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.vertical,
    }

    -- ---- right column ------------------------------------------------------
    local function head(t)
        return tb("<span font='Noto Sans Bold 12' foreground='" .. INK .. "'>" .. t .. "</span>")
    end
    local function para(t)
        local w = tb("<span font='Noto Sans 9' foreground='" .. INK .. "'>" .. t .. "</span>")
        w.wrap = "word_char"
        return w
    end

    local paper = wibox.widget {
        {
            {
                head("What Happened to My Computer?"),
                { para("Your important files are encrypted.\n" ..
                       "Many of your documents, photos, videos, databases and other files are no longer " ..
                       "accessible because they have been encrypted. Maybe you are busy looking for a way to " ..
                       "recover your files, but do not waste your time. Nobody can recover your files without " ..
                       "our decryption service."), top = 4, widget = wibox.container.margin },
                { head("Can I Recover My Files?"), top = 12, widget = wibox.container.margin },
                { para("Sure. We guarantee that you can recover all your files safely and easily. But you have " ..
                       "not so enough time.\n" ..
                       "You can decrypt some of your files for free. Try now by clicking <Decrypt>.\n" ..
                       "But if you want to decrypt all your files, you need to pay.\n" ..
                       "You only have 3 days to submit the payment. After that the price will be doubled.\n" ..
                       "Also, if you don't pay in 7 days, you won't be able to recover your files forever."),
                  top = 4, widget = wibox.container.margin },
                { head("How Do I Pay?"), top = 12, widget = wibox.container.margin },
                { para("Payment is accepted in Bitcoin only. For more information, click <About bitcoin>.\n" ..
                       "Please check the current price of Bitcoin and buy some bitcoins. For more information, " ..
                       "click <How to buy bitcoins>.\n" ..
                       "And send the correct amount to the address specified in this window.\n" ..
                       "After your payment, click <Check Payment>. Best time to check: 9:00am - 11:00am."),
                  top = 4, widget = wibox.container.margin },
                layout = wibox.layout.fixed.vertical,
            },
            margins = 12,
            widget  = wibox.container.margin,
        },
        bg     = PAPER,
        widget = wibox.container.background,
    }

    -- bitcoin bar
    local btc_bar = wibox.widget {
        {
            box(tb("<span font='Noto Sans Bold 13' foreground='#f7931a'>\u{20bf} bitcoin</span>\n" ..
                   "<span font='Noto Sans 7' foreground='#666666'>ACCEPTED HERE</span>", "center"),
                "#e6e6e6", 2, 6),
            {
                {
                    tb("<span font='Noto Sans Bold 9' foreground='" .. YELLOW ..
                       "'>Send $300 worth of bitcoin to this address:</span>"),
                    {
                        {
                            box(tb("<span font='FiraCode Nerd Font 10' foreground='#101010'>" ..
                                   "1PRANKnotREALbtcADDRESSxxxxxxxxxx</span>"), "#ffffff", 2, 5),
                            nil,
                            box(tb("<span font='Noto Sans 8' foreground='#101010'>Copy</span>", "center"),
                                "#e0e0e0", 2, 5),
                            layout = wibox.layout.align.horizontal,
                        },
                        top = 4,
                        widget = wibox.container.margin,
                    },
                    layout = wibox.layout.fixed.vertical,
                },
                left = 10,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.align.horizontal,
        },
        top = 8, bottom = 8,
        widget = wibox.container.margin,
    }

    local function button(label)
        return box(tb("<span font='Noto Sans 10' foreground='#101010'>" .. label .. "</span>", "center"),
                   "#e4e4e4", 2, 8)
    end
    local buttons_row = wibox.widget {
        button("Check Payment"),
        button("Decrypt"),
        spacing = 24,
        layout  = wibox.layout.flex.horizontal,
    }

    local right_col = wibox.widget {
        {
            {
                tb("<span font='Noto Sans Bold 13' foreground='" .. WHITE ..
                   "'>Ooops, your files have been encrypted!</span>", "center"),
                nil,
                box(tb("<span font='Noto Sans 8' foreground='#101010'>English  \u{25be}</span>"),
                    "#ededed", 2, 4),
                layout = wibox.layout.align.horizontal,
            },
            bottom = 8,
            widget = wibox.container.margin,
        },
        paper,
        btc_bar,
        buttons_row,
        layout = wibox.layout.align.vertical,
    }

    -- ---- assemble ----------------------------------------------------------
    local body = wibox.widget {
        {
            { left_col, forced_width = 250, widget = wibox.container.background },
            { right_col, left = 14, widget = wibox.container.margin },
            layout = wibox.layout.align.horizontal,
        },
        margins = 12,
        widget  = wibox.container.margin,
    }

    local content = wibox.widget {
        { titlebar, bg = RED_DK, widget = wibox.container.background },
        body,
        nil,
        layout = wibox.layout.align.vertical,
    }

    open_window(900, 660, content, "#7a0c0c")
    timer = gears.timer { timeout = 1, autostart = true, callback = function()
        pay_tb:set_markup(digits(countdown(t_pay)))
        lost_tb:set_markup(digits(countdown(t_lost)))
    end }
end

M.close = close

return M
