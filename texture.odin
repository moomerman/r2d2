package r2d2

import "core:log"
import "core:strings"

import sgfx ".deps/github.com/floooh/sokol-odin/sokol/gfx"
import stbi "vendor:stb/image"

TextureInfo :: struct {
	image:  sgfx.Image,
	width:  i32,
	height: i32,
}

TextureManager :: struct {
	textures:       [dynamic]TextureInfo,
	path_to_handle: map[string]Texture,
	next_handle:    Texture,
}

texture_manager: TextureManager

texture_init :: proc() {
	texture_manager.textures = make([dynamic]TextureInfo)
	texture_manager.path_to_handle = make(map[string]Texture)
	texture_manager.next_handle = 1
}

texture_cleanup :: proc() {
	for texture_info in texture_manager.textures {
		if texture_info.image.id != 0 {
			sgfx.destroy_image(texture_info.image)
		}
	}
	delete(texture_manager.textures)

	for path in texture_manager.path_to_handle {
		delete(path)
	}
	delete(texture_manager.path_to_handle)
}

texture_load :: proc(path: string) -> Texture {
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
	texture_manager.path_to_handle[strings.clone(path)] = handle

	return handle
}

texture_get_sokol :: proc(handle: Texture) -> sgfx.Image {
	if handle == 0 || int(handle) > len(texture_manager.textures) {
		log.warnf(
			"texture_get_sokol: invalid handle %d (max: %d)",
			handle,
			len(texture_manager.textures),
		)
		return {}
	}

	texture_info := texture_manager.textures[handle - 1]
	if texture_info.image.id == 0 {
		log.errorf("texture_get_sokol: handle %d has invalid image id (corrupted?)", handle)
		return {}
	}

	return texture_info.image
}

texture_get_size :: proc(handle: Texture) -> (width: f32, height: f32) {
	if handle == 0 || int(handle) > len(texture_manager.textures) {
		return 0, 0
	}

	texture_info := texture_manager.textures[handle - 1]
	return f32(texture_info.width), f32(texture_info.height)
}

texture_unload :: proc(handle: Texture) {
	if handle == 0 || int(handle) > len(texture_manager.textures) {
		log.warnf("texture_unload: invalid handle %d", handle)
		return
	}

	texture_info := texture_manager.textures[handle - 1]
	if texture_info.image.id != 0 {
		sgfx.destroy_image(texture_info.image)
		texture_manager.textures[handle - 1] = {} // Clear the slot
	} else {
		log.warnf("texture_unload: handle %d already destroyed or invalid", handle)
	}

	// TODO: Remove from path_to_handle map (need reverse lookup)
}
