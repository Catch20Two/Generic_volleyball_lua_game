-- conf.lua — read by LÖVE before main.lua runs.
function love.conf(t)
    t.identity = "volleyball"     -- save folder name (settings.csv, later the run save)
    t.window.title = "Volleyball"
    t.window.width = 800          -- landscape
    t.window.height = 450
    t.window.resizable = true
    t.window.highdpi = true
end