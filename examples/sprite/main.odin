package sprite_example
// run this from the examples folder with `odin run sprite.odin -file`

import r2 "../.."
import "core:log"

odin_logo: r2.Texture

main :: proc() {
	context.logger = log.create_console_logger()
	r2.init({title = "Sprite Example", width = 800, height = 600})
	r2.run(init_proc = init, update_proc = update, render_proc = render, cleanup_proc = cleanup)
}

init :: proc() {
	odin_logo = r2.load_texture("assets/odin-logo.jpg")
}

update :: proc() {}

render :: proc() {
	r2.clear({50, 50, 100, 255})

	r2.draw_texture(odin_logo, {0, 0, 400, 400}, {100, 100, 200, 200})
	r2.draw_texture(odin_logo, {200, 200, 200, 200}, {310, 100, 100, 100})
	r2.draw_texture(odin_logo, {300, 300, 100, 100}, {420, 100, 100, 100})
}

cleanup :: proc() {
	log.info("Sprite example cleanup")
	// Could unload textures here if needed
}
