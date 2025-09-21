package delores
// run this with `cd examples && odin run delores`

import "core:fmt"
import "core:log"

import r2 "../../src"

scene_texture: r2.Texture
game_texture: r2.Texture
font: r2.Font

WIDTH :: 1280
HEIGHT :: 720

main :: proc() {
	context.logger = log.create_console_logger()
	r2.init({title = "Delores (R2D2 Version)", width = WIDTH, height = HEIGHT})
	r2.run(init, update, render, cleanup)
}

init :: proc() {
	font = r2.load_font("delores/assets/fonts/crimes-09.ttf", 32)
	scene_texture = r2.load_texture("delores/assets/scenes/post_office.png")
	game_texture = r2.load_texture("delores/assets/game.png")

	camera := r2.camera_create_centered(WIDTH, HEIGHT, {160, 90}, 4.0)
	r2.camera_set(camera)
}

update :: proc() {
	mouse_pos := r2.get_mouse_position()
	if r2.is_mouse_just_pressed(.LEFT) {
		log.infof("Mouse clicked at: (%.2f, %.2f)", mouse_pos.x, mouse_pos.y)
	}
	defer free_all(context.temp_allocator)
}

render :: proc() {
	clear()
	draw_textures()
	draw_text()
}

cleanup :: proc() {
	r2.unload_texture(scene_texture)
	r2.unload_texture(game_texture)
	r2.unload_font(font)
}

clear :: proc() {
	r2.clear({0, 0, 0, 255})
}

draw_textures :: proc() {
	// Draw main room background
	r2.draw_texture(scene_texture, {0, 0, 320, 180}, {0, 0, 320, 180})

	// Draw ceiling lamp from same texture
	r2.draw_texture(scene_texture, {327, 3, 155, 109}, {45, 8, 155, 109})
}

draw_text :: proc() {
	r2.draw_text("Hello R2D2!", font, {50, 50}, {255, 255, 255, 255})
	r2.draw_text("Post Office Scene", font, {14, 14}, {255, 255, 255, 255})
}
