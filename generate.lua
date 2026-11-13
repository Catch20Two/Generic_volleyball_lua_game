---------------------------------------------------------------------------
-- generate.lua — random players and teams
---------------------------------------------------------------------------
local csv      = require("csv")
local Player   = require("player")
local Team     = require("team")
local Settings = require("settings")

local Generate = {}

Generate.STAT_TOTAL = 200              -- split across strength, speed, skill
Generate.OPPONENT_POINTS_PER_MATCH = 8 -- match n opponents get 8 x n extra

local names = {}

function Generate.loadNames(path)
    if not csv.exists(path) then return end
    for _, row in ipairs(csv.load(path)) do
        if row.name then
            names[#names + 1] = tostring(row.name)
        end
    end
end

local function randomName()
    if #names == 0 then
        return "Player " .. love.math.random(99)
    end
    return names[love.math.random(#names)]          -- names may repeat
end

-- Split `total` into 3 whole numbers whose largest and smallest differ by
-- at most `variety`. Start from an even split, then move single points
-- between random stats, undoing any move that breaks the limit.
-- (An even split of 200 is 67/67/66, so the spread is always at least 1.)
function Generate.splitStats(total, variety)
    local base = math.floor(total / 3)
    local s = { base, base, base }
    for i = 1, total - 3 * base do
        s[i] = s[i] + 1
    end
    local limit = math.max(variety, 1)
    for _ = 1, 300 do
        local from, to = love.math.random(3), love.math.random(3)
        if from ~= to and s[from] > 0 then
            s[from], s[to] = s[from] - 1, s[to] + 1
            if math.max(s[1], s[2], s[3]) - math.min(s[1], s[2], s[3]) > limit then
                s[from], s[to] = s[from] + 1, s[to] - 1     -- undo
            end
        end
    end
    return s[1], s[2], s[3]
end

-- role is optional: missing means a random role.
function Generate.player(total, variety, role)
    local strength, speed, skill = Generate.splitStats(total, variety)
    return Player.new({
        name     = randomName(),
        heightIn = love.math.random(Player.MIN_HEIGHT_IN, Player.MAX_HEIGHT_IN),
        strength = strength,
        speed    = speed,
        skill    = skill,
        role     = role or Player.ROLES[love.math.random(#Player.ROLES)],
    })
end

-- Players for the selection screen.
function Generate.candidates(n)
    local list = {}
    for i = 1, n do
        list[i] = Generate.player(Generate.STAT_TOTAL, Settings.values.variety)
    end
    return list
end

-- A computer team for match `matchNumber`: 6 players, plus 8 x n extra
-- points dropped one at a time on random players and stats, then the
-- best-suited lineup.
function Generate.opponents(matchNumber, side)
    local players = Generate.candidates(6)
    local stats = { "strength", "speed", "skill" }
    for _ = 1, Generate.OPPONENT_POINTS_PER_MATCH * matchNumber do
        local p = players[love.math.random(#players)]
        local stat = stats[love.math.random(#stats)]
        p[stat] = p[stat] + 1          -- p["speed"] is the same as p.speed
    end
    local team = Team.new(players, side, "computer", "Opponent")
    team:optimize()
    return team
end

-- New players offered in Training, with a stat total close to the team's
-- current average (trained points included).
function Generate.trainingCandidates(team, n)
    local sum = 0
    for _, p in ipairs(team.players) do
        sum = sum + p:statTotal()
    end
    local total = math.floor(sum / #team.players + 0.5)
    local list = {}
    for i = 1, n do
        list[i] = Generate.player(total, Settings.values.variety)
    end
    return list
end

return Generate