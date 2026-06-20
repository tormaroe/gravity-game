local Ship = require("ship")
local Bullet = require("bullet")

local Tests = {}

function Tests.run()
    print("========================================")
    print("RUNNING COLLISION UNIT TESTS...")
    print("========================================")

    local passed = 0
    local failed = 0

    local function assert_eq(actual, expected, msg)
        if actual == expected then
            passed = passed + 1
        else
            failed = failed + 1
            print("[-] FAIL: " .. msg)
            print("    Expected: " .. tostring(expected) .. ", Got: " .. tostring(actual))
        end
    end

    -- Create mock terrain: a platform at x=180, y=628, w=160, h=18
    -- Top of platform = 628
    -- Bottom of platform = 646
    local terrain = {
        { x = 180, y = 628, w = 160, h = 18 }
    }

    -- ────────────────────────────────────────────────────────────────
    -- Test 1: Landing on top of the platform (downward approach)
    -- ────────────────────────────────────────────────────────────────
    do
        -- Ship width=14, height=22 (hw=7, hh=11)
        -- Ship y at 619 means bottom is at 619 + 11 = 630.
        -- Platform top is at 628. Overlap = 2px.
        local ship = Ship.new(260, 619)
        ship.vy = 50 -- moving down
        ship.vx = 10
        
        ship:collide(terrain)

        assert_eq(ship.y, 628 - 11, "Ship should be pushed up to y=617")
        assert_eq(ship.landed, true, "Ship should be marked as landed")
        assert_eq(ship.vy, 0, "Vertical velocity should be set to 0 on landing")
        assert_eq(ship.vx, 7, "Horizontal velocity should be reduced by friction (10 * 0.7 = 7)")
    end

    -- ────────────────────────────────────────────────────────────────
    -- Test 2: Hitting the bottom of the platform (upward approach)
    -- ────────────────────────────────────────────────────────────────
    do
        -- Platform bottom is at 646.
        -- Ship y at 655 means top is at 655 - 11 = 644.
        -- Overlap = 2px.
        local ship = Ship.new(260, 655)
        ship.vy = -50 -- moving up
        
        ship:collide(terrain)

        assert_eq(ship.y, 646 + 11, "Ship should be pushed down to y=657")
        assert_eq(ship.landed, false, "Ship should not be marked as landed")
        assert_eq(ship.vy, 0, "Vertical velocity should be set to 0 when hitting ceiling")
    end

    -- ────────────────────────────────────────────────────────────────
    -- Test 3: Wall collision (left side of platform)
    -- ────────────────────────────────────────────────────────────────
    do
        -- Platform left wall is at x=180.
        -- Ship x at 175 means right edge is 175 + 7 = 182.
        -- Overlap = 2px.
        -- Ship is vertically overlapping (y=635, hh=11 -> y range [624, 646], platform is [628, 646])
        local ship = Ship.new(175, 635)
        ship.vx = 30
        
        ship:collide(terrain)

        assert_eq(ship.x, 180 - 7, "Ship should be pushed left to x=173")
        assert_eq(ship.vx, 0, "Horizontal velocity should be set to 0 on wall hit")
    end

    -- ────────────────────────────────────────────────────────────────
    -- Test 4: Bullet speed and direction initialization
    -- ────────────────────────────────────────────────────────────────
    do
        -- Fire bullet facing straight up (angle = 0)
        -- Ship moving with vx=20, vy=10
        -- Muzzle velocity is 550 straight up (vx_rel = 0, vy_rel = -550)
        local bullet = Bullet.new(100, 200, 0, 20, 10)
        assert_eq(bullet.vx, 20, "Bullet vx should match ship vx when angle=0")
        assert_eq(bullet.vy, 10 - 550, "Bullet vy should incorporate ship vy and muzzle speed")
        assert_eq(bullet.isAlive, true, "New bullet should be alive")
    end

    -- ────────────────────────────────────────────────────────────────
    -- Test 5: Bullet terrain collision
    -- ────────────────────────────────────────────────────────────────
    do
        -- Place bullet just above the platform, moving down
        -- Top of platform is y=628
        -- Set angle to math.pi (pointing down) so vx=0, vy=550
        local bullet = Bullet.new(200, 626, math.pi, 0, 0)
        bullet:update(0.01, terrain) -- moves it down (y ≈ 631.5), inside platform
        assert_eq(bullet.isAlive, false, "Bullet should be dead after hitting terrain")
    end

    -- ────────────────────────────────────────────────────────────────
    -- Test 6: Ship-to-ship collision resolution and bounce
    -- ────────────────────────────────────────────────────────────────
    do
        -- Create two ships overlapping horizontally (hw=7, hh=11)
        -- Ship 1: x = 100, y = 100, vx = 50 (moving right)
        -- Ship 2: x = 110, y = 100, vx = -30 (moving left)
        -- Overlap on X = (100 + 7) - (110 - 7) = 107 - 103 = 4px
        local ship1 = Ship.new(100, 100)
        ship1.vx = 50
        local ship2 = Ship.new(110, 100)
        ship2.vx = -30
        
        Ship.resolveCollision(ship1, ship2)
        
        -- Verification:
        -- 1. Separated by 2px each (overlap/2)
        assert_eq(ship1.x, 100 - 2, "Ship 1 should be pushed left to x=98")
        assert_eq(ship2.x, 110 + 2, "Ship 2 should be pushed right to x=112")
        
        -- 2. Velocities swapped and multiplied by bounce coeff (0.8)
        assert_eq(ship1.vx, -30 * 0.8, "Ship 1 vx should bounce to -24")
        assert_eq(ship2.vx, 50 * 0.8, "Ship 2 vx should bounce to 40")
    end

    print("========================================")
    print(string.format("TEST RESULTS: %d passed, %d failed", passed, failed))
    print("========================================")

    return failed == 0
end

return Tests
