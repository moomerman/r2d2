package r2d2

import sgfx ".deps/github.com/floooh/sokol-odin/sokol/gfx"
import "core:log"
import "core:math/linalg"

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
	current_view:    sgfx.View,

	// Current state
	current_texture: sgfx.Image,
	max_sprites:     int,
	sprite_count:    int,
	projection:      linalg.Matrix4f32,
}

// Global batch instance
sprite_batch: SpriteBatch

batch_init :: proc() {
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

	// Create default sampler (will be reused)
	sprite_batch.default_sampler = sgfx.make_sampler({})

	log.info("Sprite batch system initialized")
}

batch_cleanup :: proc() {
	sgfx.destroy_buffer(sprite_batch.vertex_buffer)
	sgfx.destroy_buffer(sprite_batch.index_buffer)
	sgfx.destroy_pipeline(sprite_batch.pipeline)

	if sprite_batch.default_sampler.id != 0 {
		sgfx.destroy_sampler(sprite_batch.default_sampler)
	}
	if sprite_batch.current_view.id != 0 {
		sgfx.destroy_view(sprite_batch.current_view)
	}

	delete(sprite_batch.vertices)
	delete(sprite_batch.indices)

	log.info("Sprite batch system cleaned up")
}

batch_begin :: proc() {
	clear_dynamic_array(&sprite_batch.vertices)
	sprite_batch.sprite_count = 0
	// Don't reset current_texture - let it persist between frames for batching efficiency
}

batch_set_projection :: proc(width, height: f32) {
	// Create orthographic projection matrix for 2D rendering
	sprite_batch.projection = linalg.matrix_ortho3d(0, width, height, 0, -1, 1)
}

batch_add_sprite :: proc(
	texture: sgfx.Image,
	src: Rect,
	dest: Rect,
	tint: Color,
	texture_size: [2]f32,
) {
	// Flush if texture changed or batch is full
	if sprite_batch.current_texture.id != texture.id ||
	   sprite_batch.sprite_count >= sprite_batch.max_sprites {
		batch_flush()
		sprite_batch.current_texture = texture

		// Update view when texture changes
		if sprite_batch.current_view.id != 0 {
			sgfx.destroy_view(sprite_batch.current_view)
		}
		sprite_batch.current_view = sgfx.make_view({texture = {image = texture}})
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

batch_flush :: proc() {
	if sprite_batch.sprite_count == 0 do return

	if len(sprite_batch.vertices) == 0 {
		log.warn("batch_flush: Empty vertex buffer")
		return
	}

	// Update vertex buffer with current vertices
	vertex_data := sgfx.Range {
		ptr  = raw_data(sprite_batch.vertices),
		size = uint(len(sprite_batch.vertices) * size_of(SpriteVertex)),
	}
	sgfx.update_buffer(sprite_batch.vertex_buffer, vertex_data)

	// Set up bindings using cached sampler and view
	bindings := sgfx.Bindings {
		vertex_buffers = {0 = sprite_batch.vertex_buffer},
		index_buffer = sprite_batch.index_buffer,
		views = {0 = sprite_batch.current_view},
		samplers = {0 = sprite_batch.default_sampler},
	}

	// Apply pipeline and bindings
	sgfx.apply_pipeline(sprite_batch.pipeline)
	sgfx.apply_bindings(bindings)

	// Apply uniforms using generated uniform structure
	uniforms := Uniforms {
		projection = sprite_batch.projection,
	}

	sgfx.apply_uniforms(UB_uniforms, {ptr = &uniforms, size = size_of(Uniforms)})

	// Draw
	num_indices := sprite_batch.sprite_count * 6
	if num_indices <= 0 {
		log.warnf("batch_flush: Invalid index count: %d", num_indices)
		return
	}

	sgfx.draw(0, num_indices, 1)

	// Reset for next batch
	clear_dynamic_array(&sprite_batch.vertices)
	sprite_batch.sprite_count = 0
}

batch_end :: proc() {
	batch_flush()
}
