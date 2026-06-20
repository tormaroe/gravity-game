-- bullet.lua
-- Represents a projectile fired by the ship.

local Audio = require("audio")

local Bullet = {}
local BULLET_SPEED   = 550  -- speed relative to ship muzzle
local BULLET_GRAVITY = 120  -- lower than ship gravity so they fly flatter
local TRAILING_TIME  = 0.012 -- length of tracer effect in seconds

function Bullet.new(startX, startY, angle, shipVx, shipVy, color)
    local self = setmetatable({}, { __index = Bullet })
    
    self.x = startX
    self.y = startY
    self.color = color or {1.0, 0.9, 0.4, 0.9} -- fallback for unit tests
    
    -- Calculate bullet velocity incorporating ship momentum
    self.vx = shipVx + math.sin(angle) * BULLET_SPEED
    self.vy = shipVy - math.cos(angle) * BULLET_SPEED
    
    self.isAlive = true
    
    return self
end

function Bullet:update(dt, terrain)
    if not self.isAlive then return end
    
    -- Apply gravity
    self.vy = self.vy + BULLET_GRAVITY * dt
    
    -- Integrate position
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    
    -- Boundary check (screen bounds)
    if self.x < 0 or self.x > 1024 or self.y < 0 or self.y > 768 then
        self.isAlive = false
        return
    end
    
    -- Terrain check (treating bullet as a small point for fast collision)
    for _, rect in ipairs(terrain) do
        local rx1, ry1 = rect.x, rect.y
        local rx2, ry2 = rect.x + rect.w, rect.y + rect.h
        
        if self.x >= rx1 and self.x <= rx2 and self.y >= ry1 and self.y <= ry2 then
            self.isAlive = false
            Audio.playHit()
            return
        end
    end
end

function Bullet:draw()
    if not self.isAlive then return end
    
    -- Draw as a small glowing tracer line
    love.graphics.setLineWidth(2)
    love.graphics.setColor(self.color)
    
    -- Tail is behind the bullet's current position based on velocity
    local tailX = self.x - self.vx * TRAILING_TIME
    local tailY = self.y - self.vy * TRAILING_TIME
    
    love.graphics.line(tailX, tailY, self.x, self.y)
    love.graphics.setColor(1, 1, 1)
end

return Bullet
