-- main.lua
-- Entry point for the Gravity Force clone.

local Ship  = require("ship")
local World = require("world")
local Audio = require("audio")
local Bullet = require("bullet")

-- ── State ──────────────────────────────────────────────────────────────────
local world
local ship1  -- Player 1 (Blue)
local ship2  -- Player 2 (Red)
local starfield   -- background stars for ambiance
local bullets = {} -- active projectiles
local gameCanvas  -- Canvas for scaling resolution

-- Platform spawn positions (symmetric)
local PLATFORM_1_X  = 180 + 80         -- Left platform center
local PLATFORM_1_Y  = 768 - 140
local PLATFORM_2_X  = 1024 - 180 - 80  -- Right platform center (symmetric)
local PLATFORM_2_Y  = 768 - 140

-- Player 1 (Blue) configuration
local CONFIG_P1 = {
    controls = { left = "a", right = "d", thrust = "w" },
    color = {
        hull    = {0.15, 0.45, 0.9},
        outline = {0.5, 0.8, 1.0},
        cockpit = {0.0, 0.2, 0.6}
    }
}

-- Player 2 (Red) configuration
local CONFIG_P2 = {
    controls = { left = "left", right = "right", thrust = "up" },
    color = {
        hull    = {0.9, 0.2, 0.15},
        outline = {1.0, 0.5, 0.5},
        cockpit = {0.6, 0.0, 0.0}
    }
}

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
    -- Check for command line flags (like --test and --fullscreen)
    local isTest = false
    local isFullscreen = false
    if arg then
        for _, val in ipairs(arg) do
            if val == "--test" then
                isTest = true
            elseif val == "--fullscreen" or val == "-f" then
                isFullscreen = true
            end
        end
    end

    if isTest then
        local tests = require("tests")
        local success = tests.run()
        love.event.quit(success and 0 or 1)
        return
    end

    if isFullscreen then
        love.window.setFullscreen(true)
    end

    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")

    world     = World.new()
    starfield = makeStars(120)

    -- Place both ships on their respective platforms
    local shipH = 22
    ship1 = Ship.new(PLATFORM_1_X, PLATFORM_1_Y - shipH / 2 + 2, CONFIG_P1)
    ship2 = Ship.new(PLATFORM_2_X, PLATFORM_2_Y - shipH / 2 + 2, CONFIG_P2)

    -- Create Canvas for scaling resolution
    gameCanvas = love.graphics.newCanvas(1024, 768)

    -- Initialize procedural audio engine
    Audio.init()
end

function love.update(dt)
    -- Cap dt to avoid huge jumps when window is moved / unfocused
    dt = math.min(dt, 1/30)
    
    ship1:update(dt, world:getRects())
    ship2:update(dt, world:getRects())

    -- Update active projectiles
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b:update(dt, world:getRects())
        if not b.isAlive then
            table.remove(bullets, i)
        end
    end

    -- Update procedural audio state (if either ship is thrusting)
    Audio.update(dt, ship1.thrusting or ship2.thrusting)
end

function love.draw()
    -- Render everything to the game canvas (using our fixed internal coordinate space)
    love.graphics.setCanvas(gameCanvas)
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

    -- ── Ships ────────────────────────────────────────────────
    ship1:draw()
    ship2:draw()

    -- ── HUD ──────────────────────────────────────────────────
    drawHUD()

    -- Reset target back to physical screen
    love.graphics.setCanvas()

    -- Calculate aspect-ratio scaling to fit the actual window/screen size
    local windowW, windowH = love.graphics.getDimensions()
    local scale = math.min(windowW / 1024, windowH / 768)
    local dx = (windowW - 1024 * scale) / 2
    local dy = (windowH - 768 * scale) / 2

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBackgroundColor(0, 0, 0)
    love.graphics.clear(0, 0, 0)
    
    -- Draw scaled canvas
    love.graphics.draw(gameCanvas, dx, dy, 0, scale, scale)
end

function drawHUD()
    love.graphics.setLineWidth(1)

    -- ── Player 1 (Blue) Readout (Left side) ──────────────────
    love.graphics.setColor(0.5, 0.7, 1.0, 0.9) -- Blue HUD color
    local speed1 = math.sqrt(ship1.vx * ship1.vx + ship1.vy * ship1.vy)
    love.graphics.printf(
        string.format("PLAYER 1 (BLUE)\nSPD  %5.1f\nANG  %5.1f°",
            speed1,
            math.deg(ship1.angle) % 360
        ),
        20, 20, 250, "left"
    )
    local status1 = ship1.landed and "LANDED" or "AIRBORNE"
    local sc1 = ship1.landed and {0.4, 1.0, 0.4} or {1.0, 0.7, 0.3}
    love.graphics.setColor(sc1[1], sc1[2], sc1[3], 0.9)
    love.graphics.printf(status1, 20, 75, 200, "left")

    -- ── Player 2 (Red) Readout (Right side) ──────────────────
    love.graphics.setColor(1.0, 0.5, 0.5, 0.9) -- Red HUD color
    local speed2 = math.sqrt(ship2.vx * ship2.vx + ship2.vy * ship2.vy)
    love.graphics.printf(
        string.format("PLAYER 2 (RED)\nSPD  %5.1f\nANG  %5.1f°",
            speed2,
            math.deg(ship2.angle) % 360
        ),
        1024 - 270, 20, 250, "right"
    )
    local status2 = ship2.landed and "LANDED" or "AIRBORNE"
    local sc2 = ship2.landed and {0.4, 1.0, 0.4} or {1.0, 0.7, 0.3}
    love.graphics.setColor(sc2[1], sc2[2], sc2[3], 0.9)
    love.graphics.printf(status2, 1024 - 220, 75, 200, "right")

    -- Controls reminder
    love.graphics.setColor(0.5, 0.6, 0.5, 0.6)
    love.graphics.printf(
        "P1: WASD + Space (Fire)      |      P2: Arrows + Backspace (Fire)      |      R: Reset",
        0, 748, 1024, "center"
    )
    love.graphics.setColor(1, 1, 1)
end

function love.keypressed(key)
    if key == "r" then
        -- Soft reset: put both ships back on their platforms
        local shipH = 22
        ship1 = Ship.new(PLATFORM_1_X, PLATFORM_1_Y - shipH / 2 + 2, CONFIG_P1)
        ship2 = Ship.new(PLATFORM_2_X, PLATFORM_2_Y - shipH / 2 + 2, CONFIG_P2)
        bullets = {}
    end
    if key == "space" then
        -- P1 (Blue) fires bullet
        local hh = ship1.h / 2
        local spawnX = ship1.x + math.sin(ship1.angle) * hh
        local spawnY = ship1.y - math.cos(ship1.angle) * hh
        
        local b = Bullet.new(spawnX, spawnY, ship1.angle, ship1.vx, ship1.vy, {0.5, 0.8, 1.0, 0.9})
        table.insert(bullets, b)
        Audio.playShoot()
    end
    if key == "backspace" then
        -- P2 (Red) fires bullet
        local hh = ship2.h / 2
        local spawnX = ship2.x + math.sin(ship2.angle) * hh
        local spawnY = ship2.y - math.cos(ship2.angle) * hh
        
        local b = Bullet.new(spawnX, spawnY, ship2.angle, ship2.vx, ship2.vy, {1.0, 0.5, 0.5, 0.9})
        table.insert(bullets, b)
        Audio.playShoot()
    end
    if key == "escape" then
        love.event.quit()
    end
end
