---------------------------------------------------------------
-- Directional window navigation, shared by every desktop mode
-- (rc.lua's arch family and rc_windows7.lua).
--
-- awesome's built-in focus.bydirection compares only the top-left
-- edge of windows and ignores columns, so from a full-height master
-- "up" matches nothing (it is already the topmost window) while
-- "down" jumps sideways into the stack. This walks the actual
-- neighbours instead: a candidate must OVERLAP on the perpendicular
-- axis (same column for up/down, same row for left/right) and lie
-- beyond the current edge; nearest wins.
---------------------------------------------------------------
local awful = require("awful")

local nav = {}

function nav.neighbour(dir)
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

function nav.focus_dir(dir)
    local target = nav.neighbour(dir)
    if target then
        target:emit_signal("request::activate", "focus_dir", { raise = false })
    elseif dir == "up" or dir == "down" then
        -- Nothing in this column (e.g. the full-height master): walk the client
        -- list so j/k are never dead keys.
        awful.client.focus.byidx(dir == "down" and 1 or -1)
    end
end

function nav.move_dir(dir)
    local target = nav.neighbour(dir)
    if target then
        client.focus:swap(target)
    elseif dir == "up" or dir == "down" then
        awful.client.swap.byidx(dir == "down" and 1 or -1)
    end
end

return nav
