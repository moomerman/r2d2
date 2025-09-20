build-demo:
    cd examples && odin build demo -vet -strict-style

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
