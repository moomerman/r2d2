package camera_example
// run this with `just run-camera`

import "core:fmt"
import "core:log"
import "core:math"

import r2 "../../src"

logo: r2.Texture
font: r2.Font
camera: r2.Camera

WIDTH :: 800
HEIGHT :: 600

main :: proc() {
	context.logger = log.create_console_logger()
	r2.init({title = "R2D2 Camera Demo", width = WIDTH, height = HEIGHT})
	r2.run(init, update, render, cleanup)
}

init :: proc() {
	font = r2.load_font("assets/crimes-09.ttf", 24)
	logo = r2.load_texture("assets/odin-logo.jpg")

	// Create a centered camera
	camera = r2.camera_create_centered(WIDTH, HEIGHT, r2.vec2(0, 0), 1.0)
	r2.camera_set(camera)

	log.info("Camera Demo Controls:")
	log.info("  WASD - Move camera")
	log.info("  Q/E - Rotate camera")
	log.info("  Z/X - Zoom in/out")
	log.info("  R - Reset camera")
	log.info("  SPACE - Camera shake")
	log.info("  Mouse click - Debug world coordinates")
}

update :: proc() {
	dt: f32 = 1.0 / 60.0 // Assume 60 FPS for this demo
	camera_speed: f32 = 200.0 * dt
	zoom_speed: f32 = 2.0 * dt
	rotation_speed: f32 = 1.5 * dt

	// Camera movement with WASD
	move_vec := r2.vec2(0, 0)
	if r2.is_key_pressed(.W) do move_vec.y -= camera_speed
	if r2.is_key_pressed(.S) do move_vec.y += camera_speed
	if r2.is_key_pressed(.A) do move_vec.x -= camera_speed
	if r2.is_key_pressed(.D) do move_vec.x += camera_speed

	if r2.vec2_length(move_vec) > 0 {
		r2.camera_move(move_vec)
	}

	// Camera rotation with Q/E
	if r2.is_key_pressed(.Q) {
		current := r2.camera_get()
		r2.camera_set_rotation(current.rotation - rotation_speed)
	}
	if r2.is_key_pressed(.E) {
		current := r2.camera_get()
		r2.camera_set_rotation(current.rotation + rotation_speed)
	}

	// Camera zoom with Z/X
	if r2.is_key_pressed(.Z) {
		current := r2.camera_get()
		r2.camera_set_zoom(current.zoom + zoom_speed)
	}
	if r2.is_key_pressed(.X) {
		current := r2.camera_get()
		r2.camera_set_zoom(current.zoom - zoom_speed)
	}

	// Reset camera with R
	if r2.is_key_just_pressed(.R) {
		camera = r2.camera_create_centered(WIDTH, HEIGHT, r2.vec2(0, 0), 1.0)
		r2.camera_set(camera)
		log.info("Camera reset")
	}

	// Camera shake with SPACE
	if r2.is_key_just_pressed(.SPACE) {
		r2.camera_start_shake(5.0, 0.5, 20.0)
		log.info("Camera shake started")
	}

	// Update camera shake
	r2.camera_update_shake(dt)

	// Debug info on mouse click
	if r2.is_mouse_just_pressed(.LEFT) {
		mouse_pos := r2.get_mouse_position()
		world_pos := r2.screen_to_world(mouse_pos)
		log.infof(
			"Mouse clicked - Screen: (%.1f, %.1f), World: (%.1f, %.1f)",
			mouse_pos.x,
			mouse_pos.y,
			world_pos.x,
			world_pos.y,
		)
	}
}

render :: proc() {
	// Clear with a dark blue background
	r2.clear({20, 30, 50, 255})

	// Draw world objects (affected by camera)
	draw_world()

	// Draw UI (not affected by camera)
	draw_ui()
}

draw_world :: proc() {
	// Draw a grid of logos to show the world space
	min_bounds, max_bounds, _ := r2.camera_get_world_bounds()

	// Draw logos in a grid pattern
	logo_size: f32 = 100.0
	spacing: f32 = 150.0

	start_x := math.floor_f32(min_bounds.x / spacing) * spacing
	end_x := math.ceil_f32(max_bounds.x / spacing) * spacing
	start_y := math.floor_f32(min_bounds.y / spacing) * spacing
	end_y := math.ceil_f32(max_bounds.y / spacing) * spacing

	for x := start_x; x <= end_x; x += spacing {
		for y := start_y; y <= end_y; y += spacing {
			// Color based on position
			red := u8(128 + (int(x / spacing) * 25) % 128)
			green := u8(128 + (int(y / spacing) * 25) % 128)
			blue := u8(200)

			r2.draw_texture(
				logo,
				{0, 0, 400, 400}, // Full texture
				{x - logo_size / 2, y - logo_size / 2, logo_size, logo_size},
				{red, green, blue, 255},
			)

			// Draw coordinate labels
			coord_text := fmt.tprintf("(%.0f,%.0f)", x, y)
			r2.draw_text(coord_text, font, {x - 30, y + logo_size / 2 + 5}, {255, 255, 255, 255})
		}
	}

	// Draw origin marker (larger, white logo)
	r2.draw_texture(logo, {0, 0, 400, 400}, {-75, -75, 150, 150}, {255, 255, 255, 255})

	// Draw origin text
	r2.draw_text("ORIGIN", font, {-30, 80}, {255, 255, 0, 255})
}

draw_ui :: proc() {
	// Save current camera and reset to screen space for UI
	r2.camera_push(r2.camera_create())

	// Draw UI elements in screen space
	current_cam := r2.camera_get()
	ui_text := fmt.tprintf(
		"Camera System Demo\n" +
		"Position: (%.1f, %.1f)\n" +
		"Zoom: %.2fx\n" +
		"Rotation: %.1f°\n\n" +
		"Controls:\n" +
		"WASD - Move camera\n" +
		"Q/E - Rotate camera\n" +
		"Z/X - Zoom in/out\n" +
		"R - Reset camera\n" +
		"SPACE - Shake camera",
		current_cam.position.x,
		current_cam.position.y,
		current_cam.zoom,
		math.to_degrees(current_cam.rotation),
	)

	r2.draw_text(ui_text, font, {10, 10}, {255, 255, 255, 255})

	// Mouse position info
	mouse_pos := r2.get_mouse_position()
	mouse_text := fmt.tprintf("Mouse Screen: (%.0f, %.0f)", mouse_pos.x, mouse_pos.y)
	r2.draw_text(mouse_text, font, {10, HEIGHT - 50}, {200, 200, 200, 255})

	// Convert mouse to world coordinates and display
	world_pos := r2.screen_to_world(mouse_pos)
	world_text := fmt.tprintf("Mouse World: (%.1f, %.1f)", world_pos.x, world_pos.y)
	r2.draw_text(world_text, font, {10, HEIGHT - 25}, {200, 200, 200, 255})

	// Restore previous camera
	r2.camera_pop()
}

cleanup :: proc() {
	r2.unload_texture(logo)
	r2.unload_font(font)
}
