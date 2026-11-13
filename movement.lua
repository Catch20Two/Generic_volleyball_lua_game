---------------------------------------------------------------------------
-- movement.lua — players walking to where the AI sends them
--
-- Players never cross the center line: every target, and every position,
-- stays at least NET_GAP meters on the player's own side of the net.
---------------------------------------------------------------------------
local Court = require("court")

local Movement = {}

local NET_GAP = 0.3

-- Keep x on the player's side of the net.
local function ownSideX(p, x)
    if p.team.side == "left" then
        return math.min(x, Court.NET_X - NET_GAP)
    end
    return math.max(x, Court.NET_X + NET_GAP)
end

function Movement.goTo(p, x, y, delay)
    p.targetX, p.targetY = ownSideX(p, x), y
    p.delay = delay or 0
end

function Movement.goHome(p)
    Movement.goTo(p, p.homeX, p.homeY, 0)
end

-- Seconds until the player could stand at (x, y), counting a delay.
-- Uses the clamped point, so a ball landing across the net is measured
-- to the closest spot the player can actually reach.
function Movement.timeToReach(p, x, y, delay)
    local dx, dy = ownSideX(p, x) - p.x, y - p.y
    return (delay or 0) + math.sqrt(dx * dx + dy * dy) / p:moveSpeed()
end

function Movement.update(p, dt)
    if p.delay > 0 then
        p.delay = p.delay - dt
        if p.delay > 0 then return end
    end
    local dx, dy = p.targetX - p.x, p.targetY - p.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d >= 1e-3 then
        local step = p:moveSpeed() * dt
        if step >= d then
            p.x, p.y = p.targetX, p.targetY
        else
            p.x = p.x + dx / d * step
            p.y = p.y + dy / d * step
        end
    end
    p.x = ownSideX(p, p.x)               -- safety: never past the line
end

return Movement