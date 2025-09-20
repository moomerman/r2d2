COMPLETED:
* ✅ get text drawing working! (similar wrapper style to hide implementation details)
  - Font loading with STB TrueType
  - Bitmap font atlas generation
  - Text rendering using sprite batch system
  - Text size calculation
  - Color tinting support
  - Unicode support via UTF-8

NEXT:
* if all good, then update saga to use this new API (though if it is nice and clean enough I start to
  wonder if we need the saga layer...)

FUTURE:
* keyboard input handling (expand input system beyond mouse)
* shape drawing primitives (rectangles, circles, lines)
* camera system integration
* animation/tweening system
* tilemap rendering
* particle systems
* audio api
