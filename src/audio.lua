-- audio.lua
-- Procedural audio generation for the gravity ship thrusters.
-- Generates filtered white noise (band-pass filtered to create a gas-hissing sound).

local Audio = {}

local thrustSource = nil
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
    local seconds = 0.35 -- Short looping buffer
    local samples = math.floor(rate * seconds)
    
    local soundData = love.sound.newSoundData(samples, rate, 16, 1)

    -- Filter variables for a custom Band-Pass Filter (BPF)
    -- High pass + low pass to emulate pressurized gas escaping.
    local lp_prev = 0
    local hp_prev = 0

    for i = 0, samples - 1 do
        local noise = math.random() * 2 - 1

        -- 1. Low-Pass Filter: smooths out digital harshness
        local lp = lp_prev * 0.45 + noise * 0.55
        lp_prev = lp

        -- 2. High-Pass Filter: removes deep rumbling sub-bass, keeping the "hiss"
        local hp = lp - hp_prev
        hp_prev = lp

        -- Normalize and write to buffer
        soundData:setSample(i, hp * 0.8)
    end

    -- Create audio source
    thrustSource = love.audio.newSource(soundData)
    thrustSource:setLooping(true)
    thrustSource:setVolume(0)
    thrustSource:play() -- Play immediately, control volume dynamically
end

function Audio.update(dt, isThrusting)
    if not thrustSource then return end

    if isThrusting then
        -- Fade in
        currentVolume = math.min(currentVolume + FADE_IN_SPEED * dt, TARGET_VOLUME)
    else
        -- Fade out
        currentVolume = math.max(currentVolume - FADE_OUT_SPEED * dt, 0)
    end

    thrustSource:setVolume(currentVolume)
    
    -- Dynamically modulate pitch slightly to simulate pressure variance
    if currentVolume > 0 then
        local pitchModulation = 0.95 + (currentVolume / TARGET_VOLUME) * 0.1 + (math.random() - 0.5) * 0.03
        thrustSource:setPitch(pitchModulation)
    end
end

return Audio
