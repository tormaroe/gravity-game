-- main.lua
-- Entry point for the Gravity Force clone.

local Ship  = require("ship")
local World = require("world")
local Audio = require("audio")
local Bullet = require("bullet")
local Powerup = require("powerup")

-- ── State ──────────────────────────────────────────────────────────────────
local world
local ship1  -- Player 1 (Blue)
local ship2  -- Player 2 (Red)
local starfield   -- background stars for ambiance
local bullets = {} -- active projectiles
local particles = {} -- explosion particles
local gameCanvas  -- Canvas for scaling resolution
local powerups = {} -- active floating powerup items
local powerupSpawnTimer = 0.0

-- Game state variables
local gameState = "STARTUP" -- "STARTUP", "PLAYING", "GAMEOVER"
local winnerName = nil
local fontTitle
local fontMedium
local fontSmall
local defaultFont
local menuShip1
local menuShip2

-- Platform spawn positions (symmetric)
local PLATFORM_1_X  = 180 + 80         -- Left platform center
local PLATFORM_1_Y  = 768 - 140
local PLATFORM_2_X  = 1024 - 180 - 80  -- Right platform center (symmetric)
local PLATFORM_2_Y  = 768 - 140

-- Player 1 (Blue) configuration default and custom values
local default_p1_controls = { left = "a", right = "d", thrust = "w", shoot = "tab" }
local default_p2_controls = { left = "left", right = "right", thrust = "up", shoot = "backspace" }

local function loadControls(custom, defaults)
    local tbl = {}
    custom = custom or {}
    for k, v in pairs(defaults) do
        tbl[k] = custom[k] or v
    end
    return tbl
end

local CONFIG_P1 = {
    controls = loadControls(love.player1_controls, default_p1_controls),
    color = {
        hull    = {0.15, 0.45, 0.9},
        outline = {0.5, 0.8, 1.0},
        cockpit = {0.0, 0.2, 0.6}
    }
}

-- Player 2 (Red) configuration
local CONFIG_P2 = {
    controls = loadControls(love.player2_controls, default_p2_controls),
    color = {
        hull    = {0.9, 0.2, 0.15},
        outline = {1.0, 0.5, 0.5},
        cockpit = {0.6, 0.0, 0.0}
    }
}

-- Helper to format controls for UI display
local function getControlsText(controls)
    local left = controls.left or "a"
    local right = controls.right or "d"
    local thrust = controls.thrust or "w"
    local shoot = controls.shoot or "tab"

    local moveStr
    if thrust == "w" and left == "a" and right == "d" then
        moveStr = "WASD"
    elseif thrust == "up" and left == "left" and right == "right" then
        moveStr = "Arrows"
    else
        moveStr = string.format("%s/%s/%s", string.upper(thrust), string.upper(left), string.upper(right))
    end

    local shootStr = string.upper(shoot)
    return moveStr, shootStr
end

-- Helper to trigger dynamic particle explosion
local function spawnExplosion(x, y, color)
    for i = 1, 35 do
        local angle = math.random() * math.pi * 2
        local speed = math.random() * 110 + 40
        local life = math.random() * 0.7 + 0.3
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            maxLife = life,
            color = {color[1], color[2], color[3]},
            size = math.random() * 2.5 + 1.5
        })
    end
end

-- Helper to trigger shield hit particles
local function spawnShieldParticles(x, y)
    for i = 1, 15 do
        local angle = math.random() * math.pi * 2
        local speed = math.random() * 80 + 30
        local life = math.random() * 0.4 + 0.2
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            maxLife = life,
            color = {0.3, 0.9, 1.0}, -- Shield cyan
            size = math.random() * 1.5 + 1.0
        })
    end
end

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

local function spawnPowerupAtRandomLocation()
    local rx, ry
    local rects = world:getRects()
    local success = false
    
    for attempt = 1, 15 do
        rx = math.random(80, 944)
        ry = math.random(80, 688)
        
        -- Check collision with terrain
        local collides = false
        local r_check = 25
        for _, rect in ipairs(rects) do
            if rx + r_check > rect.x and rx - r_check < rect.x + rect.w and
               ry + r_check > rect.y and ry - r_check < rect.y + rect.h then
                collides = true
                break
            end
        end
        
        if not collides then
            success = true
            break
        end
    end
    
    if not success then
        rx = 512
        ry = 280
    end
    
    local pType = (math.random() < 0.5) and "BULLET_SPRAY" or "SHIELD"
    table.insert(powerups, Powerup.new(rx, ry, pType))
    Audio.playPop()
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

    -- Save default LÖVE font and load custom fonts with fallbacks
    defaultFont = love.graphics.getFont() or love.graphics.newFont(12)
    local ok, ft = pcall(love.graphics.newFont, "font.ttf", 36)
    if ok then
        fontTitle  = ft
        fontMedium = love.graphics.newFont("font.ttf", 18)
        fontSmall  = love.graphics.newFont("font.ttf", 12)
    else
        fontTitle  = love.graphics.newFont(36)
        fontMedium = love.graphics.newFont(18)
        fontSmall  = love.graphics.newFont(12)
    end

    world     = World.new()
    starfield = makeStars(120)

    -- Place both ships on their respective platforms
    local shipH = 22
    ship1 = Ship.new(PLATFORM_1_X, PLATFORM_1_Y - shipH / 2 + 2, CONFIG_P1)
    ship2 = Ship.new(PLATFORM_2_X, PLATFORM_2_Y - shipH / 2 + 2, CONFIG_P2)

    -- Initialize menu ships for the startup splash screen
    menuShip1 = Ship.new(330, 400, CONFIG_P1)
    menuShip2 = Ship.new(694, 400, CONFIG_P2)

    -- Create Canvas for scaling resolution
    gameCanvas = love.graphics.newCanvas(1024, 768)

    -- Initialize powerups state
    powerupSpawnTimer = math.random(10, 30)
    powerups = {}

    -- Initialize procedural audio engine
    Audio.init()
    Audio.playMusic()
end

function love.update(dt)
    -- Cap dt to avoid huge jumps when window is moved / unfocused
    dt = math.min(dt, 1/30)
    
    -- 1. Update background stars (slow parallax drift leftward) - always active
    local starBaseSpeed = 4.5
    for _, s in ipairs(starfield) do
        -- Larger/brighter stars move faster than smaller/dimmer ones for a subtle parallax 3D effect
        s.x = s.x - (s.r * starBaseSpeed) * dt
        if s.x < 0 then
            s.x = s.x + 1024
            s.y = math.random(0, 768)
        end
    end

    -- 2. Update explosion particles - always active so that final kill explosion finishes animating
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 30 * dt -- gravity drift for sparks
        end
    end

    if gameState == "STARTUP" then
        -- Spin the preview menu ships and make their thrust flames flicker
        if menuShip1 and menuShip2 then
            menuShip1.angle = menuShip1.angle + dt * 1.5
            menuShip2.angle = menuShip2.angle - dt * 1.5
            menuShip1.thrusting = (math.floor(love.timer.getTime() * 4) % 2 == 0)
            menuShip2.thrusting = (math.floor(love.timer.getTime() * 4 + 1) % 2 == 0)
        end
    elseif gameState == "PLAYING" then
        -- 3. Integrate physics movement
        ship1:update(dt)
        ship2:update(dt)

        -- 4. Resolve ship-to-ship collisions (only if both are alive)
        if ship1.isAlive and ship2.isAlive then
            Ship.resolveCollision(ship1, ship2)
        end

        -- 5. Resolve terrain collisions (only if alive)
        if ship1.isAlive then ship1:collide(world:getRects()) end
        if ship2.isAlive then ship2:collide(world:getRects()) end

        -- 6. Update projectiles and check combat collisions
        for i = #bullets, 1, -1 do
            local b = bullets[i]
            b:update(dt, world:getRects())
            
            if b.isAlive then
                -- Bullet vs Player 1
                if ship1.isAlive and b.owner == 2 then
                    local hw = ship1.w / 2
                    local hh = ship1.h / 2
                    if b.x >= ship1.x - hw and b.x <= ship1.x + hw and b.y >= ship1.y - hh and b.y <= ship1.y + hh then
                        b.isAlive = false
                        if ship1.hasShield then
                            ship1.hasShield = false
                            Audio.playShieldBreak()
                            spawnShieldParticles(ship1.x, ship1.y)
                        else
                            ship1.isAlive = false
                            ship1.respawnTimer = 3.0
                            ship1.bulletSprayTimer = 0.0 -- Lose powerup on death
                            ship2.kills = ship2.kills + 1
                            ship2.shootBlockTimer = 6.0 -- 3s dead + 3s spawn protection safety
                            Audio.playExplosion()
                            spawnExplosion(ship1.x, ship1.y, CONFIG_P1.color.hull)

                            -- Check win condition
                            if ship2.kills >= 5 then
                                gameState = "GAMEOVER"
                                winnerName = "PLAYER 2 (RED)"
                                Audio.stopMusic()
                                Audio.playFanfare()
                            end
                        end
                    end
                end
            end

            if b.isAlive then
                -- Bullet vs Player 2
                if ship2.isAlive and b.owner == 1 then
                    local hw = ship2.w / 2
                    local hh = ship2.h / 2
                    if b.x >= ship2.x - hw and b.x <= ship2.x + hw and b.y >= ship2.y - hh and b.y <= ship2.y + hh then
                        b.isAlive = false
                        if ship2.hasShield then
                            ship2.hasShield = false
                            Audio.playShieldBreak()
                            spawnShieldParticles(ship2.x, ship2.y)
                        else
                            ship2.isAlive = false
                            ship2.respawnTimer = 3.0
                            ship2.bulletSprayTimer = 0.0 -- Lose powerup on death
                            ship1.kills = ship1.kills + 1
                            ship1.shootBlockTimer = 6.0 -- 3s dead + 3s spawn protection safety
                            Audio.playExplosion()
                            spawnExplosion(ship2.x, ship2.y, CONFIG_P2.color.hull)

                            -- Check win condition
                            if ship1.kills >= 5 then
                                gameState = "GAMEOVER"
                                winnerName = "PLAYER 1 (BLUE)"
                                Audio.stopMusic()
                                Audio.playFanfare()
                            end
                        end
                    end
                end
            end

            if not b.isAlive then
                table.remove(bullets, i)
            end
        end

        -- 7. Handle respawning
        local shipH = 22
        if not ship1.isAlive and ship1.respawnTimer <= 0 then
            ship1.isAlive = true
            ship1.fuel = 1.0
            ship1.vx = 0
            ship1.vy = 0
            ship1.angle = 0
            ship1.x = PLATFORM_1_X
            ship1.y = PLATFORM_1_Y - shipH / 2 + 2
            ship1.landed = true
            Audio.playRespawn()
        end

        if not ship2.isAlive and ship2.respawnTimer <= 0 then
            ship2.isAlive = true
            ship2.fuel = 1.0
            ship2.vx = 0
            ship2.vy = 0
            ship2.angle = 0
            ship2.x = PLATFORM_2_X
            ship2.y = PLATFORM_2_Y - shipH / 2 + 2
            ship2.landed = true
            Audio.playRespawn()
        end

        -- 8. Powerup Spawning & Logic
        powerupSpawnTimer = powerupSpawnTimer - dt
        if powerupSpawnTimer <= 0 then
            spawnPowerupAtRandomLocation()
            powerupSpawnTimer = math.random(10, 30)
        end

        for i = #powerups, 1, -1 do
            local p = powerups[i]
            p:update(dt, world:getRects())
            
            local removed = false
            if p.life <= 0 then
                table.remove(powerups, i)
                removed = true
            end
            
            if not removed and ship1.isAlive then
                local dx = ship1.x - p.x
                local dy = ship1.y - p.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < (ship1.w / 2 + p.r) then
                    if p.type == "SHIELD" then
                        ship1.hasShield = true
                    else
                        ship1.bulletSprayTimer = 15.0
                    end
                    Audio.playPowerup()
                    table.remove(powerups, i)
                    removed = true
                end
            end
            
            if not removed and ship2.isAlive then
                local dx = ship2.x - p.x
                local dy = ship2.y - p.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < (ship2.w / 2 + p.r) then
                    if p.type == "SHIELD" then
                        ship2.hasShield = true
                    else
                        ship2.bulletSprayTimer = 15.0
                    end
                    Audio.playPowerup()
                    table.remove(powerups, i)
                    removed = true
                end
            end
        end
    end

    -- 8. Update procedural audio state (if either ship is active and thrusting, and we're in PLAYING state)
    local thrusting1 = (gameState == "PLAYING") and ship1.isAlive and ship1.thrusting
    local thrusting2 = (gameState == "PLAYING") and ship2.isAlive and ship2.thrusting
    Audio.update(dt, thrusting1 or thrusting2)
end

-- ── Splash Screens Drawing Helpers ─────────────────────────────────────────
local function drawStartupScreen()
    -- Neon frame border
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.15, 0.45, 0.9, 0.8) -- Blue frame
    love.graphics.rectangle("line", 40, 40, 944, 688)
    love.graphics.setColor(0.9, 0.2, 0.15, 0.4) -- Red inner frame
    love.graphics.rectangle("line", 45, 45, 934, 678)

    -- Title text: "2 player gravity battle"
    love.graphics.setFont(fontTitle)
    local titleText = "2 PLAYER GRAVITY BATTLE"
    
    -- Draw glow/drop-shadow for title
    love.graphics.setColor(0.3, 0.1, 0.5, 0.8)
    love.graphics.printf(titleText, 0, 202, 1024, "center")
    love.graphics.printf(titleText, 2, 200, 1024, "center")
    love.graphics.printf(titleText, -2, 200, 1024, "center")
    love.graphics.printf(titleText, 0, 198, 1024, "center")
    
    love.graphics.setColor(1.0, 0.8, 0.2) -- Gold/Yellow
    love.graphics.printf(titleText, 0, 200, 1024, "center")

    -- Subtitle text: "first to 5 kills"
    love.graphics.setFont(fontMedium)
    local subtitleText = "FIRST TO 5 KILLS"
    love.graphics.setColor(0.3, 0.9, 0.3) -- Green
    love.graphics.printf(subtitleText, 0, 270, 1024, "center")

    -- Draw the mock spinning ships
    if menuShip1 then
        menuShip1:draw()
        -- Label P1
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(0.5, 0.7, 1.0)
        love.graphics.printf("PLAYER 1 (BLUE)", 180, 470, 300, "center")
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(0.8, 0.8, 0.8)
        local p1Move, p1Shoot = getControlsText(CONFIG_P1.controls)
        love.graphics.printf(string.format("Controls:\n%s to Fly\n%s to Shoot", p1Move, p1Shoot), 180, 500, 300, "center")
    end

    if menuShip2 then
        menuShip2:draw()
        -- Label P2
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(1.0, 0.5, 0.5)
        love.graphics.printf("PLAYER 2 (RED)", 544, 470, 300, "center")
        love.graphics.setFont(fontSmall)
        love.graphics.setColor(0.8, 0.8, 0.8)
        local p2Move, p2Shoot = getControlsText(CONFIG_P2.controls)
        love.graphics.printf(string.format("Controls:\n%s to Fly\n%s to Shoot", p2Move, p2Shoot), 544, 500, 300, "center")
    end

    -- Blinking Prompt
    local alpha = 0.4 + 0.6 * math.sin(love.timer.getTime() * 5)
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("PRESS ENTER TO START", 0, 620, 1024, "center")
end

local function drawGameOverScreen()
    -- Neon frame border (flashing or glowing red/blue depending on winner)
    love.graphics.setLineWidth(2)
    if winnerName == "PLAYER 1 (BLUE)" then
        love.graphics.setColor(0.15, 0.45, 0.9, 0.8)
    else
        love.graphics.setColor(0.9, 0.2, 0.15, 0.8)
    end
    love.graphics.rectangle("line", 40, 40, 944, 688)

    -- Winner text: "[PLAYER] WINS!"
    love.graphics.setFont(fontTitle)
    local winText = (winnerName or "NOBODY") .. " WINS!"
    
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(winText, 2, 282, 1024, "center")
    
    if winnerName == "PLAYER 1 (BLUE)" then
        love.graphics.setColor(0.4, 0.7, 1.0)
    else
        love.graphics.setColor(1.0, 0.4, 0.4)
    end
    love.graphics.printf(winText, 0, 280, 1024, "center")

    -- Final Score info
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(0.8, 0.8, 0.8)
    local scoreText = string.format("FINAL SCORE:  BLUE [%d]  -  RED [%d]", ship1.kills, ship2.kills)
    love.graphics.printf(scoreText, 0, 360, 1024, "center")

    -- Blinking Play Again prompt
    local alpha = 0.4 + 0.6 * math.sin(love.timer.getTime() * 5)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("PRESS ENTER TO PLAY AGAIN", 0, 520, 1024, "center")
end

function love.draw()
    -- Render everything to the game canvas (using our fixed internal coordinate space)
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0.04, 0.05, 0.08)

    -- Stars (drawn in all states)
    for _, s in ipairs(starfield) do
        love.graphics.setColor(s.br, s.br, s.br, s.br)
        love.graphics.circle("fill", s.x, s.y, s.r)
    end

    if gameState == "STARTUP" then
        drawStartupScreen()
    elseif gameState == "PLAYING" then
        -- ── World geometry ───────────────────────────────────────
        world:draw()

        -- ── Projectiles ──────────────────────────────────────────
        for _, b in ipairs(bullets) do
            b:draw()
        end

        -- ── Powerups ─────────────────────────────────────────────
        for _, p in ipairs(powerups) do
            p:draw(fontSmall)
        end

        -- ── Explosion Particles ──────────────────────────────────
        for _, p in ipairs(particles) do
            local alpha = p.life / p.maxLife
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
            love.graphics.circle("fill", p.x, p.y, p.size)
        end

        -- ── Ships ────────────────────────────────────────────────
        ship1:draw()
        ship2:draw()

        -- ── HUD ──────────────────────────────────────────────────
        drawHUD()
    elseif gameState == "GAMEOVER" then
        -- Draw the final gameplay state in background
        world:draw()
        for _, b in ipairs(bullets) do
            b:draw()
        end
        for _, p in ipairs(powerups) do
            p:draw(fontSmall)
        end
        for _, p in ipairs(particles) do
            local alpha = p.life / p.maxLife
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
            love.graphics.circle("fill", p.x, p.y, p.size)
        end
        ship1:draw()
        ship2:draw()
        
        -- Dark semi-transparent overlay
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, 1024, 768)

        drawGameOverScreen()
    end

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

-- Helper to draw a stylized fuel gauge bar
local function drawFuelBar(x, y, w, h, fuel)
    -- Border outline
    love.graphics.setColor(0.4, 0.4, 0.4, 0.8)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Color based on level
    if fuel > 0.5 then
        love.graphics.setColor(0.3, 0.9, 0.3, 0.85) -- Green
    elseif fuel > 0.2 then
        love.graphics.setColor(0.9, 0.9, 0.2, 0.85) -- Yellow
    else
        -- Pulsating red for critical low fuel alert
        local alpha = 0.5 + 0.4 * math.sin(love.timer.getTime() * 15)
        love.graphics.setColor(1.0, 0.2, 0.2, alpha) -- Red
    end
    
    -- Fill the bar representing current propellant levels
    love.graphics.rectangle("fill", x + 1, y + 1, (w - 2) * fuel, h - 2)
    
    -- Text label
    love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
    love.graphics.printf(string.format("FUEL %3.0f%%", fuel * 100), x, y - 15, w, "left")
end

function drawHUD()
    if defaultFont then
        love.graphics.setFont(defaultFont)
    end
    love.graphics.setLineWidth(1)

    -- ── Player 1 (Blue) Readout (Left side) ──────────────────
    love.graphics.setColor(0.5, 0.7, 1.0, 0.9) -- Blue HUD color
    local speed1 = ship1.isAlive and math.sqrt(ship1.vx * ship1.vx + ship1.vy * ship1.vy) or 0
    local angle1 = ship1.isAlive and math.deg(ship1.angle) % 360 or 0
    love.graphics.printf(
        string.format("PLAYER 1 (BLUE)   [Kills: %d]\nSPD  %5.1f\nANG  %5.1f°",
            ship1.kills,
            speed1,
            angle1
        ),
        20, 20, 280, "left"
    )
    
    if ship1.isAlive then
        local status1 = ship1.landed and "LANDED" or "AIRBORNE"
        local sc1 = ship1.landed and {0.4, 1.0, 0.4} or {1.0, 0.7, 0.3}
        love.graphics.setColor(sc1[1], sc1[2], sc1[3], 0.9)
        love.graphics.printf(status1, 20, 75, 200, "left")

        -- Weapons status / safety locks / Shield
        local wpStr1 = "WEAPONS READY"
        local wpCol1 = {0.4, 1.0, 0.4, 0.6}
        if ship1.shootBlockTimer > 0 then
            wpStr1 = string.format("WEAPONS LOCK: %1.1fs", ship1.shootBlockTimer)
            wpCol1 = {1.0, 0.5, 0.2, 0.95}
        end
        if ship1.hasShield then
            wpStr1 = wpStr1 .. " [SHIELD]"
        end
        love.graphics.setColor(wpCol1[1], wpCol1[2], wpCol1[3], wpCol1[4])
        if ship1.hasShield then
            love.graphics.setColor(0.3, 0.9, 1.0, 0.95) -- cyan color for shield text
        end
        love.graphics.printf(wpStr1, 20, 95, 250, "left")
        if ship1.bulletSprayTimer > 0 then
            love.graphics.setColor(0.3, 0.9, 0.3, 0.95)
            love.graphics.printf(string.format("SPRAY ACTIVE: %1.1fs", ship1.bulletSprayTimer), 20, 115, 200, "left")
        end
    else
        love.graphics.setColor(1.0, 0.3, 0.3, 0.95)
        love.graphics.printf(string.format("DEAD - RESPAWN IN %1.1fs", math.max(ship1.respawnTimer, 0)), 20, 75, 250, "left")
    end

    -- Player 1 Fuel Bar
    if ship1.isAlive then
        drawFuelBar(20, 150, 120, 10, ship1.fuel)
    end

    -- ── Player 2 (Red) Readout (Right side) ──────────────────
    love.graphics.setColor(1.0, 0.5, 0.5, 0.9) -- Red HUD color
    local speed2 = ship2.isAlive and math.sqrt(ship2.vx * ship2.vx + ship2.vy * ship2.vy) or 0
    local angle2 = ship2.isAlive and math.deg(ship2.angle) % 360 or 0
    love.graphics.printf(
        string.format("[Kills: %d]   PLAYER 2 (RED)\nSPD  %5.1f\nANG  %5.1f°",
            ship2.kills,
            speed2,
            angle2
        ),
        1024 - 300, 20, 280, "right"
    )
    
    if ship2.isAlive then
        local status2 = ship2.landed and "LANDED" or "AIRBORNE"
        local sc2 = ship2.landed and {0.4, 1.0, 0.4} or {1.0, 0.7, 0.3}
        love.graphics.setColor(sc2[1], sc2[2], sc2[3], 0.9)
        love.graphics.printf(status2, 1024 - 220, 75, 200, "right")

        -- Weapons status / safety locks / Shield
        local wpStr2 = "WEAPONS READY"
        local wpCol2 = {0.4, 1.0, 0.4, 0.6}
        if ship2.shootBlockTimer > 0 then
            wpStr2 = string.format("WEAPONS LOCK: %1.1fs", ship2.shootBlockTimer)
            wpCol2 = {1.0, 0.5, 0.2, 0.95}
        end
        if ship2.hasShield then
            wpStr2 = "[SHIELD] " .. wpStr2
        end
        love.graphics.setColor(wpCol2[1], wpCol2[2], wpCol2[3], wpCol2[4])
        if ship2.hasShield then
            love.graphics.setColor(0.3, 0.9, 1.0, 0.95) -- cyan color for shield text
        end
        love.graphics.printf(wpStr2, 1024 - 270, 95, 250, "right")
        if ship2.bulletSprayTimer > 0 then
            love.graphics.setColor(0.3, 0.9, 0.3, 0.95)
            love.graphics.printf(string.format("SPRAY ACTIVE: %1.1fs", ship2.bulletSprayTimer), 1024 - 220, 115, 200, "right")
        end
    else
        love.graphics.setColor(1.0, 0.3, 0.3, 0.95)
        love.graphics.printf(string.format("DEAD - RESPAWN IN %1.1fs", math.max(ship2.respawnTimer, 0)), 1024 - 270, 75, 250, "right")
    end

    -- Player 2 Fuel Bar (Symmetric position on the right)
    if ship2.isAlive then
        drawFuelBar(1024 - 140, 150, 120, 10, ship2.fuel)
    end

    -- Controls reminder
    love.graphics.setColor(0.5, 0.6, 0.5, 0.6)
    local p1Move, p1Shoot = getControlsText(CONFIG_P1.controls)
    local p2Move, p2Shoot = getControlsText(CONFIG_P2.controls)
    local reminder = string.format(
        "P1: %s + %s (Fire)      |      P2: %s + %s (Fire)      |      R: Reset",
        p1Move, p1Shoot, p2Move, p2Shoot
    )
    love.graphics.printf(reminder, 0, 748, 1024, "center")
    love.graphics.setColor(1, 1, 1)
end

local function resetGame()
    local shipH = 22
    ship1 = Ship.new(PLATFORM_1_X, PLATFORM_1_Y - shipH / 2 + 2, CONFIG_P1)
    ship2 = Ship.new(PLATFORM_2_X, PLATFORM_2_Y - shipH / 2 + 2, CONFIG_P2)
    bullets = {}
    particles = {}
    powerups = {}
    powerupSpawnTimer = math.random(10, 30)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    if gameState == "STARTUP" then
        if key == "return" or key == "kpenter" then
            gameState = "PLAYING"
        end
    elseif gameState == "GAMEOVER" then
        if key == "return" or key == "kpenter" then
            resetGame()
            gameState = "STARTUP"
            Audio.playMusic()
        end
    elseif gameState == "PLAYING" then
        if key == "r" then
            resetGame()
        end
        if key == ship1.key_shoot then
            -- P1 (Blue) fires bullet (only if alive and weapons are not locked)
            if ship1.isAlive and ship1.shootBlockTimer <= 0 then
                local hh = ship1.h / 2
                local spawnX = ship1.x + math.sin(ship1.angle) * hh
                local spawnY = ship1.y - math.cos(ship1.angle) * hh
                
                if ship1.bulletSprayTimer > 0 then
                    -- Fire 3 bullets in a 30-degree spread (-15, 0, +15 degrees)
                    local angles = {ship1.angle - 0.2618, ship1.angle, ship1.angle + 0.2618}
                    for _, ang in ipairs(angles) do
                        local b = Bullet.new(spawnX, spawnY, ang, ship1.vx, ship1.vy, {0.5, 0.8, 1.0, 0.9})
                        b.owner = 1
                        table.insert(bullets, b)
                    end
                else
                    -- Standard single bullet
                    local b = Bullet.new(spawnX, spawnY, ship1.angle, ship1.vx, ship1.vy, {0.5, 0.8, 1.0, 0.9})
                    b.owner = 1
                    table.insert(bullets, b)
                end
                Audio.playShoot()
            end
        end
        if key == ship2.key_shoot then
            -- P2 (Red) fires bullet (only if alive and weapons are not locked)
            if ship2.isAlive and ship2.shootBlockTimer <= 0 then
                local hh = ship2.h / 2
                local spawnX = ship2.x + math.sin(ship2.angle) * hh
                local spawnY = ship2.y - math.cos(ship2.angle) * hh
                
                if ship2.bulletSprayTimer > 0 then
                    -- Fire 3 bullets in a 30-degree spread (-15, 0, +15 degrees)
                    local angles = {ship2.angle - 0.2618, ship2.angle, ship2.angle + 0.2618}
                    for _, ang in ipairs(angles) do
                        local b = Bullet.new(spawnX, spawnY, ang, ship2.vx, ship2.vy, {1.0, 0.5, 0.5, 0.9})
                        b.owner = 2
                        table.insert(bullets, b)
                    end
                else
                    -- Standard single bullet
                    local b = Bullet.new(spawnX, spawnY, ship2.angle, ship2.vx, ship2.vy, {1.0, 0.5, 0.5, 0.9})
                    b.owner = 2
                    table.insert(bullets, b)
                end
                Audio.playShoot()
            end
        end
    end
end
