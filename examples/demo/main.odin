package mouse_example
// run this from the examples folder with `odin run demo`

import r2 "../.."
import "core:log"

odin_logo: r2.Texture

WIDTH :: 800
HEIGHT :: 600

main :: proc() {
	context.logger = log.create_console_logger()
	r2.init({title = "R2D2 Demo", width = WIDTH, height = HEIGHT})
	r2.run(init_proc = init, update_proc = update, render_proc = render, cleanup_proc = cleanup)
}

init :: proc() {
	odin_logo = r2.load_texture("assets/odin-logo.jpg")
}

update :: proc() {
	mouse_pos := r2.get_mouse_position()
	if r2.is_mouse_just_pressed(.LEFT) {
		log.infof("Mouse clicked at: (%.2f, %.2f)", mouse_pos.x, mouse_pos.y)
	}
}

render :: proc() {
	clear()
	draw_texture()
}

clear :: proc() {
	mouse_pos := r2.get_mouse_position()
	red := u8((mouse_pos.x / WIDTH) * 255)
	green := u8((mouse_pos.y / HEIGHT) * 255)
	r2.clear({red, green, 100, 255})
}

draw_texture :: proc() {
	r2.draw_texture(odin_logo, {0, 0, 400, 400}, {100, 100, 200, 200})
	r2.draw_texture(odin_logo, {200, 200, 200, 200}, {310, 100, 100, 100})
	r2.draw_texture(odin_logo, {300, 300, 100, 100}, {420, 100, 100, 100})
}

cleanup :: proc() {}
