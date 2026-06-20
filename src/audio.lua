local Audio = {}

local thrustSource = nil
local shootSource = nil
local hitSource = nil
local clickSource = nil
local explosionSource = nil
local respawnSource = nil

local currentVolume = 0
local TARGET_VOLUME = 0.25  -- Max thrust volume
local FADE_IN_SPEED = 8.0   -- Volume change per second
local FADE_OUT_SPEED = 4.0  -- Slower fade out for escaping gas realism

function Audio.init()
    -- Only initialize if we have love.sound available (prevents issues in headless testing if audio is disabled)
    if not love.sound or not love.audio then
        return
    end

    local rate = 44100

    -- ────────────────────────────────────────────────────────────────
    -- 1. Thrust Sound (Filtered White Noise)
    -- ────────────────────────────────────────────────────────────────
    do
        local seconds = 0.35 -- Short looping buffer
        local samples = math.floor(rate * seconds)
        local soundData = love.sound.newSoundData(samples, rate, 16, 1)

        local lp_prev = 0
        local hp_prev = 0

        for i = 0, samples - 1 do
            local noise = math.random() * 2 - 1
            -- Low-pass Filter
            local lp = lp_prev * 0.45 + noise * 0.55
            lp_prev = lp
            -- High-pass Filter
            local hp = lp - hp_prev
            hp_prev = lp
            -- Normalize
            soundData:setSample(i, hp * 0.8)
        end

        thrustSource = love.audio.newSource(soundData)
        thrustSource:setLooping(true)
        thrustSource:setVolume(0)
        thrustSource:play()
    end

    -- ────────────────────────────────────────────────────────────────
    -- 2. Shoot Sound (Synth Laser frequency sweep)
    -- ────────────────────────────────────────────────────────────────
    do
        local seconds = 0.12
        local samples = math.floor(rate * seconds)
        local soundData = love.sound.newSoundData(samples, rate, 16, 1)
        local phase = 0

        for i = 0, samples - 1 do
            local progress = i / (samples - 1)
            -- Sweep frequency down from 900Hz to 200Hz
            local freq = 900 - progress * 700
            phase = phase + (2 * math.pi * freq) / rate
            -- Sine wave with linear decay envelope
            local amp = 1.0 - progress
            soundData:setSample(i, math.sin(phase) * amp * 0.3)
        end

        shootSource = love.audio.newSource(soundData)
        shootSource:setVolume(0.5)
    end

    -- ────────────────────────────────────────────────────────────────
    -- 3. Hit/Explosion Sound (Decaying Low-Pass Noise Burst)
    -- ────────────────────────────────────────────────────────────────
    do
        local seconds = 0.18
        local samples = math.floor(rate * seconds)
        local soundData = love.sound.newSoundData(samples, rate, 16, 1)
        local lp_prev = 0

        for i = 0, samples - 1 do
            local progress = i / (samples - 1)
            local noise = math.random() * 2 - 1
            -- Low-pass sweep (gets deeper/muffled over time)
            local filterFactor = 0.15 * (1.0 - progress) + 0.02 * progress
            local lp = lp_prev * (1.0 - filterFactor) + noise * filterFactor
            lp_prev = lp
            -- Snappy exponential decay envelope
            local amp = (1.0 - progress) ^ 2.5
            soundData:setSample(i, lp * amp * 0.5)
        end

        hitSource = love.audio.newSource(soundData)
        hitSource:setVolume(0.6)
    end

    -- ────────────────────────────────────────────────────────────────
    -- 4. Engine Click/Failure Sound (Stuttering click/ignition ticks)
    -- ────────────────────────────────────────────────────────────────
    do
        local seconds = 0.08
        local samples = math.floor(rate * seconds)
        local soundData = love.sound.newSoundData(samples, rate, 16, 1)

        for i = 0, samples - 1 do
            local progress = i / (samples - 1)
            local amp = 0
            if progress < 0.25 then
                local p = progress / 0.25
                amp = (1.0 - p) * math.sin(2 * math.pi * 3000 * (i / rate))
            elseif progress >= 0.35 and progress < 0.6 then
                local p = (progress - 0.35) / 0.25
                amp = (1.0 - p) * math.sin(2 * math.pi * 2600 * ((i - 0.35 * samples) / rate))
            end
            soundData:setSample(i, amp * 0.12)
        end

        clickSource = love.audio.newSource(soundData)
        clickSource:setVolume(0.4)
    end

    -- ────────────────────────────────────────────────────────────────
    -- 5. Big Ship Explosion Sound (Muffled Low-Pass Noise Blast)
    -- ────────────────────────────────────────────────────────────────
    do
        local seconds = 0.5
        local samples = math.floor(rate * seconds)
        local soundData = love.sound.newSoundData(samples, rate, 16, 1)
        local lp_prev = 0

        for i = 0, samples - 1 do
            local progress = i / (samples - 1)
            local noise = math.random() * 2 - 1
            -- Low-pass filter sweeps down for muffled explosion thud
            local filterFactor = 0.25 * (1.0 - progress) + 0.005 * progress
            local lp = lp_prev * (1.0 - filterFactor) + noise * filterFactor
            lp_prev = lp
            -- Decay envelope
            local amp = (1.0 - progress) ^ 1.8
            soundData:setSample(i, lp * amp * 0.7)
        end

        explosionSource = love.audio.newSource(soundData)
        explosionSource:setVolume(0.8)
    end

    -- ────────────────────────────────────────────────────────────────
    -- 6. Ship Respawn Sound (Digital Sweep-Up Arpeggio)
    -- ────────────────────────────────────────────────────────────────
    do
        local seconds = 0.3
        local samples = math.floor(rate * seconds)
        local soundData = love.sound.newSoundData(samples, rate, 16, 1)
        local phase = 0

        for i = 0, samples - 1 do
            local progress = i / (samples - 1)
            -- Sweep pitch up from 250Hz to 950Hz
            local freq = 250 + progress * 700
            phase = phase + (2 * math.pi * freq) / rate
            
            -- Blend sine wave with clean square wave harmonic for teleport effect
            local sine = math.sin(phase)
            local square = (sine > 0 and 0.15 or -0.15)
            
            -- Fade in and out envelope
            local amp = math.sin(progress * math.pi)
            soundData:setSample(i, (sine * 0.7 + square * 0.3) * amp * 0.35)
        end

        respawnSource = love.audio.newSource(soundData)
        respawnSource:setVolume(0.6)
    end
end

function Audio.update(dt, isThrusting)
    if not thrustSource then return end

    if isThrusting then
        currentVolume = math.min(currentVolume + FADE_IN_SPEED * dt, TARGET_VOLUME)
    else
        currentVolume = math.max(currentVolume - FADE_OUT_SPEED * dt, 0)
    end

    thrustSource:setVolume(currentVolume)
    
    if currentVolume > 0 then
        local pitchModulation = 0.95 + (currentVolume / TARGET_VOLUME) * 0.1 + (math.random() - 0.5) * 0.03
        thrustSource:setPitch(pitchModulation)
    end
end

function Audio.playShoot()
    if shootSource then
        local instance = shootSource:clone()
        instance:play()
    end
end

function Audio.playHit()
    if hitSource then
        local instance = hitSource:clone()
        instance:play()
    end
end

function Audio.playClick()
    if clickSource then
        local instance = clickSource:clone()
        instance:play()
    end
end

function Audio.playExplosion()
    if explosionSource then
        local instance = explosionSource:clone()
        instance:play()
    end
end

function Audio.playRespawn()
    if respawnSource then
        local instance = respawnSource:clone()
        instance:play()
    end
end

return Audio
