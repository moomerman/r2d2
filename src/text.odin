package r2d2

import backend "./sokol"
import truetype "./stbtruetype"
import "core:log"
import "core:unicode/utf8"

TextSystem :: struct {
	initialized: bool,
}

text_system: TextSystem

FontTextureMapping :: struct {
	font_handle:    truetype.Font,
	texture_handle: Texture,
}

font_textures: [dynamic]FontTextureMapping

init_text :: proc() -> bool {
	if !truetype.init_truetype() {
		log.error("Failed to initialize truetype system")
		return false
	}

	font_textures = make([dynamic]FontTextureMapping)
	text_system.initialized = true
	log.info("Text system initialized")
	return true
}

cleanup_text :: proc() {
	if !text_system.initialized do return

	// Cleanup font textures
	for mapping in font_textures {
		backend.unload_texture(u32(mapping.texture_handle))
	}
	delete(font_textures)

	truetype.cleanup_truetype()
	text_system.initialized = false
	log.info("Text system cleaned up")
}

// Load font and create texture
text_load_font :: proc(path: string, size: int) -> Font {
	if !text_system.initialized {
		log.error("Text system not initialized")
		return Font(0)
	}

	// Load font through truetype system
	font_handle := truetype.load_font(path, size)
	if font_handle == 0 {
		return Font(0)
	}

	// Get atlas data from truetype system
	atlas_data, width, height, ok := truetype.get_font_atlas_data(font_handle)
	if !ok {
		log.errorf("Failed to get atlas data for font: %s", path)
		truetype.unload_font(font_handle)
		return Font(0)
	}

	// Create texture in backend
	texture_handle := backend.create_texture_from_data(raw_data(atlas_data), width, height)

	if texture_handle == 0 {
		log.errorf("Failed to create font atlas texture for: %s", path)
		truetype.unload_font(font_handle)
		return Font(0)
	}

	mapping := FontTextureMapping {
		font_handle    = font_handle,
		texture_handle = Texture(texture_handle),
	}
	append(&font_textures, mapping)

	log.infof(
		"Created font texture for: %s (font: %d, texture: %d)",
		path,
		font_handle,
		texture_handle,
	)
	return Font(font_handle)
}

text_unload_font :: proc(font: Font) {
	if !text_system.initialized do return
	if font == 0 do return

	font_handle := truetype.Font(font)

	for mapping, i in font_textures {
		if mapping.font_handle == font_handle {
			backend.unload_texture(u32(mapping.texture_handle))
			ordered_remove(&font_textures, i)
			break
		}
	}

	truetype.unload_font(font_handle)
}

get_font_texture :: proc(font: Font) -> Texture {
	if !text_system.initialized do return Texture(0)
	if font == 0 do return Texture(0)

	font_handle := truetype.Font(font)

	// Find texture mapping
	for mapping in font_textures {
		if mapping.font_handle == font_handle {
			return mapping.texture_handle
		}
	}

	return Texture(0)
}

text_get_text_size :: proc(text: string, font: Font) -> Vec2 {
	if !text_system.initialized do return {0, 0}
	if font == 0 do return {0, 0}

	font_handle := truetype.Font(font)
	width, height := truetype.get_text_size(text, font_handle)
	return Vec2{width, height}
}

text_draw_text :: proc(text: string, font: Font, position: Vec2, color: Color) {
	if !text_system.initialized do return
	if font == 0 {
		log.warn("draw_text: invalid font handle: 0")
		return
	}
	if len(text) == 0 do return

	font_handle := truetype.Font(font)
	texture := get_font_texture(font)
	if texture == 0 {
		log.warnf("draw_text: no texture found for font handle: %d", font)
		return
	}

	// Convert to runes for proper Unicode handling
	runes := utf8.string_to_runes(text, context.temp_allocator)

	x_offset := position.x
	y_offset := position.y

	for r in runes {
		if r >= 32 && r <= 126 {
			char_info, ok := truetype.get_char_info(font_handle, r)
			if !ok do continue

			// Only draw if character has visible pixels
			if char_info.x1 > char_info.x0 && char_info.y1 > char_info.y0 {
				// Source rectangle in the font atlas (pixel coordinates)
				src := Rect {
					x = f32(char_info.x0),
					y = f32(char_info.y0),
					w = f32(char_info.x1 - char_info.x0),
					h = f32(char_info.y1 - char_info.y0),
				}

				// Destination rectangle on screen
				dest := Rect {
					x = x_offset + char_info.xoff,
					y = y_offset + char_info.yoff,
					w = f32(char_info.x1 - char_info.x0),
					h = f32(char_info.y1 - char_info.y0),
				}

				// Draw the character using existing sprite system
				backend.draw_sprite(
					u32(texture),
					backend.Rect(src),
					backend.Rect(dest),
					backend.Color(color),
				)
			}

			// Advance to next character position
			x_offset += char_info.xadvance
		}
	}
}
