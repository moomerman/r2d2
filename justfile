build-examples:
    cd examples && odin build sprite -vet -strict-style
    cd examples && odin build mouse -vet -strict-style

[unix]
compile-stb:
    cd $(odin root) && make -C vendor/stb/src

[windows]
compile-stb:
    powershell -Command "$env:ODIN_ROOT = (odin root); cd $env:ODIN_ROOT\\vendor\\stb\\src; .\\build.bat"

[linux]
compile-sokol:
    cd .deps/github.com/floooh/sokol-odin/sokol && ./build_clibs_linux.sh

[macos]
compile-sokol:
    cd .deps/github.com/floooh/sokol-odin/sokol && ./build_clibs_macos.sh

[windows]
compile-sokol:
    cd .deps/github.com/floooh/sokol-odin/sokol && build_clibs_windows.cmd
