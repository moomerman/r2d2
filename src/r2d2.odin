package r2d2

import backend "./sokol"

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

Rect :: struct {
	x, y, w, h: f32,
}

MouseButton :: enum {
	LEFT,
	RIGHT,
	MIDDLE,
}

init :: proc(window: Window) {
	backend.init(
		backend.Window{title = window.title, width = window.width, height = window.height},
	)
	init_fonts()
}

run :: proc(init: proc(), update: proc(), render: proc(), cleanup: proc()) {
	backend.set_callbacks(init, update, render, cleanup)
	backend.start() // blocking
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

clear :: proc(color: Color) {
	backend.clear_screen(backend.Color(color))
}

draw_texture :: proc(texture: Texture, src: Rect, dest: Rect, tint: Color = {255, 255, 255, 255}) {
	backend.draw_sprite(u32(texture), backend.Rect(src), backend.Rect(dest), backend.Color(tint))
}

draw_text :: proc(text: string, font: Font, position: [2]f32, color: Color) {
	text_draw(text, font, position, color)
}

get_text_size :: proc(text: string, font: Font) -> [2]f32 {
	return text_get_size(text, font)
}

get_texture_size :: proc(texture: Texture) -> (width: f32, height: f32) {
	return backend.get_texture_size(u32(texture))
}

screen_to_world :: proc(screen_pos: [2]f32, camera_pos: [2]f32, camera_scale: f32) -> [2]f32 {
	return {
		(screen_pos.x / camera_scale) + camera_pos.x,
		(screen_pos.y / camera_scale) + camera_pos.y,
	}
}

world_to_screen :: proc(world_pos: [2]f32, camera_pos: [2]f32, camera_scale: f32) -> [2]f32 {
	return {
		(world_pos.x - camera_pos.x) * camera_scale,
		(world_pos.y - camera_pos.y) * camera_scale,
	}
}

get_mouse_position :: proc() -> [2]f32 {
	return backend.get_mouse_position()
}

is_mouse_pressed :: proc(button: MouseButton) -> bool {
	return backend.is_mouse_pressed(backend.MouseButton(button))
}

is_mouse_just_pressed :: proc(button: MouseButton) -> bool {
	return backend.is_mouse_just_pressed(backend.MouseButton(button))
}

should_quit :: proc() -> bool {
	return backend.should_quit()
}
