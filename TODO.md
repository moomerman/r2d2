* get sprite drawing working!
  * simple 2d quad example: https://github.com/floooh/sokol-odin/blob/main/examples/quad/main.odin
* rename package to r2d2, import as r2.
* put sokol-specific rendering into a different sub-package for clean separation and
  to potentially have other implementations in future

then

* ensure it builds on all platforms and the demo works! (main reason for doing this in the first place)

then

* get text drawing working! (similar wrapper style to hide implmenetaiton details)

then

* if all good, then update saga to use this new API (though if it is nice and clean enough I start to
  wonder if we need the saga layer...)

later

* think about an audio api
