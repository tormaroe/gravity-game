-- world.lua
-- Defines the level geometry as a list of axis-aligned rectangles.
-- Each rect: { x, y, w, h, color }

local World = {}
World.__index = World

local SW = 1024   -- screen width
local SH = 768    -- screen height

-- Colour palette
local COL_GROUND   = {0.18, 0.22, 0.18}
local COL_ROCK     = {0.28, 0.32, 0.28}
local COL_PLATFORM = {0.40, 0.70, 0.40}

function World.new()
    local self = setmetatable({}, World)

    -- ── Terrain rectangles ─────────────────────────────────────
    self.terrain = {
        -- Main ground floor
        { x = 0,    y = SH - 40, w = SW,  h = 40,   color = COL_GROUND },

        -- Roof/Ceiling
        { x = 0,    y = 0,       w = SW,  h = 20,   color = COL_ROCK   },

        -- Left wall
        { x = 0,    y = 0,       w = 20,  h = SH,   color = COL_ROCK   },
        -- Right wall
        { x = SW-20,y = 0,       w = 20,  h = SH,   color = COL_ROCK   },

        -- Starting platform (raised ledge, left-center)
        { x = 180,  y = SH - 140, w = 160, h = 18,  color = COL_PLATFORM },

        -- Second starting platform (raised ledge, right-center, symmetric)
        { x = SW - 180 - 160, y = SH - 140, w = 160, h = 18, color = COL_PLATFORM },

        -- ── Middle Obstacles (Symmetric) ───────────────────────────
        -- 1. Center Ground Pillar (rising up from the floor)
        { x = 512 - 30, y = SH - 40 - 200, w = 60, h = 200, color = COL_ROCK },

        -- 2. Center Ceiling Pillar (hanging down from the roof)
        { x = 512 - 30, y = 20,            w = 60, h = 180, color = COL_ROCK },

        -- 3. Left Side Floating Island
        { x = 360,      y = math.floor(SH / 2) - 40,   w = 80, h = 40,  color = COL_ROCK },

        -- 4. Right Side Floating Island (symmetric to Left)
        { x = SW - 360 - 80, y = math.floor(SH / 2) - 40, w = 80, h = 40,  color = COL_ROCK },
    }

    return self
end

-- Returns the list of rect tables used for collision.
function World:getRects()
    return self.terrain
end

function World:draw()
    for _, rect in ipairs(self.terrain) do
        -- Fill
        love.graphics.setColor(rect.color)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)

        -- Subtle bright top edge for depth
        love.graphics.setColor(
            math.min(rect.color[1] + 0.15, 1),
            math.min(rect.color[2] + 0.15, 1),
            math.min(rect.color[3] + 0.15, 1)
        )
        love.graphics.setLineWidth(1.5)
        love.graphics.line(rect.x, rect.y, rect.x + rect.w, rect.y)
    end
    love.graphics.setColor(1, 1, 1)
end

return World
