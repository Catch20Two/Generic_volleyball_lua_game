---------------------------------------------------------------------------
-- player.lua — one volleyball player
--
-- Stats: heightIn (inches, fixed), strength, speed, skill (no cap).
-- failure = 100 - skill, kept between 0 and 100.
-- Court position (x, y) is in meters; see court.lua.
---------------------------------------------------------------------------
local Court  = require("court")
local Colors = require("colors")

local Player = {}
Player.__index = Player

Player.ROLES = { "Server", "Setter", "Spiker", "Blocker", "Passer" }
Player.MIN_HEIGHT_IN = 60      -- 5'0"
Player.MAX_HEIGHT_IN = 77      -- 6'5"

-- Movement and reach tuning
local MOVE_BASE       = 2.0
local MOVE_PER_SPEED  = 1 / 25
local REACH_BASE      = 0.6
local REACH_PER_M     = 0.2
local STANDING_FACTOR = 1.33
local JUMP            = 0.5

-- Drawing: trapezoid widths in meters
local WIDTH_BASE      = 0.2
local WIDTH_PER_POINT = 1 / 250

-- f holds the fields by name. A saved roster row has exactly these names,
-- so Player.new(row) rebuilds a saved player directly.
function Player.new(f)
    local self = setmetatable({}, Player)
    self.name     = tostring(f.name)
    self.heightIn = f.heightIn
    self.strength = f.strength
    self.speed    = f.speed
    self.skill    = f.skill
    self.role     = f.role

    self.team = nil
    self.spot = nil
    self.x, self.y = 0, 0
    self.homeX, self.homeY = 0, 0
    self.targetX, self.targetY = 0, 0
    self.delay = 0
    self.blocking = false
    return self
end

function Player:failure()
    return math.max(0, math.min(100, 100 - self.skill))
end

function Player:heightMeters()   return self.heightIn * 0.0254 end
function Player:moveSpeed()      return MOVE_BASE + self.speed * MOVE_PER_SPEED end
function Player:reach()          return REACH_BASE + self:heightMeters() * REACH_PER_M end
function Player:standingReach()  return self:heightMeters() * STANDING_FACTOR end
function Player:jumpReach()      return self:standingReach() + JUMP end
function Player:statTotal()      return self.strength + self.speed + self.skill end
function Player:isFrontRow()     return self.spot ~= nil and self.spot:sub(1, 1) == "F" end

function Player:heightRating()
    return (self.heightIn - Player.MIN_HEIGHT_IN)
        / (Player.MAX_HEIGHT_IN - Player.MIN_HEIGHT_IN) * 100
end

function Player:heightText()
    local feet = math.floor(self.heightIn / 12)
    return feet .. "'" .. (self.heightIn - feet * 12) .. '"'
end

-- Next role in Player.ROLES, wrapping around at the end.
function Player:cycleRole()
    for i, role in ipairs(Player.ROLES) do
        if role == self.role then
            self.role = Player.ROLES[i % #Player.ROLES + 1]
            return
        end
    end
    self.role = Player.ROLES[1]
end

-- Trapezoid with its bottom edge centered on (sx, sy):
-- height from Height, top edge from Strength, bottom edge from Speed.
-- ppm and zScale are pixels per meter across and up.
function Player:drawShape(sx, sy, ppm, zScale, palette)
    local h = self:heightMeters() * zScale
    local top = ppm * (WIDTH_BASE + self.strength * WIDTH_PER_POINT)
    local bottom = ppm * (WIDTH_BASE + self.speed * WIDTH_PER_POINT)
    local points = {
        sx - bottom / 2, sy,
        sx + bottom / 2, sy,
        sx + top / 2,    sy - h,
        sx - top / 2,    sy - h,
    }
    love.graphics.setColor(Colors.TEAM[palette][self.role])
    love.graphics.polygon("fill", points)
    love.graphics.setColor(Colors.OUTLINE)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", points)
    love.graphics.setColor(1, 1, 1)
end

-- On the court.
function Player:draw()
    local sx, sy = Court.toScreen(self.x, self.y, 0)
    self:drawShape(sx, sy, Court.pixelsPerMeter(), Court.zScale(), self.team.palette)
end

return Player