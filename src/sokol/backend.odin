package sokol

import "base:runtime"
import "core:log"
import "core:strings"

import sapp "../../.deps/github.com/floooh/sokol-odin/sokol/app"
import sgfx "../../.deps/github.com/floooh/sokol-odin/sokol/gfx"
import sglue "../../.deps/github.com/floooh/sokol-odin/sokol/glue"

Window :: struct {
	title:  string,
	width:  int,
	height: int,
}

MouseButton :: enum {
	LEFT,
	RIGHT,
	MIDDLE,
}

Key :: enum {
	SPACE,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	ARROW_UP,
	ARROW_DOWN,
	ARROW_LEFT,
	ARROW_RIGHT,
	ENTER,
	ESCAPE,
	SHIFT,
	CTRL,
	ALT,
}

BackendState :: struct {
	initialized:        bool,
	should_quit:        bool,
	clear_color:        Color,
	window_info:        Window,

	// Callbacks
	update_callback:    proc(),
	render_callback:    proc(),
	init_callback:      proc(),
	cleanup_callback:   proc(),

	// Mouse state
	mouse_pos:          [2]f32,
	mouse_pressed:      [MouseButton]bool,
	mouse_just_pressed: [MouseButton]bool,

	// Keyboard state
	key_pressed:        [Key]bool,
	key_just_pressed:   [Key]bool,
}

backend_state: BackendState

// Sokol callbacks
sokol_init :: proc "c" () {
	context = runtime.default_context()
	context.logger = log.create_console_logger()
	sgfx.setup({environment = sglue.environment(), logger = {func = slog_func}})

	init_batch()

	backend_state.initialized = true

	if backend_state.init_callback != nil {
		backend_state.init_callback()
	}
}

sokol_frame :: proc "c" () {
	context = runtime.default_context()
	context.logger = log.create_console_logger()

	if !backend_state.initialized do return

	@(static) frame_count: int = 0
	frame_count += 1

	// Call user update
	if backend_state.update_callback != nil {
		backend_state.update_callback()
	}

	// Clear "just pressed" state after user update
	for &pressed in backend_state.mouse_just_pressed {
		pressed = false
	}
	for &pressed in backend_state.key_just_pressed {
		pressed = false
	}

	// Begin render pass
	sgfx.begin_pass(
		{
			action = {
				colors = {
					0 = {
						load_action = .CLEAR,
						clear_value = {
							f32(backend_state.clear_color.r) / 255.0,
							f32(backend_state.clear_color.g) / 255.0,
							f32(backend_state.clear_color.b) / 255.0,
							f32(backend_state.clear_color.a) / 255.0,
						},
					},
				},
			},
			swapchain = sglue.swapchain(),
		},
	)

	// Set up 2D rendering
	begin()
	set_projection(800, 600) // TODO: Get actual window size

	// Call user render
	if backend_state.render_callback != nil {
		backend_state.render_callback()
	}

	// Finish rendering
	end()

	sgfx.end_pass()
	sgfx.commit()
}

sokol_cleanup :: proc "c" () {
	context = runtime.default_context()
	context.logger = log.create_console_logger()

	if backend_state.cleanup_callback != nil {
		backend_state.cleanup_callback()
	}

	cleanup()
	sgfx.shutdown()
}

sokol_event :: proc "c" (event: ^sapp.Event) {
	context = runtime.default_context()
	context.logger = log.create_console_logger()

	#partial switch event.type {
	case .MOUSE_MOVE:
		backend_state.mouse_pos = {event.mouse_x, event.mouse_y}

	case .MOUSE_DOWN:
		backend_state.mouse_pos = {event.mouse_x, event.mouse_y}
		button := sokol_mouse_button_to_our_button(event.mouse_button)
		backend_state.mouse_pressed[button] = true
		backend_state.mouse_just_pressed[button] = true

	case .MOUSE_UP:
		backend_state.mouse_pos = {event.mouse_x, event.mouse_y}
		button := sokol_mouse_button_to_our_button(event.mouse_button)
		backend_state.mouse_pressed[button] = false

	case .KEY_DOWN:
		if key, ok := sokol_keycode_to_our_key(event.key_code); ok {
			backend_state.key_pressed[key] = true
			backend_state.key_just_pressed[key] = true
		}

	case .KEY_UP:
		if key, ok := sokol_keycode_to_our_key(event.key_code); ok {
			backend_state.key_pressed[key] = false
		}

	case .QUIT_REQUESTED:
		backend_state.should_quit = true
	}
}

sokol_keycode_to_our_key :: proc(keycode: sapp.Keycode) -> (Key, bool) {
	#partial switch keycode {
	case .SPACE:
		return .SPACE, true
	case .A:
		return .A, true
	case .B:
		return .B, true
	case .C:
		return .C, true
	case .D:
		return .D, true
	case .E:
		return .E, true
	case .F:
		return .F, true
	case .G:
		return .G, true
	case .H:
		return .H, true
	case .I:
		return .I, true
	case .J:
		return .J, true
	case .K:
		return .K, true
	case .L:
		return .L, true
	case .M:
		return .M, true
	case .N:
		return .N, true
	case .O:
		return .O, true
	case .P:
		return .P, true
	case .Q:
		return .Q, true
	case .R:
		return .R, true
	case .S:
		return .S, true
	case .T:
		return .T, true
	case .U:
		return .U, true
	case .V:
		return .V, true
	case .W:
		return .W, true
	case .X:
		return .X, true
	case .Y:
		return .Y, true
	case .Z:
		return .Z, true
	case .UP:
		return .ARROW_UP, true
	case .DOWN:
		return .ARROW_DOWN, true
	case .LEFT:
		return .ARROW_LEFT, true
	case .RIGHT:
		return .ARROW_RIGHT, true
	case .ENTER:
		return .ENTER, true
	case .ESCAPE:
		return .ESCAPE, true
	case .LEFT_SHIFT, .RIGHT_SHIFT:
		return .SHIFT, true
	case .LEFT_CONTROL, .RIGHT_CONTROL:
		return .CTRL, true
	case .LEFT_ALT, .RIGHT_ALT:
		return .ALT, true
	case:
		return .SPACE, false // Default return, but indicate failure
	}
}

sokol_mouse_button_to_our_button :: proc(button: sapp.Mousebutton) -> MouseButton {
	switch button {
	case .LEFT:
		return .LEFT
	case .RIGHT:
		return .RIGHT
	case .MIDDLE:
		return .MIDDLE
	case .INVALID:
		return .LEFT // fallback
	}
	return .LEFT
}

slog_func :: proc "c" (
	tag: cstring,
	log_level: u32,
	log_item_id: u32,
	message_or_null: cstring,
	line_nr: u32,
	filename_or_null: cstring,
	user_data: rawptr,
) {
	context = runtime.default_context()
	context.logger = log.create_console_logger()

	if message_or_null != nil {
		log.infof("[SOKOL] %s", message_or_null)
	}
}

init :: proc(window: Window) {
	backend_state.clear_color = {50, 100, 150, 255}
	backend_state.should_quit = false
	backend_state.window_info = window
}

start :: proc() {
	sapp.run(
		{
			init_cb = sokol_init,
			frame_cb = sokol_frame,
			cleanup_cb = sokol_cleanup,
			event_cb = sokol_event,
			width = i32(backend_state.window_info.width),
			height = i32(backend_state.window_info.height),
			window_title = strings.clone_to_cstring(
				backend_state.window_info.title,
				context.temp_allocator,
			),
			icon = {sokol_default = true},
			logger = {func = slog_func},
		},
	)
}

set_callbacks :: proc(
	init_proc: proc(),
	update_proc: proc(),
	render_proc: proc(),
	cleanup_proc: proc(),
) {
	backend_state.init_callback = init_proc
	backend_state.update_callback = update_proc
	backend_state.render_callback = render_proc
	backend_state.cleanup_callback = cleanup_proc
}

should_quit :: proc() -> bool {
	return backend_state.should_quit
}

is_key_pressed :: proc(key: Key) -> bool {
	return backend_state.key_pressed[key]
}

is_key_just_pressed :: proc(key: Key) -> bool {
	return backend_state.key_just_pressed[key]
}

clear_screen :: proc(color: Color) {
	backend_state.clear_color = color
}

get_mouse_position :: proc() -> [2]f32 {
	return backend_state.mouse_pos
}

is_mouse_pressed :: proc(button: MouseButton) -> bool {
	return backend_state.mouse_pressed[button]
}

is_mouse_just_pressed :: proc(button: MouseButton) -> bool {
	return backend_state.mouse_just_pressed[button]
}
