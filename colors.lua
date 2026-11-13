---------------------------------------------------------------------------
-- colors.lua — every color in the game, in one place
--
-- LÖVE colors are {r, g, b, a} with values from 0 to 1. The rgb() helper
-- lets you write them the familiar 0–255 way; alpha stays 0–1.
---------------------------------------------------------------------------
local function rgb(r, g, b, alpha)
    local cr, cg, cb = love.math.colorFromBytes(r, g, b)
    return { cr, cg, cb, alpha or 1 }
end

local Colors = {}

-- Screens and buttons
Colors.BACKGROUND   = rgb(178, 205, 219)
Colors.TEXT         = rgb(30, 45, 60)
Colors.WARNING      = rgb(170, 60, 40)          -- "Missing roles" line
Colors.BUTTON       = rgb(240, 227, 213)
Colors.FIELD        = rgb(255, 255, 255)        -- text field background
Colors.ACTIVE       = rgb(70, 120, 200)         -- field being typed in
Colors.OVERLAY      = rgb(0, 0, 0, 0.55)        -- dark layer behind the pause menu
Colors.BANNER       = rgb(255, 255, 255)        -- "Point: You" over the court

-- Lists and cards (selection and training screens)
Colors.ROW          = rgb(255, 255, 255, 0.45)
Colors.ROW_SELECTED = rgb(255, 236, 150)
Colors.SWAP_TARGET  = rgb(255, 160, 60)         -- outline while choosing who to replace

-- Slider
Colors.SLIDER_TRACK = rgb(120, 120, 120)
Colors.SLIDER_FILL  = rgb(70, 120, 200)
Colors.SLIDER_KNOB  = rgb(255, 255, 255)

-- Court
Colors.FLOOR        = rgb(222, 184, 135)        -- inside the lines
Colors.FLOOR_OUT    = rgb(196, 160, 118)        -- floor beyond the end lines
Colors.COURT_LINE   = rgb(255, 255, 255)
Colors.GRID         = rgb(128, 128, 128, 0.35)  -- faint gray 3x3 cells
Colors.NET          = rgb(30, 30, 30)
Colors.NET_MESH     = rgb(30, 30, 30, 0.25)

-- Ball and outlines
Colors.BALL         = rgb(255, 255, 255)
Colors.SHADOW       = rgb(0, 0, 0, 0.25)
Colors.OUTLINE      = rgb(0, 0, 0)

-- Players: one shade per role, darkest to lightest.
-- Your team is blue; the computer's is green.
Colors.TEAM = {
    user = {
        Server  = rgb(20, 35, 90),
        Spiker  = rgb(35, 85, 200),
        Setter  = rgb(90, 150, 235),
        Blocker = rgb(150, 195, 245),
        Passer  = rgb(205, 225, 250),
    },
    computer = {
        Server  = rgb(15, 70, 30),
        Spiker  = rgb(35, 130, 55),
        Setter  = rgb(80, 170, 80),
        Blocker = rgb(140, 205, 120),
        Passer  = rgb(200, 235, 185),
    },
}

return Colors