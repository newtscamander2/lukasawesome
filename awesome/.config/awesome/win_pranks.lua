-- Fake Windows screens (pranks), for your own amusement on your own machine.
--   M.update()    -- "Working on updates" screen
--   M.bsod()      -- blue screen of death (does NOT crash anything)
--   M.wannacry()  -- Wana Decrypt0r lookalike (encrypts NOTHING; it is a wibox)
--
-- Each one only ever draws pixels: no filesystem, no network, no persistence.
--
-- SAFETY (learned the hard way — an earlier version trapped a live session).
-- Three independent ways out, and none of them depend on this file being
-- bug-free:
--   * NO keyboard grab. This is the one that matters. Your keybindings keep
--     working while an overlay is up, so Super+Shift+<key> always toggles it
--     away and nothing can swallow your input even if the code below breaks.
--   * A click anywhere — on the fake window or the invisible full-screen
--     layer over the rest of the desktop — closes it.
--   * M.close() / M.is_open() are exported, so `awesome-client
--     'require("win_pranks").close()'` works from any other machine or tty.
-- There is deliberately NO auto-close timer: an overlay that vanishes on its
-- own is not convincing, and the three routes above do not need a backstop.
local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")

local M = {}

-- All shared state declared ONCE, before any function that touches it — an
-- earlier version declared `backdrop` after close(), so close() silently
-- referenced a nil global and left the backdrop covering the screen forever.
local overlay, backdrop, timer

local function close()
    if timer    then timer:stop();    timer = nil    end
    -- pcall so a widget error can never leave a layer stuck on screen.
    if overlay  then pcall(function() overlay.visible  = false end); overlay  = nil end
    if backdrop then pcall(function() backdrop.visible = false end); backdrop = nil end
end

function M.is_open() return overlay ~= nil or backdrop ~= nil end

-- Click-to-close on every layer. Deliberately no keygrabber: grabbing the
-- keyboard is what made a bug here catastrophic, and no auto-close timer,
-- because an overlay that disappears by itself is not convincing.
local function arm_dismissal(...)
    local click = gears.table.join(
        awful.button({}, 1, close),
        awful.button({}, 2, close),
        awful.button({}, 3, close))
    for _, w in ipairs({ ... }) do
        if w then w:buttons(click) end
    end
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

    -- A full-screen INVISIBLE layer, not a dimmer. Its only job is to catch a
    -- click anywhere outside the fake window.
    --
    -- type = "dnd" is load-bearing: picom blurs whatever sits behind any
    -- window it is not told to skip, so a full-screen transparent layer fogged
    -- the entire desktop. Nothing else uses the dnd type, and every picom
    -- config here excludes it from blur and shadow.
    backdrop = wibox({ ontop = true, visible = false, type = "dnd" })
    backdrop:geometry(s.geometry)
    backdrop.bg = "#00000000"
    backdrop.visible = true

    overlay = wibox({
        ontop        = true,
        visible      = false,
        type         = "splash",
        bg           = "#8b1414",
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

-- Wana Decrypt0r 2.0 lookalike. Purely cosmetic: it reads nothing, writes
-- nothing, sends nothing and survives nothing. Every colour and proportion
-- below was sampled from a screenshot of the real thing rather than guessed —
-- the body red is #8b1414, not the bright #c11f1f an eyeball picks.
--
-- The bitcoin address is DELIBERATELY not the real one. WannaCry's actual
-- wallet is public, and a believable window plus a working address is how a
-- prank turns into someone actually sending money to criminals. Same length,
-- same base58 shape, different characters: identical at a glance, inert.
function M.wannacry()
    -- Sampled from the reference screenshot.
    local RED        = "#8b1414"   -- body and panel fill
    local FRAME      = "#7c0707"   -- window frame
    local TILE_RED   = "#a51e1e"   -- lock tile, one step lighter than the body
    local EDGE       = "#c98a8a"   -- the 1px light rule around every panel
    local TITLE_BG   = "#d5868c"   -- Windows titlebar, red-tinted
    local TITLE_FG   = "#3d2b2b"   -- title text is DARK, not white
    local CLOSE_BG   = "#c0392b"
    local GOLD       = "#ffd700"
    local LINK       = "#7ec8e8"
    local DIGITS     = "#dbb6b7"   -- countdown digits: dusty pink, not white
    local PAPER      = "#ffffff"
    local INK        = "#000000"
    local BTN_FACE   = "#f2f2f2"
    local BTN_EDGE   = "#9a8080"
    local SB_TRACK   = "#c3c1be"
    local SB_THUMB   = "#aaa8a8"
    local LOGO_BG    = "#c8c8c8"
    local ORANGE     = "#f7931a"

    local W, H     = 800, 600      -- the original's window size
    local LEFT_W   = 226

    -- The dates are the real ones from the 2017 screenshots, so the window is
    -- internally consistent; the countdowns tick from now.
    local t_pay  = os.time() + 3 * 86400 - 1
    local t_lost = os.time() + 7 * 86400 - 1

    local function countdown(deadline)
        local left = math.max(0, deadline - os.time())
        return string.format("%02d:%02d:%02d:%02d",
            math.floor(left / 86400), math.floor(left % 86400 / 3600),
            math.floor(left % 3600 / 60), left % 60)
    end

    local function span(text, colour, font, extra)
        return "<span font='" .. font .. "' foreground='" .. colour .. "'" ..
               (extra or "") .. ">" .. text .. "</span>"
    end

    -- A solid block that ACTUALLY paints. A childless container.background
    -- draws nothing (its bg comes from before_draw_children, which never runs
    -- without children), so every one of these carries an empty textbox.
    local function block(colour, w, h)
        return wibox.widget {
            { text = "", widget = wibox.widget.textbox },
            forced_width  = w,
            forced_height = h,
            bg            = colour,
            widget        = wibox.container.background,
        }
    end

    -- A bordered panel: 1px light rule, red fill, like every box in the original.
    local function panel(child, pad)
        return wibox.widget {
            { child, margins = pad or 6, widget = wibox.container.margin },
            bg                 = RED,
            shape              = gears.shape.rectangle,
            shape_border_width = 1,
            shape_border_color = EDGE,
            widget             = wibox.container.background,
        }
    end

    ---------------------------------------------------------------
    -- The padlock, drawn rather than shipped: an emoji lock renders as a
    -- colour glyph on this system, and the original is a flat white lock.
    ---------------------------------------------------------------
    local function padlock(size)
        local w = wibox.widget.base.make_widget()
        function w:fit() return size, size end
        function w:draw(_, cr, width, height)
            local cx = width / 2
            local body_top = height * 0.50
            cr:set_source(gears.color("#ffffff"))
            -- Shackle. Its centre sits just BELOW the body's top edge so the
            -- two legs end inside the body: centred above it, the legs stop
            -- short and the lock reads as open, which is the opposite of the
            -- point.
            cr:set_line_width(width * 0.13)
            cr:arc(cx, body_top + height * 0.02, width * 0.21, math.pi, 2 * math.pi)
            cr:stroke()
            -- body
            local bw, bh = width * 0.62, height * 0.38
            cr:save()
            cr:translate(cx - bw / 2, body_top)
            gears.shape.rounded_rect(cr, bw, bh, width * 0.035)
            cr:restore()
            cr:fill()
            -- keyhole, punched in the tile's own red: circle plus a short slot
            cr:set_source(gears.color(TILE_RED))
            cr:arc(cx, body_top + bh * 0.34, width * 0.055, 0, 2 * math.pi)
            cr:fill()
            cr:save()
            cr:translate(cx - width * 0.024, body_top + bh * 0.34)
            gears.shape.rectangle(cr, width * 0.048, bh * 0.42)
            cr:restore()
            cr:fill()
        end
        return w
    end

    ---------------------------------------------------------------
    -- Title bar
    ---------------------------------------------------------------
    local titlebar = wibox.widget {
        {
            {
                { padlock(15), valign = "center", widget = wibox.container.place },
                left = 5, right = 5, top = 3, bottom = 3,
                widget = wibox.container.margin,
            },
            tb(span("Wana Decrypt0r 2.0", TITLE_FG, "Noto Sans 10"), "center"),
            {
                {
                    tb(span("\u{2715}", "#ffffff", "Noto Sans 9"), "center"),
                    forced_width = 26, forced_height = 17,
                    bg = CLOSE_BG,
                    shape_border_width = 1, shape_border_color = "#8f2418",
                    widget = wibox.container.background,
                },
                right = 3, top = 3, bottom = 3, left = 3,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.align.horizontal,
        },
        bg     = TITLE_BG,
        widget = wibox.container.background,
    }

    ---------------------------------------------------------------
    -- Left column
    ---------------------------------------------------------------
    local lock_tile = wibox.widget {
        {
            { padlock(96), halign = "center", valign = "center",
              widget = wibox.container.place },
            margins = 6,
            widget  = wibox.container.margin,
        },
        forced_height      = 120,
        bg                 = {
            type = "linear", from = { 0, 0 }, to = { 0, 120 },
            stops = { { 0, "#9c1c1c" }, { 0.45, "#b32424" }, { 1, "#a01e1e" } },
        },
        shape_border_width = 1,
        shape_border_color = "#e8d0d0",
        widget             = wibox.container.background,
    }

    local pay_tb  = tb(span(countdown(t_pay),  DIGITS, "DejaVu Sans Mono Bold 15"), "center")
    local lost_tb = tb(span(countdown(t_lost), DIGITS, "DejaVu Sans Mono Bold 15"), "center")

    local function timer_panel(title, when, value_tb)
        return panel(wibox.widget {
            {
                tb(span(title, GOLD, "Noto Sans Bold 10"), "center"),
                { tb(span(when, "#ffffff", "Noto Sans 9"), "center"),
                  top = 10, widget = wibox.container.margin },
                { tb(span("Time Left", "#ffffff", "Noto Sans 9"), "center"),
                  top = 12, widget = wibox.container.margin },
                { value_tb, top = 4, widget = wibox.container.margin },
                layout = wibox.layout.fixed.vertical,
            },
            nil,
            -- The green-to-red strip sits at the panel's right edge, spanning
            -- the date and countdown rows only.
            {
                {
                    { text = "", widget = wibox.widget.textbox },
                    forced_width  = 11,
                    forced_height = 76,
                    bg = {
                        type = "linear", from = { 0, 0 }, to = { 0, 76 },
                        stops = { { 0, "#22c722" }, { 0.45, "#c9c020" },
                                  { 1, "#c62020" } },
                    },
                    widget = wibox.container.background,
                },
                top = 26, left = 6,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.align.horizontal,
        }, 8)
    end

    local function link(text, font)
        return tb(span(text, LINK, font or "Noto Sans 9", " underline='single'"))
    end

    local left_col = wibox.widget {
        lock_tile,
        { timer_panel("Payment will be raised on", "5/16/2017 00:47:55", pay_tb),
          top = 12, widget = wibox.container.margin },
        { timer_panel("Your files will be lost on", "5/20/2017 00:47:55", lost_tb),
          top = 10, widget = wibox.container.margin },
        {
            {
                link("About bitcoin"),
                { link("How to buy bitcoins?"), top = 10,
                  widget = wibox.container.margin },
                { link("Contact Us", "Noto Sans Bold 13"), top = 16,
                  widget = wibox.container.margin },
                layout = wibox.layout.fixed.vertical,
            },
            top = 16, left = 2,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.fixed.vertical,
    }

    ---------------------------------------------------------------
    -- Right column: heading, the white paper, the bitcoin bar, buttons
    ---------------------------------------------------------------
    local function head(t)
        return tb(span(t, INK, "Noto Sans Bold 13"))
    end
    local function para(t)
        local w = tb(span(t, INK, "Noto Sans 9"))
        w.wrap = "word_char"
        return w
    end

    -- Faked scrollbar: the original's text pane is scrolled, and the trough on
    -- its right edge is one of those details you notice by its absence.
    -- The TRACK is the outer background, so it fills the pane's full height;
    -- the arrow stub and thumb stack at the top inside it. Built as one
    -- background rather than an align.vertical: the track needs to stretch, and
    -- a 3-slot align with a trailing nil is the constructor trap that gives an
    -- ambiguous array length.
    local scrollbar = wibox.widget {
        {
            block("#8f8f8f", 14, 13),
            {
                block(SB_THUMB, 12, 130),
                top = 1, left = 1, right = 1,
                widget = wibox.container.margin,
            },
            layout = wibox.layout.fixed.vertical,
        },
        forced_width = 14,
        bg           = SB_TRACK,
        widget       = wibox.container.background,
    }

    local paper_text = wibox.widget {
        {
            head("What Happened to My Computer?"),
            { para("Your important files are encrypted."),
              top = 6, widget = wibox.container.margin },
            { para("Many of your documents, photos, videos, databases and other files " ..
              "are no longer accessible because they have been encrypted. Maybe you " ..
              "are busy looking for a way to recover your files, but do not waste " ..
              "your time. Nobody can recover your files without our decryption service."),
              top = 2, widget = wibox.container.margin },
            { head("Can I Recover My Files?"), top = 14,
              widget = wibox.container.margin },
            { para("Sure. We guarantee that you can recover all your files safely and " ..
              "easily. But you have not so enough time."),
              top = 6, widget = wibox.container.margin },
            { para("You can decrypt some of your files for free. Try now by clicking &lt;Decrypt&gt;.\n" ..
              "But if you want to decrypt all your files, you need to pay.\n" ..
              "You only have 3 days to submit the payment. After that the price will be doubled.\n" ..
              "Also, if you don't pay in 7 days, you won't be able to recover your files forever.\n" ..
              "We will have free events for users who are so poor that they couldn't pay in 6 months."),
              top = 2, widget = wibox.container.margin },
            { head("How Do I Pay?"), top = 14,
              widget = wibox.container.margin },
            { para("Payment is accepted in Bitcoin only. For more information, click &lt;About bitcoin&gt;.\n" ..
              "Please check the current price of Bitcoin and buy some bitcoins. For more " ..
              "information, click &lt;How to buy bitcoins&gt;.\n" ..
              "And send the correct amount to the address specified in this window.\n" ..
              "After your payment, click &lt;Check Payment&gt;. Best time to check: 9:00am - 11:00am"),
              top = 6, widget = wibox.container.margin },
            layout = wibox.layout.fixed.vertical,
        },
        margins = 12,
        widget  = wibox.container.margin,
    }

    -- align.horizontal's MIDDLE slot is the one that absorbs slack, and the
    -- text pane's natural width is unbounded — declared as {text, scrollbar}
    -- the text became the middle and squeezed the scrollbar to zero width.
    -- Built imperatively because putting the text in the middle declaratively
    -- needs a leading nil, which makes the array length ambiguous.
    local paper_row = wibox.layout.align.horizontal()
    paper_row:set_middle(paper_text)
    paper_row:set_third(scrollbar)

    local paper = wibox.widget {
        paper_row,
        bg     = PAPER,
        widget = wibox.container.background,
    }

    -- Bitcoin logo: orange disc, white B, wordmark. Drawn, so the module keeps
    -- shipping zero assets.
    local btc_disc = wibox.widget.base.make_widget()
    function btc_disc:fit() return 34, 34 end
    function btc_disc:draw(_, cr, width, height)
        cr:set_source(gears.color(ORANGE))
        cr:arc(width / 2, height / 2, math.min(width, height) / 2 - 1, 0, 2 * math.pi)
        cr:fill()
    end
    local btc_logo = wibox.widget {
        {
            {
                {
                    { btc_disc, valign = "center", widget = wibox.container.place },
                    tb(span("B", "#ffffff", "Noto Serif Bold 15"), "center"),
                    layout = wibox.layout.stack,
                },
                {
                    {
                        tb(span("bitcoin", "#2b2b2b", "Noto Serif Bold 15")),
                        tb(span("ACCEPTED HERE", "#4a4a4a", "Noto Sans Italic 7")),
                        layout = wibox.layout.fixed.vertical,
                    },
                    left = 5,
                    widget = wibox.container.margin,
                },
                layout = wibox.layout.fixed.horizontal,
            },
            margins = 6,
            widget  = wibox.container.margin,
        },
        bg     = LOGO_BG,
        widget = wibox.container.background,
    }

    local address = wibox.widget {
        {
            tb(span("1Mz7ULfKk8LqYtNVGjW4pRsc2XbAd9eQhT", "#101010",
                    "Noto Sans Bold 11")),
            left = 8, right = 8, top = 6, bottom = 6,
            widget = wibox.container.margin,
        },
        bg                 = "#ffffff",
        shape_border_width = 1,
        shape_border_color = "#8a6a6a",
        widget             = wibox.container.background,
    }

    local copy_btn = wibox.widget {
        {
            tb(span("Copy", "#101010", "Noto Sans 9"), "center"),
            left = 6, right = 6, top = 6, bottom = 6,
            widget = wibox.container.margin,
        },
        bg                 = BTN_FACE,
        shape_border_width = 1,
        shape_border_color = BTN_EDGE,
        widget             = wibox.container.background,
    }

    local btc_bar = panel(wibox.widget {
        { btc_logo, valign = "center", widget = wibox.container.place },
        {
            {
                tb(span("Send $300 worth of bitcoin to this address:", GOLD,
                        "Noto Sans Bold 11")),
                {
                    {
                        address,
                        nil,
                        { copy_btn, left = 4, widget = wibox.container.margin },
                        layout = wibox.layout.align.horizontal,
                    },
                    top = 6,
                    widget = wibox.container.margin,
                },
                layout = wibox.layout.fixed.vertical,
            },
            left = 10,
            widget = wibox.container.margin,
        },
        nil,
        layout = wibox.layout.align.horizontal,
    }, 6)

    -- The accelerator underline on P and D is in the original.
    local function button(markup)
        return wibox.widget {
            {
                tb(span(markup, "#101010", "Noto Sans 12"), "center"),
                top = 7, bottom = 7,
                widget = wibox.container.margin,
            },
            bg                 = BTN_FACE,
            shape_border_width = 1,
            shape_border_color = BTN_EDGE,
            widget             = wibox.container.background,
        }
    end
    local buttons_row = wibox.widget {
        button("Check <u>P</u>ayment"),
        button("<u>D</u>ecrypt"),
        spacing = 14,
        layout  = wibox.layout.flex.horizontal,
    }

    local right_col = wibox.widget {
        {
            {
                nil,
                tb(span("Ooops, your files have been encrypted!", "#ffffff",
                        "Noto Sans Bold 15"), "center"),
                {
                    {
                        {
                            tb(span("English", "#101010", "Noto Sans 9")),
                            nil,
                            tb(span("\u{25be}", "#101010", "Noto Sans 7"), "right"),
                            layout = wibox.layout.align.horizontal,
                        },
                        left = 6, right = 4, top = 3, bottom = 3,
                        widget = wibox.container.margin,
                    },
                    forced_width       = 96,
                    bg                 = "#ffffff",
                    shape_border_width = 1,
                    shape_border_color = "#8a6a6a",
                    widget             = wibox.container.background,
                },
                layout = wibox.layout.align.horizontal,
            },
            bottom = 8,
            widget = wibox.container.margin,
        },
        paper,
        {
            {
                btc_bar,
                { buttons_row, top = 8, widget = wibox.container.margin },
                layout = wibox.layout.fixed.vertical,
            },
            top = 8,
            widget = wibox.container.margin,
        },
        layout = wibox.layout.align.vertical,
    }

    local body = wibox.widget {
        {
            { left_col, forced_width = LEFT_W, widget = wibox.container.margin },
            { right_col, left = 10, widget = wibox.container.margin },
            layout = wibox.layout.align.horizontal,
        },
        margins = 8,
        widget  = wibox.container.margin,
    }

    local content = wibox.widget {
        titlebar,
        body,
        nil,
        layout = wibox.layout.align.vertical,
    }

    open_window(W, H, content, FRAME)
    timer = gears.timer { timeout = 1, autostart = true, callback = function()
        pay_tb:set_markup(span(countdown(t_pay),  DIGITS, "DejaVu Sans Mono Bold 15"))
        lost_tb:set_markup(span(countdown(t_lost), DIGITS, "DejaVu Sans Mono Bold 15"))
    end }
end

M.close = close

return M
