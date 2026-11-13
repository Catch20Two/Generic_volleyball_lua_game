---------------------------------------------------------------------------
-- ball.lua — the ball's flight
--
-- Every flight goes from a start point (with height) to a point on the
-- floor, over `duration` seconds. Height follows a parabola:
--     z(s) = z0 * (1 - s) + 4 * arc * s * (1 - s)        (s: 0 -> 1)
-- arc = extra height at the middle. arc = 0 is a straight line down
-- (a spike); a large arc is a high, slow pass.
-- A player touching the ball starts a new flight from where it is.
---------------------------------------------------------------------------
local Court  = require("court")
local Colors = require("colors")

local Ball = {}
Ball.__index = Ball

Ball.RADIUS = 0.15            -- meters

function Ball.new()
    local self = setmetatable({}, Ball)
    self:place(0, 0, 0)
    return self
end

-- Put the ball somewhere and hold it still (e.g. in the server's hands).
function Ball:place(x, y, z)
    self.x, self.y, self.z = x, y, z
    self.prevX, self.prevY, self.prevZ = x, y, z
    self.flying = false
    self.landed = false
end

function Ball:launch(x0, y0, z0, x1, y1, duration, arc)
    self:place(x0, y0, z0)
    self.x0, self.y0, self.z0 = x0, y0, z0
    self.x1, self.y1 = x1, y1
    self.duration = math.max(0.05, duration)
    self.arc = arc or 0
    self.t = 0
    self.flying = true
end

function Ball:positionAt(s)
    local x = self.x0 + (self.x1 - self.x0) * s
    local y = self.y0 + (self.y1 - self.y0) * s
    local z = self.z0 * (1 - s) + 4 * self.arc * s * (1 - s)
    return x, y, z
end

function Ball:update(dt)
    if not self.flying then return end
    self.prevX, self.prevY, self.prevZ = self.x, self.y, self.z
    self.t = self.t + dt
    local s = math.min(1, self.t / self.duration)
    self.x, self.y, self.z = self:positionAt(s)
    if s >= 1 then
        self.z = 0
        self.flying = false
        self.landed = true
    end
end

function Ball:descending()
    return self.z < self.prevZ
end

-- Where and when the current flight hits the floor.
function Ball:landing()
    return self.x1, self.y1, math.max(0, self.duration - self.t)
end

-- Horizontal direction of travel, as a unit vector.
function Ball:direction()
    local dx, dy = self.x1 - self.x0, self.y1 - self.y0
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1e-6 then return 0, 0 end
    return dx / d, dy / d
end

-- The smallest arc that clears the net by `clearance` meters on a flight
-- from (x0, z0) to (x1, z1). 0 if the straight line already clears it, or
-- if the flight doesn't cross the net.
-- Function written with a dot: it belongs to the Ball module but isn't
-- called on a particular ball.
function Ball.arcToClear(x0, z0, x1, z1, clearance)
    if (x0 < Court.NET_X) == (x1 < Court.NET_X) then return 0 end
    local s = (Court.NET_X - x0) / (x1 - x0)
    local straight = z0 + (z1 - z0) * s
    local need = Court.NET_HEIGHT + clearance
    if straight >= need then return 0 end
    return (need - straight) / (4 * s * (1 - s))
end

local function radiusPx()
    return math.max(4, Ball.RADIUS * Court.pixelsPerMeter() * 1.5)
end

function Ball:drawShadow()
    if self.z <= 0.05 then return end
    local sx, sy = Court.toScreen(self.x, self.y, 0)
    local r = radiusPx()
    love.graphics.setColor(Colors.SHADOW)
    love.graphics.ellipse("fill", sx, sy, r * 1.2, r * 0.5)
    love.graphics.setColor(1, 1, 1)
end

function Ball:draw()
    local sx, sy = Court.toScreen(self.x, self.y, self.z)
    local r = radiusPx()
    love.graphics.setColor(Colors.BALL)
    love.graphics.circle("fill", sx, sy - r, r)
    love.graphics.setColor(Colors.OUTLINE)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", sx, sy - r, r)
    love.graphics.setColor(1, 1, 1)
end

return Ball