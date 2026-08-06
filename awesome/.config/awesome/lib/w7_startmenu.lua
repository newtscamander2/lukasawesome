---------------------------------------------------------------
-- Windows 7 Start menu, built as a real widget tree.
--
-- Why not rofi: Win7's menu is TWO columns with different
-- backgrounds — a white program list on the left, a blue glass
-- link panel on the right, an avatar above it, and a split
-- "Shut down" button in the corner. rofi renders one list. No
-- amount of rasi gets you this shape, and the two-column layout
-- is most of what makes the menu recognisable.
--
-- Dismissal is a full-screen transparent backdrop that closes on
-- click, NOT a keygrabber. A keygrabber here could trap the
-- session if any error fired between grab and release, and that
-- has already happened once in this config.
---------------------------------------------------------------
local awful     = require("awful")
local gears     = require("gears")
local wibox     = require("wibox")
local beautiful = require("beautiful")
local dpi       = require("beautiful.xresources").apply_dpi

local M = {}

-- Geometry. Win7's menu is ~480x580 at 96dpi; the left column is the wider one.
local W_LEFT   = dpi(304)
local W_RIGHT  = dpi(196)
local H_MENU   = dpi(560)
local ROW_L    = dpi(32)   -- program row
local ROW_R    = dpi(27)   -- link row
local PAD      = dpi(8)

local C = {
    frame      = "#4a7fa5e6",
    left_bg    = "#fdfefff2",
    left_edge  = "#a8c8dd",
    right_bg   = "linear:0,0:0," .. H_MENU ..
                 ":0,#e2f0fbf2:0.5,#cfe4f4f2:1,#bcd8eef2",
    text       = "#0b3350",
    text_dim   = "#3f6a88",
    hover      = "linear:0,0:0," .. ROW_L ..
                 ":0,#e8f4fdff:0.5,#c9e5f8ff:1,#a9d3f0ff",
    hover_edge = "#7fb4d8",
    sep        = "#c2d8e6",
}

local function shape(r)
    return function(cr, w, h) gears.shape.rounded_rect(cr, w, h, r) end
end

-- One clickable row. `build` returns the row's inner widget so program rows
-- (icon + label) and link rows (label only) share all the hover plumbing.
local function row(inner, height, on_click, opts)
    opts = opts or {}
    local bg = wibox.widget {
        {
            inner,
            left = opts.left or dpi(10), right = dpi(8),
            widget = wibox.container.margin,
        },
        forced_height      = height,
        bg                 = "#00000000",
        shape              = shape(dpi(3)),
        shape_border_width = 1,
        shape_border_color = "#00000000",
        widget             = wibox.container.background,
    }
    bg:connect_signal("mouse::enter", function()
        bg.bg = C.hover
        bg.shape_border_color = C.hover_edge
    end)
    bg:connect_signal("mouse::leave", function()
        bg.bg = "#00000000"
        bg.shape_border_color = "#00000000"
    end)
    if on_click then
        bg:buttons(gears.table.join(awful.button({}, 1, on_click)))
    end
    return bg
end

local function label(text, colour, font, align)
    return wibox.widget {
        markup = "<span font='" .. (font or "Noto Sans 9") .. "' foreground='" ..
                 (colour or C.text) .. "'>" .. text .. "</span>",
        align  = align or "left",
        valign = "center",
        wrap   = "none", ellipsize = "end",
        widget = wibox.widget.textbox,
    }
end

local function hline(colour)
    return {
        orientation   = "horizontal",
        thickness     = 1,
        color         = colour,
        forced_height = 1,
        widget        = wibox.widget.separator,
    }
end

---------------------------------------------------------------
-- new(s, spec) -> { toggle, close, is_open }
--
-- spec.left  : { { icon = path, label = str, cmd = str|function }, ... }
-- spec.right : { { label = str, cmd = str|function }, ... }  (text only)
-- spec.user, spec.avatar, spec.home, spec.all_programs, spec.power, spec.search
---------------------------------------------------------------
function M.new(s, spec)
    local self = { screen = s, open = false }

    -- Backdrop is created FIRST so the menu stacks above it. It is fully
    -- transparent: its only job is to catch the click that dismisses.
    --
    -- type = "dnd" is not cosmetic. picom blurs whatever is behind ANY window
    -- it is not told to skip, and a fullscreen transparent window means it
    -- blurred the entire desktop the moment the menu opened. No other surface
    -- uses the dnd type, so picom-windows7.conf excludes exactly this window
    -- from blur and shadow.
    local backdrop = wibox({
        screen = s, visible = false, ontop = true, type = "dnd",
        bg = "#00000000",
        x = s.geometry.x, y = s.geometry.y,
        width = s.geometry.width, height = s.geometry.height,
    })

    local menu = wibox({
        screen  = s,
        width   = W_LEFT + W_RIGHT,
        height  = H_MENU,
        visible = false,
        ontop   = true,
        type    = "popup_menu",
        bg      = C.frame,
        shape   = shape(dpi(6)),
        border_width = 1,
        border_color = "#7fb0d0",
    })

    function self.close()
        self.open = false
        menu.visible = false
        backdrop.visible = false
    end

    local function launch(cmd)
        self.close()
        if type(cmd) == "function" then cmd() else awful.spawn(cmd) end
    end

    ---------------------------------------------------------------
    -- Left column: program list, All Programs, search box
    ---------------------------------------------------------------
    local programs = wibox.widget { layout = wibox.layout.fixed.vertical }
    for _, e in ipairs(spec.left or {}) do
        programs:add(row(wibox.widget {
            {
                {
                    image = e.icon, resize = true,
                    forced_width = dpi(20), forced_height = dpi(20),
                    widget = wibox.widget.imagebox,
                },
                valign = "center", halign = "center",
                widget = wibox.container.place,
            },
            { label(e.label), left = dpi(9), widget = wibox.container.margin },
            layout = wibox.layout.fixed.horizontal,
        }, ROW_L, function() launch(e.cmd) end))
    end

    local all_programs = row(wibox.widget {
        {
            label("\u{25b8}", C.text_dim, "Noto Sans 9"),
            forced_width = dpi(20),
            widget = wibox.container.place,
        },
        { label("All Programs", C.text, "Noto Sans Bold 9"),
          left = dpi(9), widget = wibox.container.margin },
        layout = wibox.layout.fixed.horizontal,
    }, ROW_L, function() launch(spec.all_programs) end)

    -- Search box. Clicking it hands over to rofi rather than implementing an
    -- in-panel filter: rofi already indexes the desktop files, and a second
    -- search implementation would be one more thing to keep correct.
    local search = wibox.widget {
        {
            {
                label("\u{1f50d}", C.text_dim, "Noto Sans 8"),
                { label("Search programs and files", C.text_dim, "Noto Sans 9"),
                  left = dpi(6), widget = wibox.container.margin },
                layout = wibox.layout.fixed.horizontal,
            },
            left = dpi(7), right = dpi(7), top = dpi(5), bottom = dpi(5),
            widget = wibox.container.margin,
        },
        bg                 = "#ffffff",
        shape              = shape(dpi(3)),
        shape_border_width = 1,
        shape_border_color = "#8fb8d4",
        widget             = wibox.container.background,
    }
    search:buttons(gears.table.join(awful.button({}, 1, function()
        launch(spec.search or spec.all_programs)
    end)))

    local left_col = wibox.widget {
        {
            {
                -- align.vertical: list at the top, All Programs + search pinned
                -- to the bottom, the gap between them absorbing the slack.
                programs,
                { widget = wibox.container.background },
                {
                    { hline(C.sep), top = dpi(4), bottom = dpi(4),
                      widget = wibox.container.margin },
                    all_programs,
                    { search, top = dpi(6), widget = wibox.container.margin },
                    layout = wibox.layout.fixed.vertical,
                },
                layout = wibox.layout.align.vertical,
            },
            margins = PAD,
            widget  = wibox.container.margin,
        },
        bg                 = C.left_bg,
        shape              = shape(dpi(4)),
        shape_border_width = 1,
        shape_border_color = C.left_edge,
        widget             = wibox.container.background,
    }

    ---------------------------------------------------------------
    -- Right column: avatar, user name, links, Shut down
    ---------------------------------------------------------------
    local links = wibox.widget { layout = wibox.layout.fixed.vertical }
    for i, e in ipairs(spec.right or {}) do
        links:add(row(label(e.label, C.text), ROW_R, function() launch(e.cmd) end,
                      { left = dpi(6) }))
        -- Win7 groups the links with hairlines, not one long list.
        if e.rule then
            links:add(wibox.widget {
                hline(C.sep), top = dpi(3), bottom = dpi(3), left = dpi(4), right = dpi(4),
                widget = wibox.container.margin,
            })
        end
        local _ = i
    end

    -- Avatar + name are one clickable unit, which is what Win7's header is —
    -- listing the user again as a link below it was a duplicate.
    local header = wibox.widget {
        {
            {
                {
                    image = spec.avatar, resize = true,
                    forced_width = dpi(46), forced_height = dpi(46),
                    widget = wibox.widget.imagebox,
                },
                halign = "center",
                widget = wibox.container.place,
            },
            { label(spec.user or "user", C.text, "Noto Sans Bold 10", "center"),
              top = dpi(4), widget = wibox.container.margin },
            layout = wibox.layout.fixed.vertical,
        },
        bg     = "#00000000",
        shape  = shape(dpi(3)),
        widget = wibox.container.background,
    }
    header:connect_signal("mouse::enter", function() header.bg = "#ffffff8c" end)
    header:connect_signal("mouse::leave", function() header.bg = "#00000000" end)
    header:buttons(gears.table.join(awful.button({}, 1, function()
        launch(spec.home)
    end)))

    -- Shut down: a wide button plus the arrow that opens the other options,
    -- which is exactly how Win7 splits it.
    local shutdown = wibox.widget {
        {
            {
                {
                    image = spec.power_icon, resize = true,
                    forced_width = dpi(14), forced_height = dpi(14),
                    widget = wibox.widget.imagebox,
                },
                { label("Shut down", C.text, "Noto Sans 9"),
                  left = dpi(6), widget = wibox.container.margin },
                layout = wibox.layout.fixed.horizontal,
            },
            left = dpi(8), right = dpi(8), top = dpi(5), bottom = dpi(5),
            widget = wibox.container.margin,
        },
        bg                 = "linear:0,0:0," .. dpi(28) ..
                             ":0,#f4fafeff:0.5,#dcebf7ff:1,#c4dcefff",
        shape              = shape(dpi(3)),
        shape_border_width = 1,
        shape_border_color = "#8fb8d4",
        widget             = wibox.container.background,
    }
    shutdown:buttons(gears.table.join(awful.button({}, 1, function()
        launch(spec.power)
    end)))

    local right_col = wibox.widget {
        {
            {
                {
                    header,
                    { hline(C.sep), top = dpi(6), bottom = dpi(4),
                      widget = wibox.container.margin },
                    links,
                    layout = wibox.layout.fixed.vertical,
                },
                { widget = wibox.container.background },
                shutdown,
                layout = wibox.layout.align.vertical,
            },
            margins = PAD,
            widget  = wibox.container.margin,
        },
        bg     = C.right_bg,
        widget = wibox.container.background,
    }

    menu:set_widget(wibox.widget {
        {
            { left_col,  forced_width = W_LEFT - PAD,  widget = wibox.container.background },
            { right_col, forced_width = W_RIGHT - PAD, widget = wibox.container.background },
            spacing = PAD,
            layout  = wibox.layout.fixed.horizontal,
        },
        margins = dpi(4),   -- the translucent glass frame
        widget  = wibox.container.margin,
    })

    backdrop:buttons(gears.table.join(awful.button({}, 1, function() self.close() end)))

    -- Belt and braces: even with no keygrabber, never leave the backdrop
    -- swallowing clicks indefinitely if something goes wrong upstream.
    local guard = gears.timer { timeout = 60, single_shot = true,
                               callback = function() self.close() end }

    function self.toggle()
        if self.open then self.close() return end
        local wa = s.workarea
        menu.x = wa.x + dpi(4)
        -- workarea already excludes the taskbar, so this seats the menu on it.
        menu.y = wa.y + wa.height - menu.height
        backdrop.x, backdrop.y = s.geometry.x, s.geometry.y
        backdrop.width, backdrop.height = s.geometry.width, s.geometry.height
        backdrop.visible = true
        menu.visible = true
        self.open = true
        guard:again()
    end

    function self.is_open() return self.open end

    -- Closing on tag switch matches Windows: the menu is not sticky.
    s:connect_signal("tag::history::update", function() if self.open then self.close() end end)

    local _ = beautiful   -- theme is read through the C table above
    return self
end

return M
