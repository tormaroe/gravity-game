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

# Build standalone Windows executable in build/
build:
    mkdir -p build
    rm -f build/gravity.zip build/gravity.exe
    powershell -Command "Compress-Archive -Path src/* -DestinationPath build/gravity.zip -Force"
    cat "C:\Program Files\LOVE\love.exe" build/gravity.zip > build/gravity.exe
    rm -f build/gravity.zip
    cp "C:\Program Files\LOVE"/*.dll build/
    if [ -f "C:\Program Files\LOVE\license.txt" ]; then cp "C:\Program Files\LOVE\license.txt" build/; fi

# Package the game into Windows (gravity-win64.zip) and Web (gravity-web.zip) releases
package: build
    rm -f gravity-win64.zip gravity-web.zip
    powershell -Command "Compress-Archive -Path build/* -DestinationPath gravity-win64.zip -Force"
    powershell -Command "Compress-Archive -Path src/* -DestinationPath build/gravity.zip -Force; Move-Item -Path build/gravity.zip -Destination build/gravity.love -Force"
    npx -p love.js love.js.cmd -c -m 24000000 -t "Gravity Game" build/gravity.love build/web
    powershell -Command "Compress-Archive -Path build/web/* -DestinationPath gravity-web.zip -Force"
