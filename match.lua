---------------------------------------------------------------------------
-- match.lua — score and serve across rallies; first to N points wins
---------------------------------------------------------------------------
local Rally = require("rally")

local Match = {}
Match.__index = Match

Match.POINT_PAUSE = 0.8      -- seconds between points

-- o = { teams = { left =, right = }, ball =, pointsToWin =, say = function }
function Match.new(o)
    local self = setmetatable({}, Match)
    self.teams, self.ball, self.pointsToWin, self.say = o.teams, o.ball, o.pointsToWin, o.say
    self.teams.left.opponent = self.teams.right
    self.teams.right.opponent = self.teams.left
    self.score = { left = 0, right = 0 }
    self.serving = (love.math.random(2) == 1) and self.teams.left or self.teams.right
    self.winner, self.banner, self.timer = nil, nil, 0
    self:startRally()
    return self
end

function Match:startRally()
    self.banner = nil
    self.state = "rally"            -- "rally", "between" or "over"
    self.rally = Rally.new({
        ball = self.ball, teams = self.teams, serving = self.serving, say = self.say,
    })
end

function Match:update(dt)
    self.rally:update(dt)           -- keeps players moving between points too

    if self.state == "rally" and self.rally.winner then
        local w = self.rally.winner
        self.score[w.side] = self.score[w.side] + 1
        self.serving = w            -- the rally winner serves next
        if self.score[w.side] >= self.pointsToWin then
            self.state, self.winner = "over", w
            self.banner = (w.palette == "user") and "Match won!" or "Match lost"
        else
            self.state, self.timer = "between", Match.POINT_PAUSE
            self.banner = "Point: " .. w.name
        end
    elseif self.state == "between" then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self:startRally()
        end
    end
end

return Match