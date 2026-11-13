local Screens = { list = {}, current = nil, currentName = nil }

function Screens.register(name, screen)
    Screens.list[name] = screen
end

-- Extra arguments go to the new screen's enter(), e.g.
--     Screens.switch("win", "p1", "Computer ran out of health")
-- arrives as  win.enter("p1", "Computer ran out of health").
function Screens.switch(name, ...)
    local nextScreen = assert(Screens.list[name], "no screen named " .. tostring(name))
    if Screens.current and Screens.current.leave then
        Screens.current.leave()
    end
    Screens.current = nextScreen
    Screens.currentName = name
    if nextScreen.enter then
        nextScreen.enter(...)
    end
end

-- Call one function on the current screen, if it has it. A screen only
-- defines the callbacks it needs; missing ones are simply skipped.
function Screens.call(event, ...)
    local s = Screens.current
    if s and s[event] then
        return s[event](...)
    end
end

return Screens
