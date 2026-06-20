-- main.lua
-- Entry point for the Gravity Force clone.

local Ship  = require("ship")
local World = require("world")
local Audio = require("audio")
local Bullet = require("bullet")

-- ── State ──────────────────────────────────────────────────────────────────
local world
local ship
local starfield   -- background stars for ambiance
local bullets = {} -- active projectiles

-- Platform spawn position (centre of the starting platform)
local PLATFORM_X  = 180 + 80   -- platform.x + platform.w/2
local PLATFORM_Y  = 768 - 140  -- platform.y  (top of platform)

-- ── Helpers ────────────────────────────────────────────────────────────────
local function makeStars(count)
    local stars = {}
    for i = 1, count do
        stars[i] = {
            x  = math.random(0, 1024),
            y  = math.random(0, 768),
            r  = math.random() * 1.2 + 0.3,
            br = math.random() * 0.5 + 0.5,   -- brightness
        }
    end
    return stars
end

-- ── LÖVE callbacks ─────────────────────────────────────────────────────────
function love.load(arg)
    -- Check for command line flags (like --test)
    local isTest = false
    if arg then
        for _, val in ipairs(arg) do
            if val == "--test" then
                isTest = true
                break
            end
        end
    end

    if isTest then
        local tests = require("tests")
        local success = tests.run()
        love.event.quit(success and 0 or 1)
        return
    end

    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")

    world     = World.new()
    starfield = makeStars(120)

    -- Place ship so its bottom edge sits flush on the platform surface
    local shipH = 22
    ship = Ship.new(PLATFORM_X, PLATFORM_Y - shipH / 2 + 2)

    -- Initialize procedural audio engine
    Audio.init()
end

function love.update(dt)
    -- Cap dt to avoid huge jumps when window is moved / unfocused
    dt = math.min(dt, 1/30)
    ship:update(dt, world:getRects())

    -- Update active projectiles
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b:update(dt, world:getRects())
        if not b.isAlive then
            table.remove(bullets, i)
        end
    end

    -- Update procedural audio state
    Audio.update(dt, ship.thrusting)
end

function love.draw()
    -- ── Background ───────────────────────────────────────────
    love.graphics.setBackgroundColor(0.04, 0.05, 0.08)
    love.graphics.clear(0.04, 0.05, 0.08)

    -- Stars
    for _, s in ipairs(starfield) do
        love.graphics.setColor(s.br, s.br, s.br, s.br)
        love.graphics.circle("fill", s.x, s.y, s.r)
    end

    -- ── World geometry ───────────────────────────────────────
    world:draw()

    -- ── Projectiles ──────────────────────────────────────────
    for _, b in ipairs(bullets) do
        b:draw()
    end

    -- ── Ship ─────────────────────────────────────────────────
    ship:draw()

    -- ── HUD ──────────────────────────────────────────────────
    drawHUD()
end

function drawHUD()
    love.graphics.setColor(0.7, 0.9, 0.7, 0.9)
    love.graphics.setLineWidth(1)

    -- Speed readout
    local speed = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
    love.graphics.printf(
        string.format("SPD  %5.1f\nANG  %5.1f°",
            speed,
            math.deg(ship.angle) % 360
        ),
        20, 20, 200, "left"
    )

    -- Status
    local status = ship.landed and "LANDED" or "AIRBORNE"
    local sc = ship.landed and {0.4, 1.0, 0.4} or {1.0, 0.7, 0.3}
    love.graphics.setColor(sc[1], sc[2], sc[3], 0.9)
    love.graphics.printf(status, 20, 60, 200, "left")

    -- Controls reminder
    love.graphics.setColor(0.5, 0.6, 0.5, 0.6)
    love.graphics.printf(
        "A / D  rotate     W  thrust     Space  fire     R  reset",
        0, 748, 1024, "center"
    )
    love.graphics.setColor(1, 1, 1)
end

function love.keypressed(key)
    if key == "r" then
        -- Soft reset: put ship back on the platform
        local shipH = 22
        ship = Ship.new(PLATFORM_X, PLATFORM_Y - shipH / 2 + 2)
        bullets = {}
    end
    if key == "space" then
        -- Spawn bullet from the nose of the ship
        local hh = ship.h / 2
        local spawnX = ship.x + math.sin(ship.angle) * hh
        local spawnY = ship.y - math.cos(ship.angle) * hh
        
        local b = Bullet.new(spawnX, spawnY, ship.angle, ship.vx, ship.vy)
        table.insert(bullets, b)
        Audio.playShoot()
    end
    if key == "escape" then
        love.event.quit()
    end
end
