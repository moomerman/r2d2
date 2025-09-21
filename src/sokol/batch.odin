package sokol

import "core:c"
import "core:log"
import "core:math/linalg"
import "core:strings"

import sgfx "../../.deps/github.com/floooh/sokol-odin/sokol/gfx"
import stbi "vendor:stb/image"

Mat4 :: linalg.Matrix4f32

Rect :: struct {
	x, y, w, h: f32,
}

Color :: struct {
	r, g, b, a: u8,
}

Vertex :: struct {
	position: [2]f32,
	uv:       [2]f32,
	color:    [4]f32,
}

RenderCommand :: struct {
	texture:      sgfx.Image,
	texture_size: [2]f32,
	src_rect:     Rect,
	dest_rect:    Rect,
	color:        Color,
	transform:    linalg.Matrix4f32,
}

BatchGroup :: struct {
	texture:   sgfx.Image,
	transform: linalg.Matrix4f32,
	commands:  [dynamic]RenderCommand,
}

Renderer :: struct {
	// Command collection
	commands:        [dynamic]RenderCommand,

	// GPU resources
	vertex_buffer:   sgfx.Buffer,
	index_buffer:    sgfx.Buffer,
	pipeline:        sgfx.Pipeline,
	sampler:         sgfx.Sampler,

	// Frame data
	vertices:        [dynamic]Vertex,
	projection:      Mat4,
	transform:       Mat4,
	view_projection: Mat4,

	// Configuration
	max_sprites:     int,
}

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

renderer: Renderer
texture_manager: TextureManager

init_batch :: proc() {
	// Initialize texture manager
	texture_manager.textures = make([dynamic]TextureInfo)
	texture_manager.path_to_handle = make(map[string]u32)
	texture_manager.handle_to_path = make(map[u32]string)
	texture_manager.next_handle = 1

	// Configure renderer
	renderer.max_sprites = 2048
	renderer.commands = make([dynamic]RenderCommand, 0, renderer.max_sprites)
	renderer.vertices = make([dynamic]Vertex, 0, renderer.max_sprites * 4)

	// Create vertex buffer (dynamic, updated once per frame)
	renderer.vertex_buffer = sgfx.make_buffer(
		{
			usage = {vertex_buffer = true, dynamic_update = true},
			size = uint(renderer.max_sprites * 4 * size_of(Vertex)),
			label = "renderer_vertex_buffer",
		},
	)

	// Create index buffer (static, quad pattern)
	indices_data := make([dynamic]u16, renderer.max_sprites * 6)
	for i in 0 ..< renderer.max_sprites {
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

	renderer.index_buffer = sgfx.make_buffer(
		{
			usage = {index_buffer = true},
			data = {ptr = raw_data(indices_data), size = uint(len(indices_data) * size_of(u16))},
			label = "renderer_index_buffer",
		},
	)
	delete(indices_data)

	// Create shader and pipeline
	shader := sgfx.make_shader(sprite_shader_desc(sgfx.query_backend()))

	layout := sgfx.Vertex_Layout_State {
		buffers = {0 = {stride = i32(size_of(Vertex))}},
		attrs = {
			ATTR_sprite_position = {
				buffer_index = 0,
				format = .FLOAT2,
				offset = i32(offset_of(Vertex, position)),
			},
			ATTR_sprite_texcoord = {
				buffer_index = 0,
				format = .FLOAT2,
				offset = i32(offset_of(Vertex, uv)),
			},
			ATTR_sprite_color = {
				buffer_index = 0,
				format = .FLOAT4,
				offset = i32(offset_of(Vertex, color)),
			},
		},
	}

	renderer.pipeline = sgfx.make_pipeline(
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
					},
				},
			},
			cull_mode = .NONE,
			label = "sprite_pipeline",
		},
	)

	// Create sampler
	renderer.sampler = sgfx.make_sampler(
		{
			min_filter = .NEAREST,
			mag_filter = .NEAREST,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
			label = "sprite_sampler",
		},
	)

	// Initialize transform matrices
	renderer.transform = linalg.MATRIX4F32_IDENTITY
}

// Cleanup all resources
cleanup :: proc() {
	// Cleanup renderer resources
	if renderer.vertex_buffer.id != 0 do sgfx.destroy_buffer(renderer.vertex_buffer)
	if renderer.index_buffer.id != 0 do sgfx.destroy_buffer(renderer.index_buffer)
	if renderer.pipeline.id != 0 do sgfx.destroy_pipeline(renderer.pipeline)
	if renderer.sampler.id != 0 do sgfx.destroy_sampler(renderer.sampler)

	delete(renderer.commands)
	delete(renderer.vertices)

	cleanup_textures()
}

// Begin frame - reset command collection
begin :: proc() {
	clear_dynamic_array(&renderer.commands)
	clear_dynamic_array(&renderer.vertices)
}

set_projection :: proc(width, height: f32) {
	renderer.projection = linalg.matrix_ortho3d(0, width, height, 0, -1, 1)
	update_view_projection()
}

set_transform_matrix :: proc(transform: Mat4) {
	renderer.transform = transform
	update_view_projection()
}

reset_transform_matrix :: proc() {
	renderer.transform = linalg.MATRIX4F32_IDENTITY
	update_view_projection()
}

update_view_projection :: proc() {
	renderer.view_projection = renderer.projection * renderer.transform
}

add_sprite :: proc(texture: sgfx.Image, src: Rect, dest: Rect, tint: Color, texture_size: [2]f32) {
	if len(renderer.commands) >= renderer.max_sprites {
		log.warn("Renderer command buffer full, dropping sprite")
		return
	}

	command := RenderCommand {
		texture      = texture,
		texture_size = texture_size,
		src_rect     = src,
		dest_rect    = dest,
		color        = tint,
		transform    = renderer.view_projection, // Capture current transform
	}

	append(&renderer.commands, command)
}

command_to_vertices :: proc(cmd: RenderCommand) -> [4]Vertex {
	// Normalize color
	color := [4]f32 {
		f32(cmd.color.r) / 255.0,
		f32(cmd.color.g) / 255.0,
		f32(cmd.color.b) / 255.0,
		f32(cmd.color.a) / 255.0,
	}

	// Calculate UV coordinates
	uv := Rect{}
	if cmd.src_rect.x <= 1 && cmd.src_rect.y <= 1 && cmd.src_rect.w <= 1 && cmd.src_rect.h <= 1 {
		// Already normalized coordinates
		uv = cmd.src_rect
	} else {
		// Pixel coordinates, normalize them
		uv = Rect {
			x = cmd.src_rect.x / cmd.texture_size.x,
			y = cmd.src_rect.y / cmd.texture_size.y,
			w = cmd.src_rect.w / cmd.texture_size.x,
			h = cmd.src_rect.h / cmd.texture_size.y,
		}
	}

	// Create quad vertices (counter-clockwise)
	return [4]Vertex {
		{position = {cmd.dest_rect.x, cmd.dest_rect.y}, uv = {uv.x, uv.y}, color = color}, // Top-left
		{
			position = {cmd.dest_rect.x + cmd.dest_rect.w, cmd.dest_rect.y},
			uv = {uv.x + uv.w, uv.y},
			color = color,
		}, // Top-right
		{
			position = {cmd.dest_rect.x + cmd.dest_rect.w, cmd.dest_rect.y + cmd.dest_rect.h},
			uv = {uv.x + uv.w, uv.y + uv.h},
			color = color,
		}, // Bottom-right
		{
			position = {cmd.dest_rect.x, cmd.dest_rect.y + cmd.dest_rect.h},
			uv = {uv.x, uv.y + uv.h},
			color = color,
		}, // Bottom-left
	}
}

// Group commands by texture and transform for batching
group_commands_by_texture_and_transform :: proc(commands: []RenderCommand) -> [dynamic]BatchGroup {
	groups := make([dynamic]BatchGroup)

	if len(commands) == 0 do return groups

	current_group := BatchGroup {
		texture   = commands[0].texture,
		transform = commands[0].transform,
		commands  = make([dynamic]RenderCommand),
	}

	for cmd in commands {
		same_texture := cmd.texture.id == current_group.texture.id
		same_transform := cmd.transform == current_group.transform

		if same_texture && same_transform {
			append(&current_group.commands, cmd)
		} else {
			append(&groups, current_group)
			current_group = BatchGroup {
				texture   = cmd.texture,
				transform = cmd.transform,
				commands  = make([dynamic]RenderCommand),
			}
			append(&current_group.commands, cmd)
		}
	}

	append(&groups, current_group)

	return groups
}

// End frame - process all commands and render
end :: proc() {
	if len(renderer.commands) == 0 do return

	// Group commands by texture and transform for efficient batching
	groups := group_commands_by_texture_and_transform(renderer.commands[:])
	defer {
		for group in groups {
			delete(group.commands)
		}
		delete(groups)
	}

	// Build vertex data for all commands
	vertex_count := 0
	for group in groups {
		for cmd in group.commands {
			quad_vertices := command_to_vertices(cmd)
			for vertex in quad_vertices {
				append(&renderer.vertices, vertex)
				vertex_count += 1
			}
		}
	}

	if vertex_count == 0 do return

	// Update vertex buffer once for the entire frame
	vertex_data := sgfx.Range {
		ptr  = raw_data(renderer.vertices),
		size = uint(len(renderer.vertices) * size_of(Vertex)),
	}
	sgfx.update_buffer(renderer.vertex_buffer, vertex_data)

	// Apply pipeline once
	sgfx.apply_pipeline(renderer.pipeline)

	// Render each group with its texture and transform
	vertex_offset := 0
	for group in groups {
		sprite_count := len(group.commands)
		if sprite_count == 0 do continue

		// Apply transform-specific uniforms for this group
		uniforms := Uniforms {
			projection = group.transform,
		}
		sgfx.apply_uniforms(UB_uniforms, {ptr = &uniforms, size = size_of(Uniforms)})

		// Create view for this texture
		view := sgfx.make_view({texture = {image = group.texture}})
		defer sgfx.destroy_view(view)

		// Set up bindings for this group
		bindings := sgfx.Bindings {
			vertex_buffers = {0 = renderer.vertex_buffer},
			index_buffer = renderer.index_buffer,
			views = {0 = view},
			samplers = {0 = renderer.sampler},
		}

		sgfx.apply_bindings(bindings)

		// Draw this group
		index_offset := vertex_offset / 4 * 6 // 6 indices per quad, 4 vertices per quad
		num_indices := sprite_count * 6
		sgfx.draw(index_offset, num_indices, 1)

		vertex_offset += sprite_count * 4
	}
}

// Texture Management Functions

cleanup_textures :: proc() {
	for info in texture_manager.textures {
		if info.image.id != 0 {
			sgfx.destroy_image(info.image)
		}
	}
	delete(texture_manager.textures)

	for _, path in texture_manager.handle_to_path {
		delete_string(path)
	}
	delete(texture_manager.path_to_handle)
	delete(texture_manager.handle_to_path)
}

load_texture :: proc(path: string) -> u32 {
	// Check if already loaded
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

	image := sgfx.make_image(
		{
			width = width,
			height = height,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = {ptr = data, size = uint(width * height * 4)}}},
			label = strings.clone_to_cstring(path, context.temp_allocator),
		},
	)

	if image.id == 0 {
		log.errorf("Failed to create Sokol texture for: %s", path)
		return 0
	}

	handle := texture_manager.next_handle
	texture_manager.next_handle += 1

	texture_info := TextureInfo {
		image  = image,
		width  = width,
		height = height,
	}

	append(&texture_manager.textures, texture_info)
	texture_manager.path_to_handle[strings.clone(path)] = handle
	texture_manager.handle_to_path[handle] = strings.clone(path)

	log.infof("Loaded texture: %s (handle: %d, %dx%d)", path, handle, width, height)
	return handle
}

unload_texture :: proc(handle: u32) {
	if handle == 0 || int(handle) > len(texture_manager.textures) do return

	texture_info := &texture_manager.textures[handle - 1]
	if texture_info.image.id != 0 {
		sgfx.destroy_image(texture_info.image)
		texture_info.image = {}
	}

	if path, exists := texture_manager.handle_to_path[handle]; exists {
		delete_key(&texture_manager.path_to_handle, path)
		delete_string(path)
		delete_key(&texture_manager.handle_to_path, handle)
	}

	log.infof("Unloaded texture handle: %d", handle)
}

get_texture_size :: proc(handle: u32) -> (width: f32, height: f32) {
	if handle == 0 || int(handle) > len(texture_manager.textures) {
		return 0, 0
	}

	texture_info := texture_manager.textures[handle - 1]
	return f32(texture_info.width), f32(texture_info.height)
}

// Public API functions called by backend

draw_sprite :: proc(texture_handle: u32, src: Rect, dest: Rect, tint: Color) {
	if texture_handle == 0 || int(texture_handle) > len(texture_manager.textures) {
		log.warnf("Invalid texture handle: %d", texture_handle)
		return
	}

	texture_info := texture_manager.textures[texture_handle - 1]
	texture_size := [2]f32{f32(texture_info.width), f32(texture_info.height)}

	add_sprite(texture_info.image, src, dest, tint, texture_size)
}

create_texture_from_data :: proc(data: rawptr, width, height: c.int) -> u32 {
	if data == nil || width <= 0 || height <= 0 {
		log.errorf("create_texture_from_data: invalid parameters")
		return 0
	}

	image := sgfx.make_image(
		{
			width = width,
			height = height,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = {ptr = data, size = uint(width * height * 4)}}},
			label = "font_atlas",
		},
	)

	if image.id == 0 {
		log.errorf("Failed to create Sokol texture from data")
		return 0
	}

	handle := texture_manager.next_handle
	texture_manager.next_handle += 1

	texture_info := TextureInfo {
		image  = image,
		width  = width,
		height = height,
	}

	append(&texture_manager.textures, texture_info)

	return handle
}

draw_font_sprite_internal :: proc(texture_handle: u32, src: Rect, dest: Rect, tint: Color) {
	if texture_handle == 0 || int(texture_handle) > len(texture_manager.textures) {
		log.warnf("Invalid font texture handle: %d", texture_handle)
		return
	}

	texture_info := texture_manager.textures[texture_handle - 1]
	texture_size := [2]f32{f32(texture_info.width), f32(texture_info.height)}

	add_sprite(texture_info.image, src, dest, tint, texture_size)
}
