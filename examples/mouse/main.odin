package mouse_example
// run this from the examples folder with `odin run mouse.odin -file`

import r2 "../.."
import "core:log"

odin_logo: r2.Texture

main :: proc() {
	context.logger = log.create_console_logger()

	r2.init({title = "Mouse Example", width = 800, height = 600})

	log.info("Starting mouse example...")

	r2.run(
		init_proc = proc() {
			odin_logo = r2.load_texture("assets/odin-logo.jpg")
			if odin_logo == 0 {
				log.error("Failed to load texture: assets/odin-logo.jpg")
			}
		},
		update_proc = proc() {
			mouse_pos := r2.get_mouse_position()
			if r2.is_mouse_just_pressed(.LEFT) {
				log.infof("Mouse clicked at: (%.2f, %.2f)", mouse_pos.x, mouse_pos.y)
			}
		},
		render_proc = proc() {
			mouse_pos := r2.get_mouse_position()
			red := u8((mouse_pos.x / 800) * 255)
			green := u8((mouse_pos.y / 600) * 255)
			r2.clear({red, green, 100, 255})

			if odin_logo != 0 {
				logo_size := f32(150)
				center_x := f32(800) / 2 - logo_size / 2
				center_y := f32(600) / 2 - logo_size / 2

				r2.draw_texture(
					odin_logo,
					{0, 0, 400, 400}, // Use full texture (pixel coords)
					{center_x, center_y, logo_size, logo_size},
				)
			}

			current_mouse := r2.get_mouse_position()
			world_pos := r2.screen_to_world(current_mouse, {0, 0}, 1.0)
			screen_pos := r2.world_to_screen(world_pos, {0, 0}, 1.0)

			if abs(screen_pos.x - current_mouse.x) > 0.01 ||
			   abs(screen_pos.y - current_mouse.y) > 0.01 {
				log.warnf(
					"Coordinate conversion test failed: mouse=(%.2f,%.2f) world=(%.2f,%.2f) screen=(%.2f,%.2f)",
					current_mouse.x,
					current_mouse.y,
					world_pos.x,
					world_pos.y,
					screen_pos.x,
					screen_pos.y,
				)
			}
		},
	)

	log.info("Mouse example completed")
}
