---------------------------------------------------------------------------
-- ai.lua — every decision players make
--
-- Rules (rally.lua) ask questions here; movement.lua moves the answers.
--
-- Fallbacks when a role is missing:
--   serve   : first Server        -> player in spot B3
--   receive : closest Passer      -> closest player
--   set     : closest Setter      -> closest front-row player -> anyone
--   spike   : Spiker (weighted)   -> front-row player -> anyone
--   block   : Blockers            -> nobody blocks
---------------------------------------------------------------------------
local Court    = require("court")
local Movement = require("movement")
local Accuracy = require("accuracy")

local AI = {}

local SET_Y             = 5.0   -- passes aim here across the court
local BUMP_HEIGHT       = 1.0   -- meters: where unplanned touches happen
local SET_REACH_BONUS   = 0.5   -- extra reach for the planned setter
local SPIKE_REACH_BONUS = 1.0   -- extra reach for the planned spiker (approach jump)
local STEP_ASIDE        = 1.5   -- meters a player in the landing cell moves away

-- Blocking (placeholder numbers; rules to revisit)
local BLOCK_REACH_Y       = 1.0
local BLOCK_MAX_DEPTH     = 1.5
local BLOCK_BASE          = 0.25
local BLOCK_HEIGHT_FACTOR = 0.5       -- per meter taller than the spiker
local BLOCK_SKILL_FACTOR  = 1 / 200   -- per skill point better than the spiker
local BLOCK_MIN, BLOCK_MAX = 0.05, 0.6

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clampY(y)
    return math.max(0.5, math.min(Court.WIDTH - 0.5, y))
end

-- Keep a point on the team's own side of the net.
local function clampToSide(team, x)
    if team.side == "left" then
        return math.min(x, Court.NET_X - 0.3)
    end
    return math.max(x, Court.NET_X + 0.3)
end

-- Closest player to (x, y) for whom accept(p) is true (accept optional).
local function closest(players, x, y, accept)
    local best, bestD
    for _, p in ipairs(players) do
        if not accept or accept(p) then
            local d = distance(p.x, p.y, x, y)
            if not bestD or d < bestD then
                best, bestD = p, d
            end
        end
    end
    return best
end

-- Random pick where closer players are more likely.
local function weightedByCloseness(players, x, y)
    local weights, total = {}, 0
    for i, p in ipairs(players) do
        weights[i] = 1 / (1 + distance(p.x, p.y, x, y))
        total = total + weights[i]
    end
    local r = love.math.random() * total
    for i, p in ipairs(players) do
        r = r - weights[i]
        if r <= 0 then return p end
    end
    return players[#players]
end

---------------------------------------------------------------------------
-- Who does what
---------------------------------------------------------------------------
function AI.chooseServer(team)
    for _, p in ipairs(team.players) do
        if p.role == "Server" then return p end
    end
    for _, p in ipairs(team.players) do
        if p.spot == "B3" then return p end
    end
    return team.players[1]
end

function AI.chooseReceiver(team, x, y)
    return closest(team.players, x, y, function(p) return p.role == "Passer" and not p.blocking end)
        or closest(team.players, x, y, function(p) return not p.blocking end)
        or closest(team.players, x, y)
end

function AI.chooseSetter(team, x, y, passer)
    return closest(team.players, x, y, function(p) return p ~= passer and p.role == "Setter" end)
        or closest(team.players, x, y, function(p) return p ~= passer and p:isFrontRow() end)
        or closest(team.players, x, y, function(p) return p ~= passer end)
end

function AI.chooseSpiker(team, setter)
    local spikers = {}
    for _, p in ipairs(team.players) do
        if p ~= setter and p.role == "Spiker" then
            spikers[#spikers + 1] = p
        end
    end
    if #spikers > 0 then
        return weightedByCloseness(spikers, setter.x, setter.y)
    end
    return closest(team.players, setter.x, setter.y, function(p) return p ~= setter and p:isFrontRow() end)
        or closest(team.players, setter.x, setter.y, function(p) return p ~= setter end)
end

---------------------------------------------------------------------------
-- Where to aim
---------------------------------------------------------------------------
function AI.setPoint(team)
    return Court.depthToX(team.side, Court.SET_DEPTH), SET_Y
end

function AI.attackPoint(team, spiker)
    return Court.depthToX(team.side, Court.ATTACK_DEPTH), clampY(spiker.homeY)
end

function AI.randomCell(team)
    return Court.cellCenter(team.side, love.math.random(3), love.math.random(3))
end

function AI.frontCell(team)
    return Court.cellCenter(team.side, 1, love.math.random(3))
end

-- 9 cells, plus the cells of the weakest and the shortest defender again,
-- so those two cells are more likely. A cell can appear up to 3 times.
function AI.spikeTarget(defenders)
    local cells = {}
    for row = 1, 3 do
        for col = 1, 3 do
            cells[#cells + 1] = { row, col }
        end
    end

    local weakest, shortest = defenders.players[1], defenders.players[1]
    for _, p in ipairs(defenders.players) do
        if p.strength < weakest.strength then weakest = p end
        if p.heightIn < shortest.heightIn then shortest = p end
    end
    for _, p in ipairs({ weakest, shortest }) do
        local side, row, col = Court.cellOf(p.x, p.y)
        if side == defenders.side then
            cells[#cells + 1] = { row, col }
        end
    end

    local cell = cells[love.math.random(#cells)]       -- Lua's random.choice
    return Court.cellCenter(defenders.side, cell[1], cell[2])
end

-- After a block touch: any cell, front row twice as likely.
function AI.deflectTarget(team)
    local cells = {}
    for row = 1, 3 do
        for col = 1, 3 do
            cells[#cells + 1] = { row, col }
        end
    end
    for col = 1, 3 do
        cells[#cells + 1] = { 1, col }
    end
    local cell = cells[love.math.random(#cells)]
    return Court.cellCenter(team.side, cell[1], cell[2])
end

---------------------------------------------------------------------------
-- Touch rules
---------------------------------------------------------------------------
-- How high a player touches the ball: the planned setter reaches overhead,
-- the planned spiker jumps, everyone else bumps at waist height.
function AI.contactHeight(p)
    local plan = p.team.expect
    if plan and plan.player == p then
        if plan.action == "set" then return p:standingReach() end
        if plan.action == "spike" then return p:jumpReach() end
    end
    return BUMP_HEIGHT
end

function AI.contactReach(p)
    local plan = p.team.expect
    if plan and plan.player == p then
        if plan.action == "set" then return p:reach() + SET_REACH_BONUS end
        if plan.action == "spike" then return p:reach() + SPIKE_REACH_BONUS end
    end
    return p:reach()
end

---------------------------------------------------------------------------
-- Reactions
---------------------------------------------------------------------------
-- The ball is coming at `team` from the other side.
--   * The closest Passer goes for it after a reaction delay.
--   * Players in the landing cell step aside if that Passer will make it,
--     otherwise go for it themselves.
--   * Everyone else rolls against their failure rate; a failed roll
--     wrongly sends them toward the ball too.
--   * A ball landing out of bounds is left alone (except by mistakes).
--   * Players set up to block stay at the net.
function AI.onIncoming(team, ball)
    local lx, ly, timeLeft = ball:landing()
    local landSide, landRow, landCol = Court.cellOf(lx, ly)
    local defend = landSide == team.side

    local receiver, receiverInTime
    if defend then
        receiver = AI.chooseReceiver(team, lx, ly)
        local delay = Accuracy.reactionDelay(receiver)
        Movement.goTo(receiver, lx, ly, delay)
        receiverInTime = Movement.timeToReach(receiver, lx, ly, delay) <= timeLeft
    end

    local dx, dy = ball:direction()
    for _, p in ipairs(team.players) do
        if p ~= receiver and not p.blocking then
            local delay = Accuracy.reactionDelay(p)
            local pSide, pRow, pCol = Court.cellOf(p.x, p.y)
            local inLandingCell = defend and pSide == team.side
                and pRow == landRow and pCol == landCol

            if inLandingCell then
                if receiverInTime then
                    local x = clampToSide(team, p.x + dx * STEP_ASIDE)
                    Movement.goTo(p, x, clampY(p.y + dy * STEP_ASIDE), 0)
                else
                    Movement.goTo(p, lx, ly, delay)
                end
            elseif love.math.random(100) <= p:failure() then
                Movement.goTo(p, lx, ly, delay)          -- a mistake
            else
                Movement.goHome(p)
            end
        end
    end
end

-- A pass within the team: only the intended receiver moves; the rest go
-- home. receiver may be nil (ball sent over: everyone goes home).
function AI.onTeamPass(team, receiver, x, y)
    for _, p in ipairs(team.players) do
        p.blocking = false
        if p == receiver then
            Movement.goTo(p, x, y, Accuracy.reactionDelay(p))
        else
            Movement.goHome(p)
        end
    end
end

-- The other team just set the ball toward y: Blockers move along the net.
function AI.prepareBlock(defenders, y)
    for _, p in ipairs(defenders.players) do
        if p.role == "Blocker" then
            p.blocking = true
            Movement.goTo(p, Court.depthToX(defenders.side, Court.BLOCK_DEPTH),
                clampY(y), Accuracy.reactionDelay(p))
        end
    end
end

-- A blocker who can reach a spike crossing the net at (y, z), or nil.
function AI.findBlocker(defenders, y, z)
    local best, bestD
    for _, p in ipairs(defenders.players) do
        if p.blocking
            and Court.depthOf(defenders.side, p.x) <= BLOCK_MAX_DEPTH
            and p:jumpReach() >= z then
            local d = math.abs(p.y - y)
            if d <= BLOCK_REACH_Y and (not bestD or d < bestD) then
                best, bestD = p, d
            end
        end
    end
    return best
end

-- Chance a block attempt works. Placeholder until we revisit block rules.
function AI.blockChance(blocker, spiker)
    local chance = BLOCK_BASE
        + (blocker:heightMeters() - spiker:heightMeters()) * BLOCK_HEIGHT_FACTOR
        + (blocker.skill - spiker.skill) * BLOCK_SKILL_FACTOR
    return math.max(BLOCK_MIN, math.min(BLOCK_MAX, chance))
end

return AI