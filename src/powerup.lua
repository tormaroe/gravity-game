-- powerup.lua
-- Represents a floating powerup item.

local Powerup = {}
Powerup.__index = Powerup

function Powerup.new(x, y, powerType)
    local self = setmetatable({}, Powerup)
    self.x = x
    self.y = y
    self.type = powerType or "BULLET_SPRAY"
    self.life = 15.0 -- stays for 15 seconds
    self.r = 12
    
    -- Drift slowly in a random direction (speed: 35-60 pixels/sec)
    local angle = math.random() * 2 * math.pi
    local speed = math.random(35, 60)
    self.vx = math.cos(angle) * speed
    self.vy = math.sin(angle) * speed
    
    return self
end

function Powerup:update(dt, rects)
    self.life = self.life - dt
    if self.life <= 0 then
        return
    end

    -- 1. Apply movement
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- 2. Bounce off cave boundaries
    local hw = self.r
    local hh = self.r
    local minX = 20 + hw
    local maxX = 1024 - 20 - hw
    local minY = 20 + hh
    local maxY = 768 - 40 - hh

    if self.x < minX then
        self.x = minX
        self.vx = -self.vx
    elseif self.x > maxX then
        self.x = maxX
        self.vx = -self.vx
    end

    if self.y < minY then
        self.y = minY
        self.vy = -self.vy
    elseif self.y > maxY then
        self.y = maxY
        self.vy = -self.vy
    end

    -- 3. Bounce off world terrain blocks
    for _, r in ipairs(rects) do
        if self.x + hw > r.x and self.x - hw < r.x + r.w and
           self.y + hh > r.y and self.y - hh < r.y + r.h then
            
            -- Resolve overlap and reflect
            local overlapL = (self.x + hw) - r.x
            local overlapR = (r.x + r.w) - (self.x - hw)
            local overlapT = (self.y + hh) - r.y
            local overlapB = (r.y + r.h) - (self.y - hh)
            
            local minOverlap = math.min(overlapL, overlapR, overlapT, overlapB)
            if minOverlap == overlapL then
                self.x = r.x - hw
                self.vx = -self.vx
            elseif minOverlap == overlapR then
                self.x = r.x + r.w + hw
                self.vx = -self.vx
            elseif minOverlap == overlapT then
                self.y = r.y - hh
                self.vy = -self.vy
            else
                self.y = r.y + r.h + hh
                self.vy = -self.vy
            end
        end
    end
end

function Powerup:draw(fontSmall)
    if self.life <= 0 then return end

    -- Determine blinking alpha when close to despawning (< 2.5s left)
    local alpha = 1.0
    if self.life < 2.5 then
        -- Fast blinking (6 Hz)
        alpha = 0.25 + 0.75 * (math.floor(love.timer.getTime() * 12) % 2)
    end

    -- Pulsating sizing using a high LFO
    local pulse = 1.0 + 0.12 * math.sin(love.timer.getTime() * 8)
    local drawR = self.r * pulse

    -- Outer neon glow ring, body, and outline based on powerup type
    if self.type == "SHIELD" then
        -- Cyan/Blue colors for Shield
        love.graphics.setColor(0.1, 0.65, 1.0, 0.22 * alpha)
        love.graphics.circle("fill", self.x, self.y, drawR + 5)

        love.graphics.setColor(0.05, 0.5, 0.95, 0.85 * alpha)
        love.graphics.circle("fill", self.x, self.y, drawR)

        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(0.5, 0.85, 1.0, 0.95 * alpha)
        love.graphics.circle("line", self.x, self.y, drawR)
    else
        -- Orange/Gold colors for Bullet Spray
        love.graphics.setColor(1.0, 0.65, 0.1, 0.22 * alpha)
        love.graphics.circle("fill", self.x, self.y, drawR + 5)

        love.graphics.setColor(0.95, 0.5, 0.05, 0.85 * alpha)
        love.graphics.circle("fill", self.x, self.y, drawR)

        love.graphics.setLineWidth(1.5)
        love.graphics.setColor(1.0, 0.85, 0.5, 0.95 * alpha)
        love.graphics.circle("line", self.x, self.y, drawR)
    end

    -- Emblem: 'S' for Bullet Spray, 'H' for Shield
    if fontSmall then
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(1.0, 1.0, 1.0, alpha)
        local emblem = (self.type == "SHIELD") and "H" or "S"
        love.graphics.printf(emblem, self.x - 15, self.y - 6, 30, "center")
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Powerup
