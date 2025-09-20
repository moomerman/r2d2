package r2d2

import sapp ".deps/github.com/floooh/sokol-odin/sokol/app"
import sgfx ".deps/github.com/floooh/sokol-odin/sokol/gfx"
import sglue ".deps/github.com/floooh/sokol-odin/sokol/glue"
import "base:runtime"
import "core:log"
import "core:strings"

// Internal state
BackendState :: struct {
	initialized:        bool,
	should_quit:        bool,
	clear_color:        Color,
	window_info:        Window,

	// Callbacks
	update_callback:    UpdateProc,
	render_callback:    RenderProc,
	init_callback:      proc(),
	cleanup_callback:   proc(),

	// Mouse state
	mouse_pos:          [2]f32,
	mouse_pressed:      [MouseButton]bool,
	mouse_just_pressed: [MouseButton]bool,
}

backend_state: BackendState

// Sokol callbacks
sokol_init :: proc "c" () {
	context = runtime.default_context()
	context.logger = log.create_console_logger()
	sgfx.setup({environment = sglue.environment(), logger = {func = slog_func}})

	texture_init()
	batch_init()

	backend_state.initialized = true
	log.info("Sokol graphics initialized")

	// Call init callback if set
	if backend_state.init_callback != nil {
		backend_state.init_callback()
		log.info("Game initialized")
	}
}

sokol_frame :: proc "c" () {
	context = runtime.default_context()
	context.logger = log.create_console_logger()

	if !backend_state.initialized do return

	@(static) frame_count: int = 0
	frame_count += 1

	// Clear previous frame's "just pressed" state
	for &pressed in backend_state.mouse_just_pressed {
		pressed = false
	}

	// Call user update
	if backend_state.update_callback != nil {
		backend_state.update_callback()
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
	batch_begin()
	batch_set_projection(800, 600) // TODO: Get actual window size

	// Call user render
	if backend_state.render_callback != nil {
		backend_state.render_callback()
	}

	// Finish rendering
	batch_end()

	sgfx.end_pass()
	sgfx.commit()
}

sokol_cleanup :: proc "c" () {
	context = runtime.default_context()
	context.logger = log.create_console_logger()

	// Call user cleanup callback if set
	if backend_state.cleanup_callback != nil {
		backend_state.cleanup_callback()
		log.info("User cleanup completed")
	}

	batch_cleanup()
	sgfx.shutdown()
	log.info("Sokol graphics cleaned up")
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
		if button != nil {
			backend_state.mouse_pressed[button] = true
			backend_state.mouse_just_pressed[button] = true
		}

	case .MOUSE_UP:
		backend_state.mouse_pos = {event.mouse_x, event.mouse_y}
		button := sokol_mouse_button_to_our_button(event.mouse_button)
		if button != nil {
			backend_state.mouse_pressed[button] = false
		}

	case .QUIT_REQUESTED:
		backend_state.should_quit = true
	}
}


sokol_mouse_button_to_our_button :: proc(sokol_button: sapp.Mousebutton) -> MouseButton {
	switch sokol_button {
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

// Backend interface implementations
backend_init :: proc(window: Window) {
	backend_state.clear_color = {50, 100, 150, 255}
	backend_state.should_quit = false
	backend_state.window_info = window
}

backend_start :: proc() {
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

backend_set_callbacks :: proc(update_proc: UpdateProc, render_proc: RenderProc) {
	backend_state.update_callback = update_proc
	backend_state.render_callback = render_proc
}

backend_set_init_callback :: proc(init_proc: proc()) {
	backend_state.init_callback = init_proc
}

backend_set_cleanup_callback :: proc(cleanup_proc: proc()) {
	backend_state.cleanup_callback = cleanup_proc
}

backend_should_quit :: proc() -> bool {
	return backend_state.should_quit
}

backend_clear :: proc(color: Color) {
	backend_state.clear_color = color
}

backend_get_mouse_position :: proc() -> [2]f32 {
	return backend_state.mouse_pos
}

backend_is_mouse_pressed :: proc(button: MouseButton) -> bool {
	return backend_state.mouse_pressed[button]
}

backend_is_mouse_just_pressed :: proc(button: MouseButton) -> bool {
	return backend_state.mouse_just_pressed[button]
}
