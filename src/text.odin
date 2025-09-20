#+private
package r2d2

import "core:c"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

import backend "./sokol"
import stbtt "vendor:stb/truetype"

// Font atlas structure - contains a texture with baked character data
FontAtlas :: struct {
	texture:     Texture,
	char_info:   [95]stbtt.bakedchar, // ASCII printable characters (32-126)
	size:        int,
	line_height: f32,
}

// Font manager similar to your texture manager pattern
FontManager :: struct {
	fonts:          [dynamic]FontAtlas,
	path_to_handle: map[string]Font,
	handle_to_path: map[Font]string,
	next_handle:    u32,
}

// Global font manager
font_manager: FontManager

// Initialize the font system
init_fonts :: proc() {
	font_manager.fonts = make([dynamic]FontAtlas)
	font_manager.path_to_handle = make(map[string]Font)
	font_manager.handle_to_path = make(map[Font]string)
	font_manager.next_handle = 1
}

// Clean up font resources
cleanup_fonts :: proc() {
	// Unload all font textures
	for font_atlas in font_manager.fonts {
		if font_atlas.texture != 0 {
			unload_texture(font_atlas.texture)
		}
	}
	delete(font_manager.fonts)

	// Clean up path strings
	for _, path in font_manager.handle_to_path {
		delete(path)
	}
	delete(font_manager.path_to_handle)
	delete(font_manager.handle_to_path)
}

// Load a font at a specific size - creates a bitmap font atlas
text_load_font :: proc(path: string, size: int) -> Font {
	// Create unique key for this font+size combination
	buf: [16]byte
	size_str := strconv.itoa(buf[:], size)
	key := strings.concatenate({path, "_", size_str}, context.temp_allocator)

	// Return existing font if already loaded
	if handle, exists := font_manager.path_to_handle[key]; exists {
		return handle
	}

	// Load font file
	font_data, ok := os.read_entire_file(path)
	if !ok {
		log.errorf("Failed to load font file: %s", path)
		return Font(0)
	}
	defer delete(font_data)

	// Initialize stb_truetype font info
	font_info: stbtt.fontinfo
	if !stbtt.InitFont(&font_info, raw_data(font_data), 0) {
		log.errorf("Failed to initialize font: %s", path)
		return Font(0)
	}

	// Create bitmap atlas for ASCII printable characters (32-126)
	atlas_width, atlas_height := 512, 512 // Start with reasonable size
	atlas_bitmap := make([]u8, atlas_width * atlas_height)
	defer delete(atlas_bitmap)

	// Clear bitmap
	for i in 0 ..< len(atlas_bitmap) {
		atlas_bitmap[i] = 0
	}

	// Bake characters into the atlas
	font_atlas := FontAtlas {
		size = size,
	}

	pixel_height := f32(size)
	result := stbtt.BakeFontBitmap(
		raw_data(font_data),
		0,
		pixel_height,
		raw_data(atlas_bitmap),
		c.int(atlas_width),
		c.int(atlas_height),
		32, // First character (space)
		95, // Number of characters
		raw_data(font_atlas.char_info[:]),
	)

	if result <= 0 {
		log.errorf("Failed to bake font bitmap for: %s", path)
		return Font(0)
	}


	// Calculate line height
	ascent, descent, line_gap: c.int
	stbtt.GetFontVMetrics(&font_info, &ascent, &descent, &line_gap)
	scale := stbtt.ScaleForPixelHeight(&font_info, pixel_height)
	font_atlas.line_height = f32(ascent - descent + line_gap) * scale

	// Convert grayscale bitmap to RGBA for texture creation
	rgba_data := make([]u8, atlas_width * atlas_height * 4)
	defer delete(rgba_data)

	for i in 0 ..< len(atlas_bitmap) {
		rgba_idx := i * 4
		alpha := atlas_bitmap[i]

		// White color with alpha for the text
		rgba_data[rgba_idx + 0] = 255 // R
		rgba_data[rgba_idx + 1] = 255 // G
		rgba_data[rgba_idx + 2] = 255 // B
		rgba_data[rgba_idx + 3] = alpha // A
	}

	// Create texture from the atlas
	texture_handle := backend.create_texture_from_data(
		raw_data(rgba_data),
		c.int(atlas_width),
		c.int(atlas_height),
	)

	if texture_handle == 0 {
		log.errorf("Failed to create font atlas texture for: %s", path)
		return Font(0)
	}

	font_atlas.texture = Texture(texture_handle)

	// Store the font
	handle := Font(font_manager.next_handle)
	font_manager.next_handle += 1

	append(&font_manager.fonts, font_atlas)

	key_copy := strings.clone(key)
	font_manager.path_to_handle[key_copy] = handle
	font_manager.handle_to_path[handle] = key_copy

	log.infof("Loaded font: %s (size: %d, handle: %d)", path, size, handle)
	return handle
}

// Get font atlas from handle
get_font_atlas :: proc(handle: Font) -> ^FontAtlas {
	if handle == 0 || int(handle) > len(font_manager.fonts) {
		log.warnf("get_font_atlas: invalid handle %d", handle)
		return nil
	}
	return &font_manager.fonts[handle - 1]
}

text_get_size :: proc(text: string, font: Font) -> [2]f32 {
	font_atlas := get_font_atlas(font)
	if font_atlas == nil {
		return {0, 0}
	}

	if len(text) == 0 {
		return {0, 0}
	}

	// Convert to runes for proper Unicode handling
	runes := utf8.string_to_runes(text, context.temp_allocator)
	width: f32 = 0
	height := font_atlas.line_height

	for r in runes {
		if r >= 32 && r <= 126 {
			char_index := int(r - 32)
			char_info := &font_atlas.char_info[char_index]
			width += char_info.xadvance
		}
	}

	return {width, height}
}

text_draw :: proc(text: string, font: Font, position: [2]f32, color: Color) {
	font_atlas := get_font_atlas(font)
	if font_atlas == nil {
		log.warnf("draw_text: invalid font handle: %d", font)
		return
	}

	if len(text) == 0 {
		return
	}

	// Convert to runes for proper Unicode handling
	runes := utf8.string_to_runes(text, context.temp_allocator)

	x_offset := position.x
	y_offset := position.y

	for r in runes {
		if r >= 32 && r <= 126 {
			char_index := int(r - 32)
			char_info := &font_atlas.char_info[char_index]

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
				draw_texture(font_atlas.texture, src, dest, color)
			}

			// Advance to next character position
			x_offset += char_info.xadvance
		}
	}
}

// Unload a font and free its resources
text_unload_font :: proc(handle: Font) {
	if handle == 0 || int(handle) > len(font_manager.fonts) {
		log.warnf("unload_font: invalid handle %d", handle)
		return
	}

	font_atlas := &font_manager.fonts[handle - 1]
	if font_atlas.texture != 0 {
		unload_texture(font_atlas.texture)
		font_atlas.texture = 0
	}

	// Clean up path mapping
	if path, exists := font_manager.handle_to_path[handle]; exists {
		delete_key(&font_manager.path_to_handle, path)
		delete(path)
		delete_key(&font_manager.handle_to_path, handle)
	}
}
