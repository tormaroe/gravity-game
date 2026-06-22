function love.conf(t)
    t.title   = "Gravity Force"
    t.version = "11.5"
    t.window.width  = 1024
    t.window.height = 768
    t.window.resizable = false
    t.window.vsync  = 1
end

-- Player 1 (Blue) Controls Configuration
-- Standard key names are used (e.g., "a"-"z", "tab", "lshift", "space")
love.player1_controls = {
    left   = "a",
    right  = "d",
    thrust = "w",
    shoot  = "tab"
}

-- Player 2 (Red) Controls Configuration
-- Standard key names are used (e.g., "left", "right", "up", "backspace", "rshift", "space")
love.player2_controls = {
    left   = "left",
    right  = "right",
    thrust = "up",
    shoot  = "backspace"
}
