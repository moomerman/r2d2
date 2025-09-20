package r2d2

import "core:math"

Vec2 :: [2]f32

vec2 :: proc {
	vec2_xy,
	vec2_scalar,
}

vec2_xy :: proc(x, y: f32) -> Vec2 {
	return {x, y}
}

vec2_scalar :: proc(s: f32) -> Vec2 {
	return {s, s}
}

vec2_length :: proc(v: Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

vec2_length_squared :: proc(v: Vec2) -> f32 {
	return v.x * v.x + v.y * v.y
}

vec2_normalize :: proc(v: Vec2) -> Vec2 {
	length := vec2_length(v)
	if length == 0 do return {0, 0}
	return v / length
}

vec2_distance :: proc(a, b: Vec2) -> f32 {
	return vec2_length(b - a)
}

vec2_dot :: proc(a, b: Vec2) -> f32 {
	return a.x * b.x + a.y * b.y
}

vec2_lerp :: proc(a, b: Vec2, t: f32) -> Vec2 {
	return a + (b - a) * t
}

vec2_rotate :: proc(v: Vec2, angle: f32) -> Vec2 {
	cos_a := math.cos(angle)
	sin_a := math.sin(angle)
	return {v.x * cos_a - v.y * sin_a, v.x * sin_a + v.y * cos_a}
}
