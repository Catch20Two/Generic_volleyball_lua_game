---------------------------------------------------------------------------
-- main.lua — loads shared data, registers screens, routes input
--
-- Flow: start -> select -> game <-> training -> result -> start
--       start -> settings -> start
--       start -> (CONTINUE) game
---------------------------------------------------------------------------
local Screens  = require("screens")
local UI       = require("ui")
local Colors   = require("colors")
local Settings = require("settings")
local Generate = require("generate")

function love.load()
    love.graphics.setBackgroundColor(Colors.BACKGROUND)
    UI.chooseOrientation()
    UI.resize()
    Settings.load()
    Generate.loadNames("names.csv")

    Screens.register("start",    require("screens.start"))
    Screens.register("select",   require("screens.select"))
    Screens.register("settings", require("screens.settings"))
    Screens.register("game",     require("screens.game"))
    Screens.register("training", require("screens.training"))
    Screens.register("result",   require("screens.result"))
    Screens.switch("start")
end

for _, event in ipairs({ "update", "textinput" }) do
    love[event] = function(...)
        return Screens.call(event, ...)
    end
end

function love.draw()
    love.graphics.push()
    UI.applyTransform()
    Screens.call("draw")
    love.graphics.pop()
end

function love.resize(w, h)
    -- UI.chooseOrientation()       -- uncomment to recheck rotation on every resize
    UI.resize()
    Screens.call("resize", w, h)
end

-- Mouse and touch merged, converted to virtual (landscape) coordinates.
function love.mousepressed(x, y, button, istouch)
    if button == 1 and not istouch then Screens.call("pointerpressed", UI.toVirtual(x, y)) end
end
function love.mousemoved(x, y, _, _, istouch)
    if not istouch then Screens.call("pointermoved", UI.toVirtual(x, y)) end
end
function love.mousereleased(x, y, button, istouch)
    if button == 1 and not istouch then Screens.call("pointerreleased", UI.toVirtual(x, y)) end
end
function love.touchpressed(_, x, y)  Screens.call("pointerpressed", UI.toVirtual(x, y))  end
function love.touchmoved(_, x, y)    Screens.call("pointermoved", UI.toVirtual(x, y))    end
function love.touchreleased(_, x, y) Screens.call("pointerreleased", UI.toVirtual(x, y)) end

-- The screen gets first chance at a key; returning true means "handled".
-- Escape / Android Back goes to the screen's `back`, or quits.
function love.keypressed(key, scancode, isrepeat)
    if Screens.call("keypressed", key, scancode, isrepeat) then return end
    if key == "escape" then
        local back = Screens.current and Screens.current.back
        if back then Screens.switch(back) else love.event.quit() end
    end
end