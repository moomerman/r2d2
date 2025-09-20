package r2d2

import "core:log"

// Core types
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

UpdateProc :: proc()
RenderProc :: proc()
InitProc :: proc()
CleanupProc :: proc()

init :: proc(window: Window) {
	backend_init(window)
}

run :: proc(
	init_proc: InitProc = nil,
	update_proc: UpdateProc,
	render_proc: RenderProc,
	cleanup_proc: CleanupProc = nil,
) {
	if init_proc != nil {
		backend_set_init_callback(init_proc)
	}
	if cleanup_proc != nil {
		backend_set_cleanup_callback(cleanup_proc)
	}
	backend_set_callbacks(update_proc, render_proc)
	backend_start() // This starts the Sokol main loop and blocks until window closes

	// Automatic shutdown after main loop ends
	shutdown()
}

shutdown :: proc() {
	texture_cleanup()
}

load_texture :: proc(path: string) -> Texture {
	return texture_load(path)
}

unload_texture :: proc(texture: Texture) {
	texture_unload(texture)
}

load_font :: proc(path: string, size: int) -> Font {
	// TODO: Load font using STB truetype
	return 0
}

clear :: proc(color: Color) {
	backend_clear(color)
}

draw_texture :: proc(texture: Texture, src: Rect, dest: Rect) {
	sokol_texture := texture_get_sokol(texture)
	if sokol_texture.id == 0 {
		log.warnf("draw_texture: invalid texture handle %d", texture)
		return
	}

	texture_width, texture_height := texture_get_size(texture)
	texture_size := [2]f32{texture_width, texture_height}
	batch_add_sprite(sokol_texture, src, dest, {255, 255, 255, 255}, texture_size)
}

draw_texture_tinted :: proc(texture: Texture, src: Rect, dest: Rect, tint: Color) {
	sokol_texture := texture_get_sokol(texture)
	if sokol_texture.id == 0 {
		log.warnf("draw_texture_tinted: invalid texture handle %d", texture)
		return
	}

	texture_width, texture_height := texture_get_size(texture)
	texture_size := [2]f32{texture_width, texture_height}
	batch_add_sprite(sokol_texture, src, dest, tint, texture_size)
}

draw_text :: proc(text: string, font: Font, position: [2]f32, color: Color) {
	// TODO: Render text using font atlas or dynamic texture
}

// Utility
get_text_size :: proc(text: string, font: Font) -> [2]f32 {
	// TODO: Calculate text dimensions
	return {0, 0}
}

get_texture_size :: proc(texture: Texture) -> (width: f32, height: f32) {
	return texture_get_size(texture)
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

// Input
get_mouse_position :: proc() -> [2]f32 {
	return backend_get_mouse_position()
}

is_mouse_pressed :: proc(button: MouseButton) -> bool {
	return backend_is_mouse_pressed(button)
}

is_mouse_just_pressed :: proc(button: MouseButton) -> bool {
	return backend_is_mouse_just_pressed(button)
}

should_quit :: proc() -> bool {
	return backend_should_quit()
}
