---------------------------------------------------------------------------
-- court.lua — court geometry (meters) and the angled view (pixels)
--
-- Court units are meters, like a real court: 18 long (x) by 9 wide (y),
-- net at x = 9. The left half is your team, the right half the computer's.
-- y = 0 is the near sideline (bottom of the screen), y = 9 the far one.
-- z is height above the floor.
--
-- Each half has 3x3 cells: row 1 = front (by the net) to row 3 = back,
-- col 1 = near sideline to col 3 = far sideline.
---------------------------------------------------------------------------
local Colors = require("colors")

local Court = {}

Court.LENGTH     = 18
Court.WIDTH      = 9
Court.NET_X      = 9
Court.NET_HEIGHT = 2.43     -- still used by the rules; the net is just drawn as a line
Court.CELL       = 3

-- Distances from the net, in meters
Court.FRONT_DEPTH  = 2.0
Court.BACK_DEPTH   = 6.5
Court.SERVE_DEPTH  = 9.8
Court.SET_DEPTH    = 1.2
Court.ATTACK_DEPTH = 0.9
Court.BLOCK_DEPTH  = 0.5

-- View tuning
local MARGIN      = 2.5    -- meters of floor shown beyond each end line
local FAR_SCALE   = 0.9    -- far sideline drawn 90% as long as the near one;
                           -- both ends lean inward by the same angle
local DEPTH_SHARE = 0.55   -- share of the court area's height used by the floor
local Z_FACTOR    = 0.75   -- height drawn at 75% of the horizontal scale
local BOTTOM_PAD  = 6      -- pixels below the near sideline
local NET_WIDTH   = 4      -- pixels

local view = { cx = 0, bottom = 0, depthPx = 1, ppm = 1, zScale = 1 }

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------
function Court.depthToX(side, depth)
    return (side == "left") and (Court.NET_X - depth) or (Court.NET_X + depth)
end

function Court.depthOf(side, x)
    return (side == "left") and (Court.NET_X - x) or (x - Court.NET_X)
end

function Court.sideOf(x)
    return (x < Court.NET_X) and "left" or "right"
end

function Court.inBounds(x, y)
    return x >= 0 and x <= Court.LENGTH and y >= 0 and y <= Court.WIDTH
end

function Court.cellCenter(side, row, col)
    return Court.depthToX(side, (row - 0.5) * Court.CELL), (col - 0.5) * Court.CELL
end

function Court.cellOf(x, y)
    if not Court.inBounds(x, y) then return nil end
    local side = Court.sideOf(x)
    local row = math.min(3, math.floor(Court.depthOf(side, x) / Court.CELL) + 1)
    local col = math.min(3, math.floor(y / Court.CELL) + 1)
    return side, row, col
end

---------------------------------------------------------------------------
-- The view
---------------------------------------------------------------------------
function Court.layout(rect)
    view.ppm = rect.w / (Court.LENGTH + 2 * MARGIN)
    view.depthPx = rect.h * DEPTH_SHARE
    view.bottom = rect.y + rect.h - BOTTOM_PAD
    view.cx = rect.x + rect.w / 2
    view.zScale = view.ppm * Z_FACTOR
end

function Court.pixelsPerMeter() return view.ppm end
function Court.zScale()         return view.zScale end

-- Court meters (x, y, z) -> screen pixels.
-- Farther away (bigger y): higher on screen and narrower, shrinking toward
-- the center equally on both sides, so the court is a symmetric trapezoid.
function Court.toScreen(x, y, z)
    local t = y / Court.WIDTH
    local scale = 1 + (FAR_SCALE - 1) * t
    local sx = view.cx + (x - Court.NET_X) * view.ppm * scale
    local sy = view.bottom - t * view.depthPx - (z or 0) * view.zScale
    return sx, sy
end

local function floorQuad(x1, y1, x2, y2)
    local ax, ay = Court.toScreen(x1, y1, 0)
    local bx, by = Court.toScreen(x2, y1, 0)
    local cx, cy = Court.toScreen(x2, y2, 0)
    local dx, dy = Court.toScreen(x1, y2, 0)
    return { ax, ay, bx, by, cx, cy, dx, dy }
end

local function floorLine(x1, y1, x2, y2)
    local ax, ay = Court.toScreen(x1, y1, 0)
    local bx, by = Court.toScreen(x2, y2, 0)
    love.graphics.line(ax, ay, bx, by)
end

function Court.drawFloor()
    love.graphics.setColor(Colors.FLOOR_OUT)
    love.graphics.polygon("fill", floorQuad(-MARGIN, 0, Court.LENGTH + MARGIN, Court.WIDTH))
    love.graphics.setColor(Colors.FLOOR)
    love.graphics.polygon("fill", floorQuad(0, 0, Court.LENGTH, Court.WIDTH))

    love.graphics.setColor(Colors.GRID)
    love.graphics.setLineWidth(1)
    for _, x in ipairs({ 3, 6, 12, 15 }) do
        floorLine(x, 0, x, Court.WIDTH)
    end
    for _, y in ipairs({ 3, 6 }) do
        floorLine(0, y, Court.LENGTH, y)
    end

    love.graphics.setColor(Colors.COURT_LINE)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", floorQuad(0, 0, Court.LENGTH, Court.WIDTH))
    love.graphics.setColor(1, 1, 1)
end

-- The net: one line down the center, from the near sideline to the far one.
function Court.drawNet()
    love.graphics.setColor(Colors.NET)
    love.graphics.setLineWidth(NET_WIDTH)
    floorLine(Court.NET_X, 0, Court.NET_X, Court.WIDTH + 2)
    love.graphics.setColor(1, 1, 1)
end

return Court