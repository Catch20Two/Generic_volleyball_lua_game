---------------------------------------------------------------------------
-- team.lua — six players on one side of the court
--
-- Home spots: F = front row (near the net), B = back row.
-- 1, 2, 3 go across the court from the near sideline to the far one.
-- Roles are free (any mix), so spots are filled in role priority order,
-- and extra players of one role take the next free spot they prefer.
---------------------------------------------------------------------------
local Court  = require("court")
local Player = require("player")

local Team = {}
Team.__index = Team

local SPOTS = {
    F1 = { depth = Court.FRONT_DEPTH, y = 1.5 },
    F2 = { depth = Court.FRONT_DEPTH, y = 4.5 },
    F3 = { depth = Court.FRONT_DEPTH, y = 7.5 },
    B1 = { depth = Court.BACK_DEPTH,  y = 1.5 },
    B2 = { depth = Court.BACK_DEPTH,  y = 4.5 },
    B3 = { depth = Court.BACK_DEPTH,  y = 7.5 },
}

local SPOT_PREFS = {
    Server  = { "B3", "B2", "B1", "F3", "F2", "F1" },
    Setter  = { "F3", "F2", "F1", "B2", "B3", "B1" },
    Blocker = { "F2", "F1", "F3", "B2", "B1", "B3" },
    Spiker  = { "F1", "F3", "F2", "B1", "B3", "B2" },
    Passer  = { "B1", "B2", "B3", "F1", "F2", "F3" },
}

local ROLE_ORDER = { "Server", "Setter", "Blocker", "Spiker", "Passer" }

local LINEUP = { "Server", "Setter", "Spiker", "Spiker", "Blocker", "Passer" }
local FIT = {
    Server  = function(p) return (p.strength + p.skill) / 2 end,
    Setter  = function(p) return p.skill end,
    Spiker  = function(p) return (p.strength + p:heightRating()) / 2 end,
    Blocker = function(p) return p:heightRating() end,
    Passer  = function(p) return (p.speed + p.skill) / 2 end,
}

function Team.new(players, side, palette, name)
    assert(#players <= 6, "a team has at most 6 players")
    local self = setmetatable({}, Team)
    self.players = players
    self.side = side
    self.palette = palette
    self.name = name
    self.opponent = nil
    self.touches = 0
    self.expect = nil
    for _, p in ipairs(players) do
        p.team = self
    end
    return self
end

-- Roles nobody in `players` has, in Player.ROLES order.
-- Written with a dot: it works on any list of players, not a Team.
function Team.missingRoles(players)
    local have = {}
    for _, p in ipairs(players) do
        have[p.role] = true
    end
    local missing = {}
    for _, role in ipairs(Player.ROLES) do
        if not have[role] then
            missing[#missing + 1] = role
        end
    end
    return missing
end

function Team:assignHomes()
    local taken = {}
    for _, role in ipairs(ROLE_ORDER) do
        for _, p in ipairs(self.players) do
            if p.role == role then
                for _, spot in ipairs(SPOT_PREFS[role]) do
                    if not taken[spot] then
                        taken[spot] = true
                        p.spot = spot
                        break
                    end
                end
            end
        end
    end
    for _, p in ipairs(self.players) do
        local s = SPOTS[p.spot]
        p.homeX = Court.depthToX(self.side, s.depth)
        p.homeY = s.y
    end
    self:resetPositions()
end

function Team:optimize()
    local free = {}
    for _, p in ipairs(self.players) do free[p] = true end
    local roles = {}
    for i, role in ipairs(LINEUP) do roles[i] = role end

    while #roles > 0 do
        local bestPlayer, bestIndex, bestScore
        for p in pairs(free) do
            for i, role in ipairs(roles) do
                local score = FIT[role](p)
                if not bestScore or score > bestScore then
                    bestPlayer, bestIndex, bestScore = p, i, score
                end
            end
        end
        if not bestPlayer then break end
        bestPlayer.role = roles[bestIndex]
        free[bestPlayer] = nil
        table.remove(roles, bestIndex)
    end
    self:assignHomes()
end

function Team:resetPositions()
    for _, p in ipairs(self.players) do
        p.x, p.y = p.homeX, p.homeY
        p.targetX, p.targetY = p.homeX, p.homeY
        p.delay = 0
        p.blocking = false
    end
    self.touches, self.expect = 0, nil
end

return Team