---------------------------------------------------------------------------
-- run.lua — the current run (one attempt at winning the game) and its save
--
-- Every screen reads and changes the run through this module.
--   Run.candidates   the 12 players offered on the selection screen
--   Run.selected     which of them are picked: Run.selected[player] = true
--   Run.user         your 6 players
--   Run.opponents    the 6 players you face next
--   Run.matchNumber, Run.pointsPerMatch, Run.matchesToWin
--
-- The two settings are copied into the run when it starts, so changing
-- Settings later only affects the next NEW game.
--
-- Saved as two CSV files in the save folder:
--   run.csv     key,value      (matchNumber, pointsPerMatch, matchesToWin)
--   roster.csv  one row per player, with a `team` column: user or computer
---------------------------------------------------------------------------
local csv      = require("csv")
local Player   = require("player")
local Generate = require("generate")
local Settings = require("settings")

local Run = {}

local RUN_FILE    = "run.csv"
local ROSTER_FILE = "roster.csv"
local PLAYER_COLUMNS = { "team", "name", "heightIn", "strength", "speed", "skill", "role" }

Run.candidates = nil
Run.selected = {}
Run.user = nil
Run.opponents = nil
Run.matchNumber = 1
Run.pointsPerMatch = nil
Run.matchesToWin = nil

-- NEW: 12 fresh players to choose from.
function Run.newSelection()
    Run.candidates = Generate.candidates(12)
    Run.selected = {}
end

-- START on the selection screen. Saving here replaces any older save,
-- so a previous run only disappears once the new one actually begins.
function Run.start(players)
    Run.user = players
    Run.matchNumber = 1
    Run.pointsPerMatch = Settings.values.pointsPerMatch
    Run.matchesToWin = Settings.values.matchesToWin
    Run.opponents = Generate.opponents(1, "right").players
    Run.save()
end

-- After winning a match: next number, new (harder) opponents, save.
function Run.advance()
    Run.matchNumber = Run.matchNumber + 1
    Run.opponents = Generate.opponents(Run.matchNumber, "right").players
    Run.save()
end

function Run.isLastMatch()
    return Run.matchNumber >= Run.matchesToWin
end

local function playerRow(team, p)
    return {
        team = team, name = p.name, heightIn = p.heightIn,
        strength = p.strength, speed = p.speed, skill = p.skill, role = p.role,
    }
end

function Run.save()
    csv.save(RUN_FILE, {
        { key = "matchNumber",    value = Run.matchNumber },
        { key = "pointsPerMatch", value = Run.pointsPerMatch },
        { key = "matchesToWin",   value = Run.matchesToWin },
    }, { "key", "value" })

    local rows = {}
    for _, p in ipairs(Run.user) do rows[#rows + 1] = playerRow("user", p) end
    for _, p in ipairs(Run.opponents) do rows[#rows + 1] = playerRow("computer", p) end
    csv.save(ROSTER_FILE, rows, PLAYER_COLUMNS)
end

function Run.hasSave()
    return love.filesystem.getInfo(RUN_FILE) ~= nil
        and love.filesystem.getInfo(ROSTER_FILE) ~= nil
end

-- Returns true if a complete save was loaded.
function Run.load()
    if not Run.hasSave() then return false end

    local values = {}
    for _, row in ipairs(csv.load(RUN_FILE)) do
        values[row.key] = row.value
    end

    local validRole = {}
    for _, role in ipairs(Player.ROLES) do validRole[role] = true end

    local user, computer = {}, {}
    for _, row in ipairs(csv.load(ROSTER_FILE)) do
        if not validRole[row.role] then row.role = "Passer" end
        local list = (row.team == "user") and user or computer
        list[#list + 1] = Player.new(row)
    end

    if #user ~= 6 or #computer ~= 6 or type(values.matchNumber) ~= "number" then
        return false                         -- damaged save: ignore it
    end
    Run.user, Run.opponents = user, computer
    Run.matchNumber = values.matchNumber
    Run.pointsPerMatch = values.pointsPerMatch or Settings.values.pointsPerMatch
    Run.matchesToWin = values.matchesToWin or Settings.values.matchesToWin
    return true
end

-- The run is over (won or lost): delete the save.
function Run.clear()
    love.filesystem.remove(RUN_FILE)
    love.filesystem.remove(ROSTER_FILE)
    Run.user, Run.opponents = nil, nil
end

return Run