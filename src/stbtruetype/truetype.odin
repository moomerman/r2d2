package truetype

import "core:c"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"
import stbtt "vendor:stb/truetype"

// Font handle type
Font :: distinct u32

// Font atlas structure - contains baked character data and metadata
FontAtlas :: struct {
	char_info:    [95]stbtt.bakedchar, // ASCII printable characters (32-126)
	atlas_data:   []u8, // RGBA bitmap data
	atlas_width:  i32,
	atlas_height: i32,
	size:         int,
	line_height:  f32,
	path:         string,
	loaded:       bool,
}

// Font manager
FontManager :: struct {
	fonts:          [dynamic]FontAtlas,
	path_to_handle: map[string]Font,
	handle_to_path: map[Font]string,
	next_handle:    u32,
}

// Global font manager
font_manager: FontManager

// Initialize the font system
init_truetype :: proc() -> bool {
	font_manager.fonts = make([dynamic]FontAtlas)
	font_manager.path_to_handle = make(map[string]Font)
	font_manager.handle_to_path = make(map[Font]string)
	font_manager.next_handle = 1
	return true
}

// Cleanup font resources
cleanup_truetype :: proc() {
	// Free atlas data
	for &font_atlas in font_manager.fonts {
		if font_atlas.loaded && font_atlas.atlas_data != nil {
			delete(font_atlas.atlas_data)
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
load_font :: proc(path: string, size: int) -> Font {
	// Create unique key for this font+size combination
	buf: [16]byte
	size_str := strconv.itoa(buf[:], size)
	key := strings.concatenate({path, "_", size_str}, context.temp_allocator)

	// Return existing font if already loaded
	if handle, exists := font_manager.path_to_handle[key]; exists {
		log.infof("Font already loaded: %s (size: %d, handle: %d)", path, size, handle)
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
	atlas_width, atlas_height := i32(512), i32(512) // Start with reasonable size
	atlas_bitmap := make([]u8, atlas_width * atlas_height)
	defer delete(atlas_bitmap)

	// Clear bitmap
	for i in 0 ..< len(atlas_bitmap) {
		atlas_bitmap[i] = 0
	}

	// Create font atlas
	font_atlas := FontAtlas {
		atlas_width  = atlas_width,
		atlas_height = atlas_height,
		size         = size,
		path         = path,
		loaded       = false,
	}

	pixel_height := f32(size)
	result := stbtt.BakeFontBitmap(
		raw_data(font_data),
		0,
		pixel_height,
		raw_data(atlas_bitmap),
		atlas_width,
		atlas_height,
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
	for i in 0 ..< len(atlas_bitmap) {
		rgba_idx := i * 4
		alpha := atlas_bitmap[i]

		// White color with alpha for the text
		rgba_data[rgba_idx + 0] = 255 // R
		rgba_data[rgba_idx + 1] = 255 // G
		rgba_data[rgba_idx + 2] = 255 // B
		rgba_data[rgba_idx + 3] = alpha // A
	}

	font_atlas.atlas_data = rgba_data
	font_atlas.loaded = true

	// Generate handle and store
	handle := Font(font_manager.next_handle)
	font_manager.next_handle += 1

	append(&font_manager.fonts, font_atlas)

	// Store path mappings
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

// Get font atlas data for texture creation
get_font_atlas_data :: proc(handle: Font) -> (data: []u8, width: i32, height: i32, ok: bool) {
	font_atlas := get_font_atlas(handle)
	if font_atlas == nil || !font_atlas.loaded {
		return nil, 0, 0, false
	}
	return font_atlas.atlas_data, font_atlas.atlas_width, font_atlas.atlas_height, true
}

// Calculate text dimensions without rendering
get_text_size :: proc(text: string, handle: Font) -> (width: f32, height: f32) {
	font_atlas := get_font_atlas(handle)
	if font_atlas == nil {
		return 0, 0
	}

	if len(text) == 0 {
		return 0, 0
	}

	// Convert to runes for proper Unicode handling
	runes := utf8.string_to_runes(text, context.temp_allocator)
	text_width: f32 = 0
	text_height := font_atlas.line_height

	for r in runes {
		if r >= 32 && r <= 126 {
			char_index := int(r - 32)
			char_info := &font_atlas.char_info[char_index]
			text_width += char_info.xadvance
		}
	}

	return text_width, text_height
}

// Get character rendering info for a specific character
get_char_info :: proc(handle: Font, char: rune) -> (info: ^stbtt.bakedchar, ok: bool) {
	font_atlas := get_font_atlas(handle)
	if font_atlas == nil {
		return nil, false
	}

	if char >= 32 && char <= 126 {
		char_index := int(char - 32)
		return &font_atlas.char_info[char_index], true
	}

	return nil, false
}

// Get font metrics
get_font_line_height :: proc(handle: Font) -> f32 {
	font_atlas := get_font_atlas(handle)
	if font_atlas == nil {
		return 0
	}
	return font_atlas.line_height
}

// Unload a font and free its resources
unload_font :: proc(handle: Font) {
	if handle == 0 || int(handle) > len(font_manager.fonts) {
		log.warnf("unload_font: invalid handle %d", handle)
		return
	}

	font_atlas := &font_manager.fonts[handle - 1]
	if font_atlas.loaded && font_atlas.atlas_data != nil {
		delete(font_atlas.atlas_data)
		font_atlas.atlas_data = nil
		font_atlas.loaded = false
	}

	// Clean up path mappings
	if path, exists := font_manager.handle_to_path[handle]; exists {
		delete_key(&font_manager.path_to_handle, path)
		delete(path)
		delete_key(&font_manager.handle_to_path, handle)
	}
}
