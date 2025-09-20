package audio

import "core:log"
import "core:strings"
import "vendor:miniaudio"

AudioManager :: struct {
	engine:      miniaudio.engine,
	initialized: bool,
}

audio_manager: AudioManager

init_audio :: proc() -> bool {
	result := miniaudio.engine_init(nil, &audio_manager.engine)
	if result != .SUCCESS {
		log.errorf("Failed to initialize audio engine: %v", result)
		return false
	}

	audio_manager.initialized = true
	return true
}

cleanup_audio :: proc() {
	if !audio_manager.initialized do return

	miniaudio.engine_uninit(&audio_manager.engine)
	audio_manager.initialized = false

	log.info("Audio system cleaned up")
}

play_sound_file :: proc(path: string) -> bool {
	if !audio_manager.initialized {
		log.error("Audio system not initialized")
		return false
	}

	cpath := strings.clone_to_cstring(path, context.temp_allocator)

	result := miniaudio.engine_play_sound(&audio_manager.engine, cpath, nil)
	if result != .SUCCESS {
		log.errorf("Failed to play sound file '%s': %v", path, result)
		return false
	}

	return true
}

set_master_volume :: proc(volume: f32) -> bool {
	if !audio_manager.initialized do return false

	clamped_volume := clamp(volume, 0.0, 1.0)
	miniaudio.engine_set_volume(&audio_manager.engine, clamped_volume)
	return true
}

clamp :: proc(value, min_val, max_val: f32) -> f32 {
	if value < min_val do return min_val
	if value > max_val do return max_val
	return value
}
