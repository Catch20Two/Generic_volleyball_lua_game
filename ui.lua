---------------------------------------------------------------------------
-- ui.lua — screen orientation, usable area, fonts, and widgets:
-- buttons, number text fields, a slider, role chips
-- (colors come from colors.lua)
--
-- Rotation: if the screen is taller than wide at startup, the whole game
-- is drawn turned 90°, so it plays in landscape with the phone held
-- sideways (turned counterclockwise). Screens never know: they always
-- see landscape coordinates.
--   physical : the real screen, as LÖVE reports it
--   virtual  : the landscape coordinates every screen draws in
---------------------------------------------------------------------------
local Colors = require("colors")

local UI = {}

UI.PAD = 8
UI.rotated = false

---------------------------------------------------------------------------
-- Orientation and area
---------------------------------------------------------------------------
function UI.chooseOrientation()
    local w, h = love.graphics.getDimensions()
    UI.rotated = h > w
end

-- Virtual screen size: width and height swap when rotated.
function UI.screenSize()
    local w, h = love.graphics.getDimensions()
    if UI.rotated then
        return h, w
    end
    return w, h
end

-- Physical touch position -> virtual position.
function UI.toVirtual(px, py)
    if not UI.rotated then
        return px, py
    end
    return py, love.graphics.getWidth() - px
end

function UI.applyTransform()
    if UI.rotated then
        love.graphics.translate(love.graphics.getWidth(), 0)
        love.graphics.rotate(math.pi / 2)
    end
end

-- The visible part of the screen, in virtual coordinates.
function UI.updateArea()
    local x, y, w, h = love.window.getSafeArea()
    if UI.rotated then
        local screenW = love.graphics.getWidth()
        x, y, w, h = y, screenW - (x + w), h, w
    end
    -- Extra margins by hand, in GAME (landscape) directions:
    -- y = y + 20       -- uncomment to push everything down
    -- h = h - 40       -- uncomment to shrink the height (top + bottom)
    UI.area = { x = x, y = y, w = w, h = h }
end

function UI.resize()
    UI.updateArea()
    local short = math.min(UI.area.w, UI.area.h)
    UI.font      = love.graphics.newFont(math.max(12, math.floor(short / 22)))
    UI.smallFont = love.graphics.newFont(math.max(10, math.floor(short / 30)))
    UI.bigFont   = love.graphics.newFont(math.max(16, math.floor(short / 12)))
end

-- Fills the whole virtual screen. Used to cover list rows that have
-- scrolled outside their area.
function UI.fillBackground(x, y, w, h)
    love.graphics.setColor(Colors.BACKGROUND)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
function UI.buttonHeight()
    return math.max(36, UI.font:getHeight() * 1.8)
end

function UI.newButton(text)
    return { x = 0, y = 0, w = 0, h = 0, text = text }
end

function UI.pointInRect(px, py, r)
    return px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

-- `enabled` is optional; only false disables a button.
function UI.hit(b, px, py)
    return b.enabled ~= false and UI.pointInRect(px, py, b)
end

-- font is optional (small buttons use UI.smallFont).
function UI.drawButton(b, font)
    font = font or UI.font
    local alpha = (b.enabled ~= false) and 1 or 0.4
    local bc, tc = Colors.BUTTON, Colors.TEXT
    love.graphics.setColor(bc[1], bc[2], bc[3], alpha)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h, 8)

    local textW = b.w - 8
    local _, lines = font:getWrap(b.text, textW)
    local textH = #lines * font:getHeight()
    love.graphics.setColor(tc[1], tc[2], tc[3], alpha)
    love.graphics.setFont(font)
    love.graphics.printf(b.text, b.x + 4, b.y + (b.h - textH) / 2, textW, "center")
    love.graphics.setColor(1, 1, 1)
end

-- Centered across the usable width. font and color are optional.
function UI.printCentered(text, y, font, color)
    love.graphics.setFont(font or UI.font)
    love.graphics.setColor(color or Colors.TEXT)
    love.graphics.printf(text, UI.area.x, y, UI.area.w, "center")
    love.graphics.setColor(1, 1, 1)
end

-- A tappable role label: a swatch of the role's shade plus its name.
function UI.drawRoleChip(r, role, palette, font)
    font = font or UI.smallFont
    love.graphics.setColor(Colors.BUTTON)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6)
    local sw = r.h - 8
    love.graphics.setColor(Colors.TEAM[palette or "user"][role])
    love.graphics.rectangle("fill", r.x + 4, r.y + 4, sw, sw)
    love.graphics.setColor(Colors.OUTLINE)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x + 4, r.y + 4, sw, sw)
    love.graphics.setColor(Colors.TEXT)
    love.graphics.setFont(font)
    love.graphics.print(role, r.x + sw + 10, r.y + (r.h - font:getHeight()) / 2)
    love.graphics.setColor(1, 1, 1)
end

---------------------------------------------------------------------------
-- Number text field
--
-- A field is { x, y, w, h, editing, buffer, maxDigits }. The screen calls
--   UI.startEditing(field, value)   when the field is tapped
--   UI.fieldTextInput(field, text)  from its textinput callback
--   UI.fieldKey(field, key)         from its keypressed callback
--   UI.stopEditing(field)           to finish; returns the number or nil
---------------------------------------------------------------------------
function UI.newField(maxDigits)
    return { x = 0, y = 0, w = 0, h = 0, editing = false, buffer = "", maxDigits = maxDigits or 2 }
end

function UI.startEditing(field, value)
    field.editing = true
    field.buffer = tostring(value)
    love.keyboard.setTextInput(true)      -- shows the on-screen keyboard
end

function UI.stopEditing(field)
    field.editing = false
    love.keyboard.setTextInput(false)
    return tonumber(field.buffer)         -- nil if the box was emptied
end

-- Digits only, up to maxDigits.
function UI.fieldTextInput(field, text)
    if field.editing and text:match("^%d+$") then
        field.buffer = (field.buffer .. text):sub(1, field.maxDigits)
    end
end

-- Returns "confirm", "cancel", "handled", or nil (not our key).
function UI.fieldKey(field, key)
    if not field.editing then return nil end
    if key == "backspace" then
        field.buffer = field.buffer:sub(1, -2)
        return "handled"
    elseif key == "return" or key == "kpenter" then
        return "confirm"
    elseif key == "escape" then
        return "cancel"
    end
end

function UI.drawField(field, value)
    love.graphics.setColor(Colors.FIELD)
    love.graphics.rectangle("fill", field.x, field.y, field.w, field.h, 6)
    local text = tostring(value)
    if field.editing then
        love.graphics.setColor(Colors.ACTIVE)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", field.x, field.y, field.w, field.h, 6)
        local cursor = (love.timer.getTime() % 1 < 0.5) and "_" or " "
        text = field.buffer .. cursor
    end
    love.graphics.setColor(Colors.TEXT)
    love.graphics.setFont(UI.font)
    love.graphics.printf(text, field.x, field.y + (field.h - UI.font:getHeight()) / 2,
        field.w, "center")
    love.graphics.setColor(1, 1, 1)
end

---------------------------------------------------------------------------
-- Slider: value from 0 to 1, dragged by its knob
---------------------------------------------------------------------------
function UI.newSlider(value)
    return { x = 0, y = 0, w = 0, h = 0, value = value or 0.5, dragging = false }
end

-- Returns true if the press grabbed the slider.
function UI.sliderPressed(s, px, py)
    local grab = { x = s.x - s.h / 2, y = s.y, w = s.w + s.h, h = s.h }
    if UI.pointInRect(px, py, grab) then
        s.dragging = true
        UI.sliderMoved(s, px)
        return true
    end
    return false
end

function UI.sliderMoved(s, px)
    if s.dragging then
        s.value = math.max(0, math.min(1, (px - s.x) / s.w))
    end
end

function UI.sliderReleased(s)
    s.dragging = false
end

function UI.drawSlider(s)
    local cy = s.y + s.h / 2
    local fillX = s.x + s.w * s.value
    love.graphics.setLineWidth(4)
    love.graphics.setColor(Colors.SLIDER_TRACK)
    love.graphics.line(s.x, cy, s.x + s.w, cy)
    love.graphics.setColor(Colors.SLIDER_FILL)
    love.graphics.line(s.x, cy, fillX, cy)
    love.graphics.setColor(Colors.SLIDER_KNOB)
    love.graphics.circle("fill", fillX, cy, s.h * 0.35)
    love.graphics.setColor(Colors.OUTLINE)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", fillX, cy, s.h * 0.35)
    love.graphics.setColor(1, 1, 1)
end

return UI