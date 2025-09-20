package r2d2

import audio "./miniaudio"
import backend "./sokol"
import "core:log"

Window :: struct {
	title:  string,
	width:  int,
	height: int,
}

Texture :: distinct u32
Font :: distinct u32

Color :: struct {
	r, g, b, a: u8,
}

init :: proc(window: Window) {
	backend.init(
		backend.Window{title = window.title, width = window.width, height = window.height},
	)
	init_text()
	init_camera()
	if !audio.init_audio() {
		log.error("Failed to initialize audio system")
	}
}

run :: proc(init: proc(), update: proc(), render: proc(), cleanup: proc()) {
	backend.set_callbacks(init, update, render, cleanup)
	backend.start() // blocking

	cleanup_text()
	cleanup_camera()
	audio.cleanup_audio()
}

load_texture :: proc(path: string) -> Texture {
	return Texture(backend.load_texture(path))
}

unload_texture :: proc(texture: Texture) {
	backend.unload_texture(u32(texture))
}

load_font :: proc(path: string, size: int) -> Font {
	return text_load_font(path, size)
}

unload_font :: proc(font: Font) {
	text_unload_font(font)
}

play_sound :: proc(path: string) -> bool {
	return audio.play_sound_file(path)
}

set_master_volume :: proc(volume: f32) -> bool {
	return audio.set_master_volume(volume)
}

clear :: proc(color: Color) {
	backend.clear_screen(backend.Color(color))
}

draw_texture :: proc(texture: Texture, src: Rect, dest: Rect, tint: Color = {255, 255, 255, 255}) {
	backend.draw_sprite(u32(texture), backend.Rect(src), backend.Rect(dest), backend.Color(tint))
}

draw_text :: proc(text: string, font: Font, position: Vec2, color: Color) {
	text_draw_text(text, font, position, color)
}

get_text_size :: proc(text: string, font: Font) -> Vec2 {
	return text_get_text_size(text, font)
}

get_texture_size :: proc(texture: Texture) -> (width: f32, height: f32) {
	return backend.get_texture_size(u32(texture))
}

should_quit :: proc() -> bool {
	return backend.should_quit()
}
