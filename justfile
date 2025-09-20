run-demo:
    cd examples && odin run demo -vet -strict-style

build-demo:
    cd examples && odin build demo -vet -strict-style

run-camera:
    cd examples && odin run camera -vet -strict-style

shdc:
    .deps/github.com/floooh/sokol-tools-bin/bin/osx_arm64/sokol-shdc --input src/sokol/sprite.glsl --output src/sokol/sprite.odin --slang glsl410:hlsl4:metal_macos -f sokol_odin

[unix]
compile-stb:
    cd $(odin root) && make -C vendor/stb/src

[windows]
compile-stb:
    cd $(odin root) && build.bat

[linux]
compile-sokol:
    cd .deps/github.com/floooh/sokol-odin/sokol && ./build_clibs_linux.sh

[macos]
compile-sokol:
    cd .deps/github.com/floooh/sokol-odin/sokol && ./build_clibs_macos.sh

[windows]
compile-sokol:
    cd .deps/github.com/floooh/sokol-odin/sokol && build_clibs_windows.cmd
