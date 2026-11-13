---------------------------------------------------------------------------
-- accuracy.lua — how close a touch lands to where it was aimed
--
-- Every touch rolls 1-100:
--   1-5    critical failure: wildly off (often net or out)
--   96-100 critical success: exactly on target
--   else   angle off by up to failure/4 degrees,
--          distance off by up to failure/25 meters
-- All tuning numbers are here.
---------------------------------------------------------------------------
local Accuracy = {}

Accuracy.CRIT_FAIL_CHANCE    = 5
Accuracy.CRIT_SUCCESS_CHANCE = 5
Accuracy.ANGLE_DIVISOR       = 4        -- failure 100 -> up to 25 degrees
Accuracy.DISTANCE_DIVISOR    = 25       -- failure 100 -> up to 4 meters
Accuracy.CRIT_ANGLE          = { 30, 60 }
Accuracy.CRIT_DISTANCE       = { 2, 5 }
Accuracy.REACTION_DIVISOR    = 100      -- failure 30 -> 0.3 s before moving

local function uniform(a, b)
    return a + (b - a) * love.math.random()     -- random() alone: 0 to 1
end

local function randomSign()
    return (love.math.random(2) == 1) and -1 or 1
end

function Accuracy.roll()
    local r = love.math.random(100)
    if r <= Accuracy.CRIT_FAIL_CHANCE then
        return "critFail"
    elseif r > 100 - Accuracy.CRIT_SUCCESS_CHANCE then
        return "critSuccess"
    end
    return "normal"
end

function Accuracy.reactionDelay(player)
    return player:failure() / Accuracy.REACTION_DIVISOR
end

-- Aim from (fromX, fromY) at (toX, toY). Returns where it actually goes
-- and the roll result.
function Accuracy.aim(fromX, fromY, toX, toY, failure)
    local result = Accuracy.roll()
    if result == "critSuccess" then
        return toX, toY, result
    end

    local angle, distance
    if result == "critFail" then
        angle = randomSign() * uniform(Accuracy.CRIT_ANGLE[1], Accuracy.CRIT_ANGLE[2])
        distance = randomSign() * uniform(Accuracy.CRIT_DISTANCE[1], Accuracy.CRIT_DISTANCE[2])
    else
        local maxAngle = failure / Accuracy.ANGLE_DIVISOR
        local maxDistance = failure / Accuracy.DISTANCE_DIVISOR
        angle = uniform(-maxAngle, maxAngle)
        distance = uniform(-maxDistance, maxDistance)
    end

    local dx, dy = toX - fromX, toY - fromY
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1e-6 then
        return toX, toY, result
    end

    -- Rotate the aim direction by `angle`, then stretch or shrink it.
    local a = math.rad(angle)
    local c, s = math.cos(a), math.sin(a)
    local ux = (dx * c - dy * s) / length
    local uy = (dx * s + dy * c) / length
    local newLength = math.max(0.5, length + distance)
    return fromX + ux * newLength, fromY + uy * newLength, result
end

return Accuracy