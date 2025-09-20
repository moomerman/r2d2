package r2d2

Rect :: struct {
	x, y, w, h: f32,
}

rect :: proc {
	rect_xywh,
	rect_pos_size,
}

rect_xywh :: proc(x, y, w, h: f32) -> Rect {
	return {x, y, w, h}
}

rect_pos_size :: proc(pos: Vec2, size: Vec2) -> Rect {
	return {pos.x, pos.y, size.x, size.y}
}
