package demo
// run this with `just run-demo`

import "core:fmt"
import "core:log"

import r2 "../../src"

logo: r2.Texture
font: r2.Font

WIDTH :: 800
HEIGHT :: 600

main :: proc() {
	context.logger = log.create_console_logger()
	r2.init({title = "R2D2 Demo", width = WIDTH, height = HEIGHT})
	r2.run(init, update, render, cleanup)
}

init :: proc() {
	font = r2.load_font("assets/crimes-09.ttf", 24)
	logo = r2.load_texture("assets/odin-logo.jpg")
}

update :: proc() {
	mouse_pos := r2.get_mouse_position()
	if r2.is_mouse_just_pressed(.LEFT) {
		log.infof("Mouse clicked at: (%.2f, %.2f)", mouse_pos.x, mouse_pos.y)
	}
	play_audio()
	defer free_all(context.temp_allocator)
}

render :: proc() {
	clear()
	draw_texture()
	draw_text()
}

cleanup :: proc() {
	r2.unload_texture(logo)
	r2.unload_font(font)
}

clear :: proc() {
	mouse_pos := r2.get_mouse_position()
	red := u8((mouse_pos.x / WIDTH) * 255)
	green := u8((mouse_pos.y / HEIGHT) * 255)
	r2.clear({red, green, 100, 255})
}

draw_texture :: proc() {
	r2.draw_texture(logo, {0, 0, 400, 400}, {100, 100, 200, 200})
	r2.draw_texture(logo, {200, 200, 200, 200}, {310, 100, 100, 100})
	r2.draw_texture(logo, {300, 300, 100, 100}, {420, 100, 100, 100})
}

draw_text :: proc() {
	r2.draw_text("Hello, R2D2!", font, {50, 50}, {255, 255, 255, 255})
	r2.draw_text("Text rendering works!", font, {50, 100}, {255, 100, 100, 255})
	r2.draw_text("Different colors!", font, {50, 150}, {100, 255, 100, 255})
	r2.draw_text("And positions!", font, {200, 200}, {100, 100, 255, 255})

	mouse_pos := r2.get_mouse_position()
	mouse_text := fmt.tprintf("Mouse: {:.0f}, {:.0f}", mouse_pos.x, mouse_pos.y)
	r2.draw_text(mouse_text, font, {50, 300}, {255, 255, 100, 255})

	text := "This text has calculated size"
	text_size := r2.get_text_size(text, font)
	r2.draw_text(text, font, {50, 400}, {200, 200, 200, 255})

	size_text := fmt.tprintf("Size: {:.0f}x{:.0f}", text_size.x, text_size.y)
	r2.draw_text(size_text, font, {50, 430}, {150, 150, 150, 255})
}

play_audio :: proc() {
	if r2.is_key_just_pressed(.SPACE) {
		r2.play_sound("assets/beep.wav")
	}

	if r2.is_key_just_pressed(.M) {
		r2.play_sound("assets/music.ogg")
	}

	if r2.is_key_pressed(.ARROW_UP) {
		r2.set_master_volume(1.0)
	}
	if r2.is_key_pressed(.ARROW_DOWN) {
		r2.set_master_volume(0.3)

	}
}
