-- ship.lua
-- Represents the player's ship with physics state.

local Audio = require("audio")

local Ship = {}
Ship.__index = Ship

local ROTATE_SPEED   = math.pi * 1.0   -- radians per second (slower for fine control)
local THRUST_FORCE   = 450             -- pixels per second^2 (>2x gravity so lift-off feels decisive)
local SHIP_W         = 14
local SHIP_H         = 22
local DAMPING        = 0.995           -- very slight air resistance

function Ship.new(x, y, config)
    local self = setmetatable({}, Ship)
    self.x       = x
    self.y       = y
    self.vx      = 0
    self.vy      = 0
    self.angle   = 0        -- 0 = pointing up; radians, clockwise positive
    self.w       = SHIP_W
    self.h       = SHIP_H
    self.landed  = true   -- start resting; gravity won't apply until first liftoff
    self.thrusting = false

    -- Parse custom controls and colors (with defaults for unit tests)
    config = config or {}
    local controls = config.controls or {}
    self.key_left   = controls.left or "a"
    self.key_right  = controls.right or "d"
    self.key_thrust = controls.thrust or "w"

    local color = config.color or {}
    self.col_hull    = color.hull or {0.6, 0.85, 1.0}
    self.col_outline = color.outline or {0.9, 1.0, 1.0}
    self.col_cockpit = color.cockpit or {0.2, 0.5, 0.9}

    -- Propellant / Fuel state
    self.fuel = 1.0             -- 1.0 = 100% full
    self.click_cooldown = 0.0   -- failure sound timer

    return self
end

function Ship:update(dt)
    local GRAVITY = 120  -- pixels per second^2 downward (lowered for easier maneuvering)

    -- ── Rotation ─────────────────────────────────────────────
    if love.keyboard.isDown(self.key_left) then
        self.angle = self.angle - ROTATE_SPEED * dt
    end
    if love.keyboard.isDown(self.key_right) then
        self.angle = self.angle + ROTATE_SPEED * dt
    end

    -- ── Thrust & Propellant Logic ────────────────────────────
    local isThrustDown = love.keyboard.isDown(self.key_thrust)

    if self.click_cooldown > 0 then
        self.click_cooldown = self.click_cooldown - dt
    end

    if isThrustDown then
        if self.fuel > 0 then
            -- Deplete fuel: empty in 5 seconds (1/5 per sec)
            self.fuel = math.max(self.fuel - (1.0 / 5.0) * dt, 0)
            self.thrusting = true
            
            -- If fuel just ran out, kill thrusting
            if self.fuel <= 0 then
                self.thrusting = false
            end
        else
            self.thrusting = false
            -- Play engine failure click sound once every 0.6 seconds
            if self.click_cooldown <= 0 then
                Audio.playClick()
                self.click_cooldown = 0.6
            end
        end
    else
        self.thrusting = false
        -- Regenerate fuel when not thrusting: full in 10 seconds (1/10 per sec)
        self.fuel = math.min(self.fuel + (1.0 / 10.0) * dt, 1.0)
    end

    if self.thrusting then
        -- angle=0 means nose up; thrust in -sin/+cos of angle direction
        local tx = math.sin(self.angle) * THRUST_FORCE
        local ty = -math.cos(self.angle) * THRUST_FORCE
        self.vx = self.vx + tx * dt
        self.vy = self.vy + ty * dt
        self.landed = false -- liftoff
    end

    -- ── Gravity (skip if resting on ground) ──────────────────
    if not self.landed then
        self.vy = self.vy + GRAVITY * dt
    end

    -- ── Damping ──────────────────────────────────────────────
    self.vx = self.vx * DAMPING
    self.vy = self.vy * DAMPING

    -- ── Integration ──────────────────────────────────────────
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
end

-- Simple AABB collision: ship bounding box vs terrain rectangles.
-- Collision is the sole authority on self.landed each frame.
function Ship:collide(terrain)
    local hw = self.w / 2
    local hh = self.h / 2
    -- Ship bounding box (axis-aligned, used for collision only)
    local sx1, sy1 = self.x - hw, self.y - hh
    local sx2, sy2 = self.x + hw, self.y + hh

    -- Accumulate landed state; written to self.landed at the end.
    local isLanded = false

    for _, rect in ipairs(terrain) do
        local rx1, ry1 = rect.x, rect.y
        local rx2, ry2 = rect.x + rect.w, rect.y + rect.h

        -- AABB overlap test (>= so a flush-touching surface counts)
        if sx2 >= rx1 and sx1 <= rx2 and sy2 >= ry1 and sy1 <= ry2 then
            -- Compute overlap on each axis
            local overlapL = sx2 - rx1
            local overlapR = rx2 - sx1
            local overlapT = sy2 - ry1
            local overlapB = ry2 - sy1

            local minOverlap = math.min(overlapL, overlapR, overlapT, overlapB)

            if minOverlap == overlapT then
                -- Ship bottom hit top of terrain — land / bounce (push ship up)
                self.y = ry1 - hh
                if self.vy > 0 then
                    self.vx = self.vx * 0.7  -- landing friction
                    self.vy = 0
                end
                isLanded = true
            elseif minOverlap == overlapB then
                -- Ship top hit bottom of terrain — ceiling collision (push ship down)
                self.y = ry2 + hh
                if self.vy < 0 then self.vy = 0 end
            elseif minOverlap == overlapL then
                self.x = rx1 - hw
                if self.vx > 0 then self.vx = 0 end
            elseif minOverlap == overlapR then
                self.x = rx2 + hw
                if self.vx < 0 then self.vx = 0 end
            end

            -- Update bounding box after each resolution so multi-surface
            -- contacts (e.g. corner in a crevice) resolve correctly.
            sx1, sy1 = self.x - hw, self.y - hh
            sx2, sy2 = self.x + hw, self.y + hh
        end
    end

    -- ── Hard Screen Boundaries Clamping (Left/Right Walls, Roof, Ground) ─────
    -- Outer borders are 20px wall (left/right/ceiling) and 40px ground.
    -- Clamping coordinates prevents ships from tunneling outside the play field.
    local minX = 20 + hw
    local maxX = 1024 - 20 - hw
    local minY = 20 + hh
    local maxY = 768 - 40 - hh

    if self.x < minX then
        self.x = minX
        if self.vx < 0 then self.vx = 0 end
    elseif self.x > maxX then
        self.x = maxX
        if self.vx > 0 then self.vx = 0 end
    end

    if self.y < minY then
        self.y = minY
        if self.vy < 0 then self.vy = 0 end
    elseif self.y > maxY then
        self.y = maxY
        if self.vy > 0 then
            self.vx = self.vx * 0.7  -- landing friction on ground
            self.vy = 0
        end
        isLanded = true
    end

    self.landed = isLanded
end

function Ship:draw()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)

    -- Ship body (a slightly tapered rectangle)
    local hw = self.w / 2
    local hh = self.h / 2

    -- Hull
    love.graphics.setColor(self.col_hull)
    love.graphics.polygon("fill",
         hw * 0.4, -hh,   -- top-right (nose)
        -hw * 0.4, -hh,   -- top-left  (nose)
        -hw,        hh,   -- bottom-left
         hw,        hh    -- bottom-right
    )
    -- Outline
    love.graphics.setColor(self.col_outline)
    love.graphics.setLineWidth(1.2)
    love.graphics.polygon("line",
         hw * 0.4, -hh,
        -hw * 0.4, -hh,
        -hw,        hh,
         hw,        hh
    )

    -- Cockpit window
    love.graphics.setColor(self.col_cockpit)
    love.graphics.ellipse("fill", 0, -hh * 0.25, hw * 0.35, hh * 0.22)

    -- Thrust flame
    if self.thrusting then
        local flameH = 10 + math.random(0, 8)
        love.graphics.setColor(1.0, 0.5 + math.random() * 0.3, 0.1, 0.85)
        love.graphics.polygon("fill",
             hw * 0.35,  hh,
            -hw * 0.35,  hh,
             0,           hh + flameH
        )
        love.graphics.setColor(1.0, 0.9, 0.4, 0.6)
        love.graphics.polygon("fill",
             hw * 0.18,  hh,
            -hw * 0.18,  hh,
             0,           hh + flameH * 0.6
        )
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- Resolves axis-aligned bounding box collision between two ships.
-- Adjusts their coordinates to prevent clipping and performs an elastic bounce (swapping velocities with restitution).
function Ship.resolveCollision(s1, s2)
    local hw = s1.w / 2
    local hh = s1.h / 2
    
    local s1x1, s1y1 = s1.x - hw, s1.y - hh
    local s1x2, s1y2 = s1.x + hw, s1.y + hh
    
    local s2x1, s2y1 = s2.x - hw, s2.y - hh
    local s2x2, s2y2 = s2.x + hw, s2.y + hh
    
    -- Check overlap
    if s1x2 > s2x1 and s1x1 < s2x2 and s1y2 > s2y1 and s1y1 < s2y2 then
        local overlapL = s1x2 - s2x1
        local overlapR = s2x2 - s1x1
        local overlapT = s1y2 - s2y1
        local overlapB = s2y2 - s1y1
        
        local minOverlap = math.min(overlapL, overlapR, overlapT, overlapB)
        local bounceCoeff = 0.8  -- Coefficient of restitution (energy retention)
        
        if minOverlap == overlapL then
            -- s1 is left of s2: push s1 left, s2 right
            s1.x = s1.x - overlapL / 2
            s2.x = s2.x + overlapL / 2
            
            -- Bounce horizontal velocities
            local temp = s1.vx
            s1.vx = s2.vx * bounceCoeff
            s2.vx = temp * bounceCoeff
        elseif minOverlap == overlapR then
            -- s1 is right of s2: push s1 right, s2 left
            s1.x = s1.x + overlapR / 2
            s2.x = s2.x - overlapR / 2
            
            -- Bounce horizontal velocities
            local temp = s1.vx
            s1.vx = s2.vx * bounceCoeff
            s2.vx = temp * bounceCoeff
        elseif minOverlap == overlapT then
            -- s1 is above s2: push s1 up, s2 down
            s1.y = s1.y - overlapT / 2
            s2.y = s2.y + overlapT / 2
            
            -- Bounce vertical velocities
            local temp = s1.vy
            s1.vy = s2.vy * bounceCoeff
            s2.vy = temp * bounceCoeff
        elseif minOverlap == overlapB then
            -- s1 is below s2: push s1 down, s2 up
            s1.y = s1.y + overlapB / 2
            s2.y = s2.y - overlapB / 2
            
            -- Bounce vertical velocities
            local temp = s1.vy
            s1.vy = s2.vy * bounceCoeff
            s2.vy = temp * bounceCoeff
        end
        
        Audio.playHit()
    end
end

return Ship
