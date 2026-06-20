default: run

# Run the game in windowed mode
run:
    "C:\Program Files\LOVE\love.exe" src

# Run the game in fullscreen mode
fullscreen:
    "C:\Program Files\LOVE\love.exe" src --fullscreen

# Run the unit tests
test:
    "C:\Program Files\LOVE\lovec.exe" src --test
