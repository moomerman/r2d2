package sokol

import "core:c"
import "core:log"
import "core:math/linalg"
import "core:strings"

import stbi "vendor:stb/image"

import sgfx "../../.deps/github.com/floooh/sokol-odin/sokol/gfx"

// Define our own types to avoid cyclical imports
Rect :: struct {
	x, y, w, h: f32,
}

Color :: struct {
	r, g, b, a: u8,
}

// Type alias expected by generated shader
Mat4 :: linalg.Matrix4f32

// Vertex structure for 2D sprites
SpriteVertex :: struct {
	position: [2]f32,
	uv:       [2]f32,
	color:    [4]f32,
}

// Sprite batch for efficient rendering
SpriteBatch :: struct {
	vertices:        [dynamic]SpriteVertex,
	indices:         [dynamic]u16,

	// Sokol resources
	pipeline:        sgfx.Pipeline,
	vertex_buffer:   sgfx.Buffer,
	index_buffer:    sgfx.Buffer,
	default_sampler: sgfx.Sampler,

	// Current state
	current_texture: sgfx.Image,
	max_sprites:     int,
	sprite_count:    int,
	projection:      linalg.Matrix4f32,
	transform:       linalg.Matrix4f32,
	view_projection: linalg.Matrix4f32,
}

// Separate font batch to avoid conflicts with texture rendering
FontBatch :: struct {
	vertices:        [dynamic]SpriteVertex,

	// Separate Sokol resources
	pipeline:        sgfx.Pipeline,
	vertex_buffer:   sgfx.Buffer,
	index_buffer:    sgfx.Buffer,
	sampler:         sgfx.Sampler,
	bindings:        sgfx.Bindings,

	// Font state
	current_texture: sgfx.Image,
	max_sprites:     int,
	sprite_count:    int,
	projection:      linalg.Matrix4f32,
}

// Global batch instances
sprite_batch: SpriteBatch
font_batch: FontBatch

init_batch :: proc() {
	// Initialize texture manager
	texture_manager.textures = make([dynamic]TextureInfo)
	texture_manager.path_to_handle = make(map[string]u32)
	texture_manager.handle_to_path = make(map[u32]string)
	texture_manager.next_handle = 1

	sprite_batch.max_sprites = 1000
	sprite_batch.vertices = make([dynamic]SpriteVertex, 0, sprite_batch.max_sprites * 4)
	sprite_batch.indices = make([dynamic]u16, 0, sprite_batch.max_sprites * 6)

	// Create vertex buffer (dynamic, will be updated each frame)
	sprite_batch.vertex_buffer = sgfx.make_buffer(
		{
			usage = {vertex_buffer = true, dynamic_update = true},
			size = uint(sprite_batch.max_sprites * 4 * size_of(SpriteVertex)),
			label = "sprite_vertex_buffer",
		},
	)

	// Create index buffer (immutable, set up once with quad patterns)
	indices_data := make([dynamic]u16, sprite_batch.max_sprites * 6)
	for i in 0 ..< sprite_batch.max_sprites {
		base := u16(i * 4)
		quad_indices := [6]u16 {
			base + 0,
			base + 1,
			base + 2, // First triangle
			base + 0,
			base + 2,
			base + 3, // Second triangle
		}
		for j in 0 ..< 6 {
			indices_data[i * 6 + j] = quad_indices[j]
		}
	}

	sprite_batch.index_buffer = sgfx.make_buffer(
		{
			usage = {index_buffer = true},
			data = {ptr = raw_data(indices_data), size = uint(len(indices_data) * size_of(u16))},
			label = "sprite_index_buffer",
		},
	)

	delete(indices_data)

	// Create shader using generated sprite shader
	shader := sgfx.make_shader(sprite_shader_desc(sgfx.query_backend()))

	// Pipeline layout description using generated constants
	layout := sgfx.Vertex_Layout_State {
		buffers = {0 = {stride = i32(size_of(SpriteVertex))}},
		attrs = {
			ATTR_sprite_position = {
				buffer_index = 0,
				format = .FLOAT2,
				offset = i32(offset_of(SpriteVertex, position)),
			},
			ATTR_sprite_texcoord = {
				buffer_index = 0,
				format = .FLOAT2,
				offset = i32(offset_of(SpriteVertex, uv)),
			},
			ATTR_sprite_color = {
				buffer_index = 0,
				format = .FLOAT4,
				offset = i32(offset_of(SpriteVertex, color)),
			},
		},
	}

	sprite_batch.pipeline = sgfx.make_pipeline(
		{
			shader = shader,
			layout = layout,
			index_type = .UINT16,
			colors = {
				0 = {
					blend = {
						enabled = true,
						src_factor_rgb = .SRC_ALPHA,
						dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
						src_factor_alpha = .SRC_ALPHA,
						dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
					},
				},
			},
			label = "sprite_pipeline",
		},
	)

	// Create default sampler
	sprite_batch.default_sampler = sgfx.make_sampler({})

	// Initialize font batch with separate resources
	font_batch.max_sprites = 500
	font_batch.vertices = make([dynamic]SpriteVertex, 0, font_batch.max_sprites * 4)

	// Create separate vertex buffer for fonts
	font_batch.vertex_buffer = sgfx.make_buffer(
		{
			usage = {vertex_buffer = true, dynamic_update = true},
			size = uint(font_batch.max_sprites * 4 * size_of(SpriteVertex)),
			label = "font_vertex_buffer",
		},
	)

	// Reuse index buffer (it's just pattern data)
	font_batch.index_buffer = sprite_batch.index_buffer

	// Create separate sampler for fonts
	font_batch.sampler = sgfx.make_sampler({})

	// Pipeline layout description for fonts (same as sprites)
	font_layout := sgfx.Vertex_Layout_State {
		buffers = {0 = {stride = i32(size_of(SpriteVertex))}},
		attrs = {
			ATTR_sprite_position = {
				buffer_index = 0,
				format = .FLOAT2,
				offset = i32(offset_of(SpriteVertex, position)),
			},
			ATTR_sprite_texcoord = {
				buffer_index = 0,
				format = .FLOAT2,
				offset = i32(offset_of(SpriteVertex, uv)),
			},
			ATTR_sprite_color = {
				buffer_index = 0,
				format = .FLOAT4,
				offset = i32(offset_of(SpriteVertex, color)),
			},
		},
	}

	// Create separate pipeline for fonts (same shader, separate instance)
	font_batch.pipeline = sgfx.make_pipeline(
		{
			shader = sgfx.make_shader(sprite_shader_desc(sgfx.query_backend())),
			layout = font_layout,
			index_type = .UINT16,
			colors = {
				0 = {
					blend = {
						enabled = true,
						src_factor_rgb = .SRC_ALPHA,
						dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
						src_factor_alpha = .SRC_ALPHA,
						dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
					},
				},
			},
			label = "font_pipeline",
		},
	)

	// Set up font bindings
	font_batch.bindings = sgfx.Bindings {
		vertex_buffers = {0 = font_batch.vertex_buffer},
		index_buffer = font_batch.index_buffer,
		samplers = {0 = font_batch.sampler},
	}

	// Initialize font projection
	font_batch.projection = linalg.matrix_ortho3d_f32(0, 800, 600, 0, -1, 1)
}

cleanup :: proc() {
	sgfx.destroy_buffer(sprite_batch.vertex_buffer)
	sgfx.destroy_buffer(sprite_batch.index_buffer)
	sgfx.destroy_pipeline(sprite_batch.pipeline)

	if sprite_batch.default_sampler.id != 0 {
		sgfx.destroy_sampler(sprite_batch.default_sampler)
	}

	// Cleanup font batch resources
	sgfx.destroy_buffer(font_batch.vertex_buffer)
	sgfx.destroy_pipeline(font_batch.pipeline)
	sgfx.destroy_sampler(font_batch.sampler)

	delete(sprite_batch.vertices)
	delete(sprite_batch.indices)
	delete(font_batch.vertices)

	// Cleanup texture manager
	cleanup_textures()
	delete(texture_manager.textures)

	// Only delete strings once since both maps reference the same strings
	for _, path in texture_manager.handle_to_path {
		delete(path)
	}
	delete(texture_manager.path_to_handle)
	delete(texture_manager.handle_to_path)
}

begin :: proc() {
	clear_dynamic_array(&sprite_batch.vertices)
	sprite_batch.sprite_count = 0
	// Reset current_texture to ensure clean state
	sprite_batch.current_texture = {}

	// Reset font batch
	clear_dynamic_array(&font_batch.vertices)
	font_batch.sprite_count = 0
	font_batch.current_texture = {}
}

set_projection :: proc(width, height: f32) {
	// Create orthographic projection matrix for 2D rendering
	sprite_batch.projection = linalg.matrix_ortho3d(0, width, height, 0, -1, 1)
	sprite_batch.transform = linalg.MATRIX4F32_IDENTITY
	update_view_projection()
}

set_transform_matrix :: proc(transform: linalg.Matrix4f32) {
	sprite_batch.transform = transform
	update_view_projection()
}

reset_transform_matrix :: proc() {
	sprite_batch.transform = linalg.MATRIX4F32_IDENTITY
	update_view_projection()
}

update_view_projection :: proc() {
	sprite_batch.view_projection = sprite_batch.projection * sprite_batch.transform
}

add_sprite :: proc(texture: sgfx.Image, src: Rect, dest: Rect, tint: Color, texture_size: [2]f32) {
	// Flush if texture changed or batch is full
	if sprite_batch.current_texture.id != texture.id ||
	   sprite_batch.sprite_count >= sprite_batch.max_sprites {
		flush()
		sprite_batch.current_texture = texture
	}

	// Normalize color to 0-1 range
	color := [4]f32 {
		f32(tint.r) / 255.0,
		f32(tint.g) / 255.0,
		f32(tint.b) / 255.0,
		f32(tint.a) / 255.0,
	}

	// Use actual texture dimensions
	texture_width := texture_size.x
	texture_height := texture_size.y

	// Calculate UV coordinates - if src is already normalized (0-1), use as-is
	// Otherwise normalize from pixel coordinates
	uv := Rect{}
	if src.x <= 1 && src.y <= 1 && src.w <= 1 && src.h <= 1 {
		// Already normalized coordinates
		uv = src
	} else {
		// Pixel coordinates, need to normalize
		uv = Rect {
			x = src.x / texture_width,
			y = src.y / texture_height,
			w = src.w / texture_width,
			h = src.h / texture_height,
		}
	}

	// Add four vertices for the quad (counter-clockwise)
	append(
		&sprite_batch.vertices,
		SpriteVertex {
			position = {dest.x, dest.y}, // Top-left
			uv       = {uv.x, uv.y},
			color    = color,
		},
	)
	append(
		&sprite_batch.vertices,
		SpriteVertex {
			position = {dest.x + dest.w, dest.y}, // Top-right
			uv       = {uv.x + uv.w, uv.y},
			color    = color,
		},
	)
	append(
		&sprite_batch.vertices,
		SpriteVertex {
			position = {dest.x + dest.w, dest.y + dest.h}, // Bottom-right
			uv       = {uv.x + uv.w, uv.y + uv.h},
			color    = color,
		},
	)
	append(
		&sprite_batch.vertices,
		SpriteVertex {
			position = {dest.x, dest.y + dest.h}, // Bottom-left
			uv       = {uv.x, uv.y + uv.h},
			color    = color,
		},
	)

	sprite_batch.sprite_count += 1
}

flush :: proc() {
	if sprite_batch.sprite_count == 0 do return

	if len(sprite_batch.vertices) == 0 {
		return
	}

	// Update vertex buffer with current vertices
	vertex_data := sgfx.Range {
		ptr  = raw_data(sprite_batch.vertices),
		size = uint(len(sprite_batch.vertices) * size_of(SpriteVertex)),
	}
	sgfx.update_buffer(sprite_batch.vertex_buffer, vertex_data)

	// Create view for current texture like the working example approach
	// Create view for current texture
	view := sgfx.make_view({texture = {image = sprite_batch.current_texture}})
	defer sgfx.destroy_view(view)

	// Set up bindings
	bindings := sgfx.Bindings {
		vertex_buffers = {0 = sprite_batch.vertex_buffer},
		index_buffer = sprite_batch.index_buffer,
		views = {0 = view},
		samplers = {0 = sprite_batch.default_sampler},
	}

	// Apply pipeline and bindings
	sgfx.apply_pipeline(sprite_batch.pipeline)
	sgfx.apply_bindings(bindings)

	// Apply uniforms using generated uniform structure
	uniforms := Uniforms {
		projection = sprite_batch.view_projection,
	}

	sgfx.apply_uniforms(UB_uniforms, {ptr = &uniforms, size = size_of(Uniforms)})

	// Draw
	num_indices := sprite_batch.sprite_count * 6
	sgfx.draw(0, num_indices, 1)

	// Reset for next batch
	clear_dynamic_array(&sprite_batch.vertices)
	sprite_batch.sprite_count = 0
}

end :: proc() {
	flush()
	flush_fonts()
}

// Complete texture management system
TextureInfo :: struct {
	image:  sgfx.Image,
	width:  i32,
	height: i32,
}

TextureManager :: struct {
	textures:       [dynamic]TextureInfo,
	path_to_handle: map[string]u32,
	handle_to_path: map[u32]string,
	next_handle:    u32,
}

// Global texture manager for this package
texture_manager: TextureManager

// Internal helper to cleanup all textures
cleanup_textures :: proc() {
	for texture_info in texture_manager.textures {
		if texture_info.image.id != 0 {
			sgfx.destroy_image(texture_info.image)
		}
	}
}

// Load texture from file path
load_texture :: proc(path: string) -> u32 {
	if handle, exists := texture_manager.path_to_handle[path]; exists {
		return handle
	}

	cpath := strings.clone_to_cstring(path, context.temp_allocator)

	width, height, channels: i32
	data := stbi.load(cpath, &width, &height, &channels, 4)
	defer stbi.image_free(data)

	if data == nil {
		log.errorf("Failed to load image: %s - %s", path, stbi.failure_reason())
		return 0
	}

	sokol_texture := sgfx.make_image(
		{
			width = width,
			height = height,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = {ptr = data, size = uint(width * height * 4)}}},
		},
	)

	if sokol_texture.id == 0 {
		log.errorf("Failed to create Sokol texture for: %s", path)
		return 0
	}

	handle := texture_manager.next_handle
	texture_manager.next_handle += 1

	texture_info := TextureInfo {
		image  = sokol_texture,
		width  = width,
		height = height,
	}
	append(&texture_manager.textures, texture_info)

	path_copy := strings.clone(path)
	texture_manager.path_to_handle[path_copy] = handle
	texture_manager.handle_to_path[handle] = path_copy

	log.infof("Loaded texture: %s (handle: %d, %dx%d)", path, handle, width, height)
	return handle
}

unload_texture :: proc(handle: u32) {
	if handle == 0 || int(handle) > len(texture_manager.textures) {
		log.warnf("unload_texture: invalid handle %d", handle)
		return
	}

	texture_info := texture_manager.textures[handle - 1]
	if texture_info.image.id != 0 {
		sgfx.destroy_image(texture_info.image)
		texture_manager.textures[handle - 1] = {}
	} else {
		log.warnf("unload_texture: handle %d already destroyed or invalid", handle)
	}

	if path, exists := texture_manager.handle_to_path[handle]; exists {
		delete_key(&texture_manager.path_to_handle, path)
		delete(path)
		delete_key(&texture_manager.handle_to_path, handle)
	}

}

get_texture_size :: proc(handle: u32) -> (width: f32, height: f32) {
	if handle == 0 || int(handle) > len(texture_manager.textures) {
		return 0, 0
	}

	texture_info := texture_manager.textures[handle - 1]
	return f32(texture_info.width), f32(texture_info.height)
}

draw_sprite :: proc(texture_handle: u32, src: Rect, dest: Rect, tint: Color) {
	if texture_handle == 0 || int(texture_handle) > len(texture_manager.textures) {
		log.warnf("draw_sprite: invalid texture handle %d", texture_handle)
		return
	}

	texture_info := texture_manager.textures[texture_handle - 1]
	if texture_info.image.id == 0 {
		log.warnf("draw_sprite: texture handle %d has no valid image", texture_handle)
		return
	}

	texture_size := [2]f32{f32(texture_info.width), f32(texture_info.height)}
	add_sprite(texture_info.image, src, dest, tint, texture_size)
}

// Create texture from raw RGBA data (for font atlases)
create_texture_from_data :: proc(data: rawptr, width: c.int, height: c.int) -> u32 {
	if data == nil || width <= 0 || height <= 0 {
		log.errorf("create_texture_from_data: invalid parameters")
		return 0
	}

	sokol_texture := sgfx.make_image(
		{
			width = width,
			height = height,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = {ptr = data, size = uint(width * height * 4)}}},
		},
	)

	if sokol_texture.id == 0 {
		log.errorf("Failed to create Sokol texture from data")
		return 0
	}

	handle := texture_manager.next_handle
	texture_manager.next_handle += 1

	texture_info := TextureInfo {
		image  = sokol_texture,
		width  = width,
		height = height,
	}
	append(&texture_manager.textures, texture_info)

	log.infof("Created texture from data (handle: %d, %dx%d)", handle, width, height)
	return handle
}

// Separate font sprite addition that uses font batch
add_font_sprite :: proc(
	texture: sgfx.Image,
	src: Rect,
	dest: Rect,
	tint: Color,
	texture_size: [2]f32,
) {
	// Flush if texture changed or batch is full
	if font_batch.current_texture.id != texture.id ||
	   font_batch.sprite_count >= font_batch.max_sprites {
		flush_fonts()
		font_batch.current_texture = texture
	}

	// Normalize color to 0-1 range
	color := [4]f32 {
		f32(tint.r) / 255.0,
		f32(tint.g) / 255.0,
		f32(tint.b) / 255.0,
		f32(tint.a) / 255.0,
	}

	// Use actual texture dimensions
	texture_width := texture_size.x
	texture_height := texture_size.y

	// Calculate UV coordinates for font atlas
	uv := Rect {
		x = src.x / texture_width,
		y = src.y / texture_height,
		w = src.w / texture_width,
		h = src.h / texture_height,
	}

	// Add four vertices for the quad (counter-clockwise)
	append(
		&font_batch.vertices,
		SpriteVertex {
			position = {dest.x, dest.y}, // Top-left
			uv       = {uv.x, uv.y},
			color    = color,
		},
	)
	append(
		&font_batch.vertices,
		SpriteVertex {
			position = {dest.x + dest.w, dest.y}, // Top-right
			uv       = {uv.x + uv.w, uv.y},
			color    = color,
		},
	)
	append(
		&font_batch.vertices,
		SpriteVertex {
			position = {dest.x + dest.w, dest.y + dest.h}, // Bottom-right
			uv       = {uv.x + uv.w, uv.y + uv.h},
			color    = color,
		},
	)
	append(
		&font_batch.vertices,
		SpriteVertex {
			position = {dest.x, dest.y + dest.h}, // Bottom-left
			uv       = {uv.x, uv.y + uv.h},
			color    = color,
		},
	)

	font_batch.sprite_count += 1
}

// Separate font flush function
flush_fonts :: proc() {
	if font_batch.sprite_count == 0 do return

	if len(font_batch.vertices) == 0 {
		return
	}

	// Update font vertex buffer with current vertices
	vertex_data := sgfx.Range {
		ptr  = raw_data(font_batch.vertices),
		size = uint(len(font_batch.vertices) * size_of(SpriteVertex)),
	}
	sgfx.update_buffer(font_batch.vertex_buffer, vertex_data)

	// Create view for font texture
	view := sgfx.make_view({texture = {image = font_batch.current_texture}})
	defer sgfx.destroy_view(view)

	// Update font bindings with current view
	font_batch.bindings.views[0] = view

	// Apply font pipeline and bindings
	sgfx.apply_pipeline(font_batch.pipeline)
	sgfx.apply_bindings(font_batch.bindings)

	// Apply font uniforms
	uniforms := Uniforms {
		projection = font_batch.projection,
	}

	sgfx.apply_uniforms(UB_uniforms, {ptr = &uniforms, size = size_of(Uniforms)})

	// Draw font sprites
	num_indices := font_batch.sprite_count * 6
	sgfx.draw(0, num_indices, 1)

	// Reset for next batch
	clear_dynamic_array(&font_batch.vertices)
	font_batch.sprite_count = 0
}

// Font-specific draw function
draw_font_sprite_internal :: proc(texture_handle: u32, src: Rect, dest: Rect, tint: Color) {
	if texture_handle == 0 || int(texture_handle) > len(texture_manager.textures) {
		log.warnf("draw_font_sprite: invalid texture handle %d", texture_handle)
		return
	}

	texture_info := texture_manager.textures[texture_handle - 1]
	if texture_info.image.id == 0 {
		log.warnf("draw_font_sprite: texture handle %d has no valid image", texture_handle)
		return
	}

	texture_size := [2]f32{f32(texture_info.width), f32(texture_info.height)}
	add_font_sprite(texture_info.image, src, dest, tint, texture_size)
}
