package r2d2

import backend "./sokol"

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

get_mouse_position :: proc() -> Vec2 {
	pos := backend.get_mouse_position()
	return {pos.x, pos.y}
}

is_mouse_pressed :: proc(button: MouseButton) -> bool {
	return backend.is_mouse_pressed(backend.MouseButton(button))
}

is_mouse_just_pressed :: proc(button: MouseButton) -> bool {
	return backend.is_mouse_just_pressed(backend.MouseButton(button))
}

is_key_pressed :: proc(key: Key) -> bool {
	return backend.is_key_pressed(backend.Key(key))
}

is_key_just_pressed :: proc(key: Key) -> bool {
	return backend.is_key_just_pressed(backend.Key(key))
}
