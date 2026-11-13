---------------------------------------------------------------------------
-- settings.lua — game settings, saved to settings.csv in the save folder
--
--   Settings.values.pointsPerMatch   points needed to win a match
--   Settings.values.matchesToWin     matches needed to win the game
--   Settings.values.variety          max spread between a new player's stats
--   Settings.values.volume           placeholder, 0 to 1
---------------------------------------------------------------------------
local csv = require("csv")

local Settings = {}

local FILE = "settings.csv"

Settings.DEFAULTS = { pointsPerMatch = 5, matchesToWin = 5, variety = 20, volume = 0.5 }
Settings.RANGES = {
    pointsPerMatch = { 1, 25 },
    matchesToWin   = { 1, 10 },
    variety        = { 0, 60 },
    volume         = { 0, 1 },
}
Settings.ORDER = { "pointsPerMatch", "matchesToWin", "variety", "volume" }

Settings.values = {}

-- Clamp into range. Volume is a fraction; everything else is a whole number.
function Settings.set(key, value)
    local range = Settings.RANGES[key]
    assert(range, "unknown setting '" .. tostring(key) .. "'")
    value = tonumber(value) or Settings.DEFAULTS[key]
    if key ~= "volume" then value = math.floor(value) end
    Settings.values[key] = math.max(range[1], math.min(range[2], value))
end

function Settings.resetDefaults()
    for key, value in pairs(Settings.DEFAULTS) do
        Settings.values[key] = value
    end
end

function Settings.load()
    Settings.resetDefaults()
    if not csv.exists(FILE) then return end
    for _, row in ipairs(csv.load(FILE)) do
        if Settings.RANGES[row.key] then
            Settings.set(row.key, row.value)
        end
    end
end

function Settings.save()
    local rows = {}
    for _, key in ipairs(Settings.ORDER) do
        rows[#rows + 1] = { key = key, value = Settings.values[key] }
    end
    csv.save(FILE, rows, { "key", "value" })
end

return Settings