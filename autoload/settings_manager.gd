extends Node
## SettingsManager - Handles game settings persistence and application
## Manages graphics, audio, controls, and gameplay settings

const SETTINGS_FILE := "user://settings.cfg"

# Default settings
const DEFAULT_SETTINGS := {
	"graphics": {
		"resolution": Vector2i(1920, 1080),
		"fullscreen": false,
		"vsync": true,
		"quality": "high",  # low, medium, high, ultra
		"max_fps": 144,
		"window_mode": 0,  # 0=windowed, 1=fullscreen, 2=borderless
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"ui_volume": 0.7,
		"muted": false,
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"key_bindings": {},  # Will be populated with default keybinds
	},
	"gameplay": {
		"show_fps": false,
		"show_ping": true,
		"screen_shake": true,
		"camera_smoothing": true,
	}
}

# Current settings
var settings := {}
var config := ConfigFile.new()

# Signals
signal settings_changed(category: String)
signal settings_loaded()

# Audio bus indices
var master_bus_idx := AudioServer.get_bus_index("Master")


func _ready() -> void:
	# Load settings or create defaults
	load_settings()
	apply_all_settings()


## Load settings from file
func load_settings() -> void:
	var error := config.load(SETTINGS_FILE)

	if error != OK:
		print("SettingsManager: No settings file found, using defaults")
		settings = DEFAULT_SETTINGS.duplicate(true)
		save_settings()
	else:
		print("SettingsManager: Loaded settings from file")
		_parse_config()

	settings_loaded.emit()


## Parse config file into settings dictionary
func _parse_config() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)

	for category in DEFAULT_SETTINGS.keys():
		for key in DEFAULT_SETTINGS[category].keys():
			var value = config.get_value(category, key, DEFAULT_SETTINGS[category][key])
			settings[category][key] = value


## Save settings to file
func save_settings() -> void:
	for category in settings.keys():
		for key in settings[category].keys():
			config.set_value(category, key, settings[category][key])

	var error := config.save(SETTINGS_FILE)

	if error != OK:
		push_error("SettingsManager: Failed to save settings: %d" % error)
	else:
		print("SettingsManager: Settings saved successfully")


## Apply all settings
func apply_all_settings() -> void:
	apply_graphics_settings()
	apply_audio_settings()
	apply_gameplay_settings()


## Apply graphics settings
func apply_graphics_settings() -> void:
	var gfx: Dictionary = settings.graphics

	# Window mode
	match gfx.window_mode:
		0:  # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:  # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:  # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# Resolution (only for windowed mode)
	if gfx.window_mode == 0:
		DisplayServer.window_set_size(gfx.resolution)
		_center_window()

	# VSync
	if gfx.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Max FPS
	Engine.max_fps = gfx.max_fps

	# Quality settings (placeholder - customize per your needs)
	_apply_quality_preset(gfx.quality)

	print("SettingsManager: Applied graphics settings")
	settings_changed.emit("graphics")


## Apply quality preset
func _apply_quality_preset(quality: String) -> void:
	match quality:
		"low":
			RenderingServer.set_default_clear_color(Color.BLACK)
			# Add low quality settings (disable shadows, reduce particles, etc.)
		"medium":
			# Medium quality settings
			pass
		"high":
			# High quality settings
			pass
		"ultra":
			# Ultra quality settings
			pass


## Apply audio settings
func apply_audio_settings() -> void:
	var audio: Dictionary = settings.audio

	# Master volume
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(audio.master_volume))
	AudioServer.set_bus_mute(master_bus_idx, audio.muted)

	# Individual bus volumes (if they exist)
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(audio.music_volume))

	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(audio.sfx_volume))

	var ui_bus := AudioServer.get_bus_index("UI")
	if ui_bus != -1:
		AudioServer.set_bus_volume_db(ui_bus, linear_to_db(audio.ui_volume))

	print("SettingsManager: Applied audio settings")
	settings_changed.emit("audio")


## Apply gameplay settings
func apply_gameplay_settings() -> void:
	# These are mostly used by other scripts via get_setting()
	print("SettingsManager: Applied gameplay settings")
	settings_changed.emit("gameplay")


## Get a specific setting
func get_setting(category: String, key: String, default_value = null):
	if category in settings and key in settings[category]:
		return settings[category][key]
	return default_value


## Set a specific setting
func set_setting(category: String, key: String, value) -> void:
	if category not in settings:
		settings[category] = {}

	settings[category][key] = value
	settings_changed.emit(category)


## Reset to defaults
func reset_to_defaults() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	save_settings()
	apply_all_settings()
	print("SettingsManager: Reset to default settings")


## Get available resolutions
func get_available_resolutions() -> Array[Vector2i]:
	return [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]


## Center window on screen
func _center_window() -> void:
	var screen_size := DisplayServer.screen_get_size()
	var window_size := DisplayServer.window_get_size()
	var centered_pos := (screen_size - window_size) / 2
	DisplayServer.window_set_position(centered_pos)
