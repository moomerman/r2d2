package r2d2

import backend "./sokol"
import "core:math"
import "core:math/linalg"

// Camera represents a 2D view transformation
Camera :: struct {
	position: Vec2, // World position the camera is looking at
	zoom:     f32, // Scale factor (1.0 = normal, 2.0 = 2x zoom, 0.5 = zoomed out)
	rotation: f32, // Rotation in radians
	offset:   Vec2, // Screen offset (usually screen center)
}

// Global camera state
current_camera: Camera
camera_stack: [dynamic]Camera
transform_dirty: bool

// Initialize camera system
init_camera :: proc() {
	current_camera = {
		position = {0, 0},
		zoom     = 1.0,
		rotation = 0,
		offset   = {0, 0},
	}
	camera_stack = make([dynamic]Camera)
	transform_dirty = true
}

// Cleanup camera system
cleanup_camera :: proc() {
	delete(camera_stack)
}

// Create a new camera
camera_create :: proc(position: Vec2 = {0, 0}, zoom: f32 = 1.0, rotation: f32 = 0) -> Camera {
	return {position = position, zoom = zoom, rotation = rotation, offset = {0, 0}}
}

// Create a camera centered on screen
camera_create_centered :: proc(
	screen_width, screen_height: f32,
	position: Vec2 = {0, 0},
	zoom: f32 = 1.0,
) -> Camera {
	return {
		position = position,
		zoom = zoom,
		rotation = 0,
		offset = {screen_width * 0.5, screen_height * 0.5},
	}
}

// Set the current camera (affects all subsequent drawing calls)
camera_set :: proc(camera: Camera) {
	current_camera = camera
	transform_dirty = true
	update_transform_if_needed()
}

// Get the current camera
camera_get :: proc() -> Camera {
	return current_camera
}

// Reset camera to default (no transformation)
camera_reset :: proc() {
	current_camera = {
		position = {0, 0},
		zoom     = 1.0,
		rotation = 0,
		offset   = {0, 0},
	}
	transform_dirty = true
	update_transform_if_needed()
}

// Push current camera onto stack and set new camera
camera_push :: proc(camera: Camera) {
	append(&camera_stack, current_camera)
	camera_set(camera)
}

// Pop camera from stack and restore it
camera_pop :: proc() {
	if len(camera_stack) > 0 {
		current_camera = pop(&camera_stack)
		transform_dirty = true
		update_transform_if_needed()
	}
}

// Camera movement and manipulation
camera_move :: proc(offset: Vec2) {
	current_camera.position += offset
	transform_dirty = true
	update_transform_if_needed()
}

camera_set_position :: proc(position: Vec2) {
	current_camera.position = position
	transform_dirty = true
	update_transform_if_needed()
}

camera_set_zoom :: proc(zoom: f32) {
	current_camera.zoom = math.max(zoom, 0.001) // Prevent zero/negative zoom
	transform_dirty = true
	update_transform_if_needed()
}

camera_set_rotation :: proc(rotation: f32) {
	current_camera.rotation = rotation
	transform_dirty = true
	update_transform_if_needed()
}

camera_zoom_at_point :: proc(point: Vec2, zoom_delta: f32) {
	// Zoom towards a specific point (like mouse cursor)
	old_zoom := current_camera.zoom
	new_zoom := math.max(old_zoom + zoom_delta, 0.001)

	// Adjust position so the point stays in the same screen location
	world_point := screen_to_world(point)
	current_camera.zoom = new_zoom
	new_world_point := screen_to_world(point)
	current_camera.position += world_point - new_world_point

	transform_dirty = true
	update_transform_if_needed()
}

// Coordinate transformations
screen_to_world :: proc(screen_pos: Vec2) -> Vec2 {
	// Transform screen coordinates to world coordinates using current camera
	cam := current_camera

	// Translate to camera offset origin
	pos := screen_pos - cam.offset

	// Apply inverse zoom
	pos /= cam.zoom

	// Apply inverse rotation
	if cam.rotation != 0 {
		cos_r := math.cos(-cam.rotation)
		sin_r := math.sin(-cam.rotation)
		rotated_x := pos.x * cos_r - pos.y * sin_r
		rotated_y := pos.x * sin_r + pos.y * cos_r
		pos = {rotated_x, rotated_y}
	}

	// Translate to world position
	return pos + cam.position
}

world_to_screen :: proc(world_pos: Vec2) -> Vec2 {
	// Transform world coordinates to screen coordinates using current camera
	cam := current_camera

	// Translate relative to camera position
	pos := world_pos - cam.position

	// Apply rotation
	if cam.rotation != 0 {
		cos_r := math.cos(cam.rotation)
		sin_r := math.sin(cam.rotation)
		rotated_x := pos.x * cos_r - pos.y * sin_r
		rotated_y := pos.x * sin_r + pos.y * cos_r
		pos = {rotated_x, rotated_y}
	}

	// Apply zoom
	pos *= cam.zoom

	// Translate to screen coordinates
	return pos + cam.offset
}

// Get camera bounds in world coordinates (useful for culling)
camera_get_world_bounds :: proc() -> (min: Vec2, max: Vec2, size: Vec2) {
	cam := current_camera

	// Get screen corners
	screen_corners := [4]Vec2 {
		{0, 0},
		{cam.offset.x * 2, 0},
		{cam.offset.x * 2, cam.offset.y * 2},
		{0, cam.offset.y * 2},
	}

	// Convert to world coordinates
	world_corners: [4]Vec2
	for corner, i in screen_corners {
		world_corners[i] = screen_to_world(corner)
	}

	// Find bounds
	min_pos := world_corners[0]
	max_pos := world_corners[0]

	for corner in world_corners[1:] {
		min_pos.x = math.min(min_pos.x, corner.x)
		min_pos.y = math.min(min_pos.y, corner.y)
		max_pos.x = math.max(max_pos.x, corner.x)
		max_pos.y = math.max(max_pos.y, corner.y)
	}

	return min_pos, max_pos, max_pos - min_pos
}

// Convert camera to transformation matrix for backend
camera_to_matrix :: proc(camera: Camera) -> linalg.Matrix4f32 {
	// Create transformation matrix from camera parameters
	// For 2D camera: translate to center, scale, rotate, then translate by camera position

	// Start with identity
	result := linalg.MATRIX4F32_IDENTITY

	// Apply translation to offset (screen center)
	if camera.offset.x != 0 || camera.offset.y != 0 {
		result = linalg.matrix4_translate_f32({camera.offset.x, camera.offset.y, 0}) * result
	}

	// Apply zoom (scale)
	if camera.zoom != 1.0 {
		result = linalg.matrix4_scale_f32({camera.zoom, camera.zoom, 1}) * result
	}

	// Apply rotation around Z axis
	if camera.rotation != 0 {
		result = linalg.matrix4_rotate_f32(camera.rotation, {0, 0, 1}) * result
	}

	// Apply camera position (negative translation to move world)
	if camera.position.x != 0 || camera.position.y != 0 {
		result = linalg.matrix4_translate_f32({-camera.position.x, -camera.position.y, 0}) * result
	}

	// Apply inverse offset to return to origin
	if camera.offset.x != 0 || camera.offset.y != 0 {
		result = linalg.matrix4_translate_f32({-camera.offset.x, -camera.offset.y, 0}) * result
	}

	return result
}

// Update backend transform if needed
update_transform_if_needed :: proc() {
	if transform_dirty {
		transform_matrix := camera_to_matrix(current_camera)
		backend.set_transform_matrix(transform_matrix)
		transform_dirty = false
	}
}

// Camera follow utilities
camera_follow :: proc(target: Vec2, lerp_speed: f32 = 1.0, dt: f32 = 1.0 / 60.0) {
	if lerp_speed >= 1.0 {
		current_camera.position = target
	} else {
		current_camera.position = linalg.lerp(
			current_camera.position,
			target,
			lerp_speed * dt * 60.0,
		)
	}
	transform_dirty = true
	update_transform_if_needed()
}

camera_follow_smooth :: proc(target: Vec2, smoothing: f32 = 0.1, dt: f32 = 1.0 / 60.0) {
	// Exponential smoothing
	alpha := 1.0 - math.pow(smoothing, dt * 60.0)
	current_camera.position = linalg.lerp(current_camera.position, target, alpha)
	transform_dirty = true
	update_transform_if_needed()
}

// Camera shake effect
CameraShake :: struct {
	intensity: f32,
	duration:  f32,
	frequency: f32,
	time:      f32,
}

camera_shake: CameraShake

camera_start_shake :: proc(intensity: f32, duration: f32, frequency: f32 = 30.0) {
	camera_shake = {
		intensity = intensity,
		duration  = duration,
		frequency = frequency,
		time      = 0,
	}
}

camera_update_shake :: proc(dt: f32) {
	if camera_shake.duration <= 0 do return

	camera_shake.time += dt
	camera_shake.duration -= dt

	if camera_shake.duration > 0 {
		// Generate shake offset using sine waves
		shake_x :=
			math.sin(camera_shake.time * camera_shake.frequency * 2 * math.PI) *
			camera_shake.intensity
		shake_y :=
			math.sin(camera_shake.time * camera_shake.frequency * 2 * math.PI * 1.1) *
			camera_shake.intensity

		// Apply decay
		decay := camera_shake.duration / (camera_shake.duration + dt)
		shake_x *= decay
		shake_y *= decay

		// Add shake to camera position
		current_camera.position += {shake_x, shake_y}
		transform_dirty = true
		update_transform_if_needed()
	}
}
