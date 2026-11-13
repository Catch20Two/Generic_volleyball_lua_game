---------------------------------------------------------------------------
-- rally.lua — the rules of one rally, from serve to dead ball
--
-- Each frame: players move, the ball moves, then the rally checks the
-- net, touches and landing, in that order.
--
-- A touch decides the next action:
--   1st touch after the ball comes over   -> pass to the setter
--   the planned setter                    -> set to a spiker
--   the planned spiker                    -> spike
--   anyone unplanned, or the 3rd touch    -> free ball over
---------------------------------------------------------------------------
local Court    = require("court")
local Ball     = require("ball")
local Accuracy = require("accuracy")
local Movement = require("movement")
local AI       = require("ai")

local Rally = {}
Rally.__index = Rally

-- Timing and ball tuning (seconds, meters, meters per second)
local SERVE_WAIT        = 0.6
local SERVE_CONTACT_Z   = 2.6
local SERVE_SPEED_BASE  = 8
local SERVE_SPEED_PER   = 1 / 20      -- per Strength point
local SPIKE_SPEED_BASE  = 12
local SPIKE_SPEED_PER   = 1 / 10
local PASS_TIME, PASS_ARC       = 1.3, 3.0
local SET_TIME, SET_ARC         = 1.0, 3.0
local FREE_TIME, FREE_ARC       = 1.5, 2.5
local DEFLECT_TIME, DEFLECT_ARC = 1.0, 1.2
local STUFF_TIME, STUFF_ARC     = 0.5, 0.3
local STUFF_SHARE   = 0.5             -- share of successful blocks that stuff
local NET_CLEARANCE = 0.3
local NET_OFFSET    = 0.05            -- blocked balls restart just off the net

local VERBS = {
    serve = { normal = "serves",  critSuccess = "serves perfectly",     critFail = "botches the serve" },
    pass  = { normal = "passes",  critSuccess = "makes a perfect pass", critFail = "shanks the pass" },
    set   = { normal = "sets",    critSuccess = "makes a perfect set",  critFail = "mishandles the set" },
    spike = { normal = "spikes",  critSuccess = "crushes a spike",      critFail = "mis-hits the spike" },
    free  = { normal = "sends a free ball over", critSuccess = "places a free ball",
              critFail = "flubs the free ball" },
}

local function distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- o = { ball =, teams = { left =, right = }, serving = team, say = function }
function Rally.new(o)
    local self = setmetatable({}, Rally)
    self.ball, self.teams, self.serving, self.say = o.ball, o.teams, o.serving, o.say
    self.phase = "waiting"            -- "waiting", "live" or "over"
    self.timer = SERVE_WAIT
    self.lastTeam, self.lastPlayer = nil, nil
    self.sentBy = nil                 -- team that sent the ball over, until it crosses
    self.kind = nil                   -- "serve", "attack", "free", "block", "deflect"
    self.attacker = nil
    self.winner, self.reason = nil, nil

    for _, team in pairs(self.teams) do
        team:resetPositions()
    end
    local server = AI.chooseServer(self.serving)
    server.x = Court.depthToX(self.serving.side, Court.SERVE_DEPTH)
    Movement.goTo(server, server.x, server.y, 0)
    self.server = server
    self.ball:place(server.x, server.y, SERVE_CONTACT_Z)
    return self
end

function Rally:describe(player, action, result)
    self.say(player.name .. " " .. VERBS[action][result])
end

function Rally:finish(winner, reason)
    self.phase = "over"
    self.winner, self.reason = winner, reason
    self.say(reason)
end

-- Arc for a ball going over the net. A critical failure gets no help
-- clearing it, which is how balls end up in the net.
function Rally:netArc(x1, result, minimum)
    local b = self.ball
    local arc = minimum or 0
    if result ~= "critFail" then
        arc = math.max(arc, Ball.arcToClear(b.x, b.z, x1, 0, NET_CLEARANCE))
    end
    return arc
end

function Rally:sendOver(player, x, y, duration, arc, kind)
    local team = player.team
    local b = self.ball
    b:launch(b.x, b.y, b.z, x, y, duration, arc)
    self.lastTeam, self.lastPlayer = team, player
    self.sentBy, self.kind = team, kind
    team.touches, team.expect = 0, nil
    AI.onTeamPass(team, nil)             -- the sending team heads home
    AI.onIncoming(team.opponent, b)      -- the other team reacts
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
function Rally:serve()
    local server = self.server
    local tx, ty = AI.randomCell(self.serving.opponent)
    local x, y, result = Accuracy.aim(server.x, server.y, tx, ty, server:failure())
    local b = self.ball
    local speed = SERVE_SPEED_BASE + server.strength * SERVE_SPEED_PER
    self:sendOver(server, x, y, distance(b.x, b.y, x, y) / speed, self:netArc(x, result, 0), "serve")
    self.phase = "live"
    self:describe(server, "serve", result)
end

function Rally:pass(p)
    local team = p.team
    local sx, sy = AI.setPoint(team)
    local setter = AI.chooseSetter(team, sx, sy, p)
    local b = self.ball
    local x, y, result = Accuracy.aim(b.x, b.y, sx, sy, p:failure())
    b:launch(b.x, b.y, b.z, x, y, PASS_TIME, PASS_ARC)
    team.expect = setter and { player = setter, action = "set" } or nil
    AI.onTeamPass(team, setter, x, y)
    self:describe(p, "pass", result)
end

function Rally:set(p)
    local team = p.team
    local spiker = AI.chooseSpiker(team, p)
    if not spiker then return self:free(p) end
    local tx, ty = AI.attackPoint(team, spiker)
    local b = self.ball
    local x, y, result = Accuracy.aim(b.x, b.y, tx, ty, p:failure())
    b:launch(b.x, b.y, b.z, x, y, SET_TIME, SET_ARC)
    team.expect = { player = spiker, action = "spike" }
    AI.onTeamPass(team, spiker, x, y)
    AI.prepareBlock(team.opponent, y)
    self:describe(p, "set", result)
end

function Rally:spike(p)
    local tx, ty = AI.spikeTarget(p.team.opponent)
    local b = self.ball
    local x, y, result = Accuracy.aim(b.x, b.y, tx, ty, p:failure())
    local speed = SPIKE_SPEED_BASE + p.strength * SPIKE_SPEED_PER
    self.attacker = p
    self:sendOver(p, x, y, distance(b.x, b.y, x, y) / speed, self:netArc(x, result, 0), "attack")
    self:describe(p, "spike", result)
end

function Rally:free(p)
    local tx, ty = AI.randomCell(p.team.opponent)
    local b = self.ball
    local x, y, result = Accuracy.aim(b.x, b.y, tx, ty, p:failure())
    self:sendOver(p, x, y, FREE_TIME, self:netArc(x, result, FREE_ARC), "free")
    self:describe(p, "free", result)
end

function Rally:touch(p)
    local team = p.team
    team.touches = team.touches + 1
    self.lastTeam, self.lastPlayer = team, p

    local action
    if team.touches == 1 then
        action = "pass"
    elseif team.expect and team.expect.player == p then
        action = team.expect.action
    else
        action = "free"                  -- the plan broke down: just send it over
    end
    if team.touches >= 3 and action ~= "spike" then
        action = "free"                  -- 3rd touch must go over
    end
    team.expect = nil

    if action == "pass" then self:pass(p)
    elseif action == "set" then self:set(p)
    elseif action == "spike" then self:spike(p)
    else self:free(p) end
end

---------------------------------------------------------------------------
-- Blocks
---------------------------------------------------------------------------
-- Stuffed: straight back down on the attackers' side.
function Rally:stuff(blocker, attackers, y, z)
    local tx, ty = AI.frontCell(attackers)
    self.ball:launch(Court.depthToX(attackers.side, NET_OFFSET), y, z, tx, ty, STUFF_TIME, STUFF_ARC)
    self.lastTeam, self.lastPlayer = blocker.team, nil
    self.sentBy, self.kind = blocker.team, "block"
    attackers.touches, attackers.expect = 0, nil
    AI.onIncoming(attackers, self.ball)
    self.say(blocker.name .. " blocks it!")
end

-- Touched: slowed down, continues into the blockers' own court to be dug.
-- A block touch doesn't count as one of the 3 touches.
function Rally:blockTouch(blocker, defenders, y, z)
    local tx, ty = AI.deflectTarget(defenders)
    self.ball:launch(Court.depthToX(defenders.side, NET_OFFSET), y, z, tx, ty, DEFLECT_TIME, DEFLECT_ARC)
    self.lastTeam, self.lastPlayer = defenders, nil
    self.sentBy, self.kind = nil, "deflect"
    defenders.touches, defenders.expect = 0, nil
    AI.onIncoming(defenders, self.ball)
    self.say(blocker.name .. " gets a hand on it!")
end

---------------------------------------------------------------------------
-- Checks
---------------------------------------------------------------------------
function Rally:checkNet()
    local b = self.ball
    if (b.prevX < Court.NET_X) == (b.x < Court.NET_X) then return end

    -- Where the ball was as it crossed the net plane
    local s = (Court.NET_X - b.prevX) / (b.x - b.prevX)
    local y = b.prevY + (b.y - b.prevY) * s
    local z = b.prevZ + (b.z - b.prevZ) * s
    local fromTeam = self.teams[Court.sideOf(b.prevX)]
    local toTeam = fromTeam.opponent

    if y < 0 or y > Court.WIDTH then
        return self:finish(self.lastTeam.opponent, "Outside the antenna!")
    end
    if z < Court.NET_HEIGHT then
        return self:finish(self.lastTeam.opponent, "Into the net!")
    end

    if self.kind == "attack" and self.sentBy == fromTeam then
        local blocker = AI.findBlocker(toTeam, y, z)
        if blocker and love.math.random() < AI.blockChance(blocker, self.attacker) then
            if love.math.random() < STUFF_SHARE then
                self:stuff(blocker, fromTeam, y, z)
            else
                self:blockTouch(blocker, toTeam, y, z)
            end
            return
        end
    end

    -- An accidental crossing (a wild pass) gives no early warning, so the
    -- other team reacts now instead of at launch.
    if self.sentBy ~= fromTeam then
        AI.onIncoming(toTeam, b)
    end
    self.sentBy = nil
    toTeam.touches, toTeam.expect = 0, nil
end

-- The closest eligible player within reach touches the ball.
function Rally:checkTouches()
    local b = self.ball
    if not b:descending() then return end
    local team = self.teams[Court.sideOf(b.x)]
    if team == self.sentBy or team.touches >= 3 then return end

    local best, bestD
    for _, p in ipairs(team.players) do
        if p ~= self.lastPlayer and b.z <= AI.contactHeight(p) then
            local d = distance(p.x, p.y, b.x, b.y)
            if d <= AI.contactReach(p) and (not bestD or d < bestD) then
                best, bestD = p, d
            end
        end
    end
    if best then
        self:touch(best)
    end
end

function Rally:landed()
    local b = self.ball
    if Court.inBounds(b.x, b.y) then
        local landedOn = self.teams[Court.sideOf(b.x)]
        local ace = self.kind == "serve" and landedOn ~= self.serving
        self:finish(landedOn.opponent, ace and "Ace!" or "The ball drops in!")
    else
        self:finish(self.lastTeam.opponent, "Out!")
    end
end

function Rally:update(dt)
    for _, team in pairs(self.teams) do
        for _, p in ipairs(team.players) do
            Movement.update(p, dt)
        end
    end
    if self.phase == "over" then return end

    if self.phase == "waiting" then
        self.timer = self.timer - dt
        if self.timer <= 0 then self:serve() end
        return
    end

    self.ball:update(dt)
    self:checkNet()
    if self.phase == "over" then return end
    self:checkTouches()
    if self.ball.landed then
        self:landed()
    end
end

return Rally