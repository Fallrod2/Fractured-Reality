extends Control
## Options Menu - Comprehensive settings interface
## Handles Graphics, Audio, Controls, and Gameplay settings

# Tab nodes
@onready var tabs := $MarginContainer/VBoxContainer/Content/TabContainer
@onready var graphics_tab := $MarginContainer/VBoxContainer/Content/TabContainer/Graphics
@onready var audio_tab := $MarginContainer/VBoxContainer/Content/TabContainer/Audio
@onready var controls_tab := $MarginContainer/VBoxContainer/Content/TabContainer/Controls
@onready var gameplay_tab := $MarginContainer/VBoxContainer/Content/TabContainer/Gameplay

# Graphics controls
@onready var resolution_option := $MarginContainer/VBoxContainer/Content/TabContainer/Graphics/Settings/ResolutionOption
@onready var window_mode_option := $MarginContainer/VBoxContainer/Content/TabContainer/Graphics/Settings/WindowModeOption
@onready var vsync_check := $MarginContainer/VBoxContainer/Content/TabContainer/Graphics/Settings/VsyncCheck
@onready var quality_option := $MarginContainer/VBoxContainer/Content/TabContainer/Graphics/Settings/QualityOption
@onready var max_fps_slider := $MarginContainer/VBoxContainer/Content/TabContainer/Graphics/Settings/MaxFpsSlider

# Audio controls
@onready var master_slider := $MarginContainer/VBoxContainer/Content/TabContainer/Audio/Settings/MasterSlider
@onready var music_slider := $MarginContainer/VBoxContainer/Content/TabContainer/Audio/Settings/MusicSlider
@onready var sfx_slider := $MarginContainer/VBoxContainer/Content/TabContainer/Audio/Settings/SfxSlider
@onready var ui_slider := $MarginContainer/VBoxContainer/Content/TabContainer/Audio/Settings/UiSlider
@onready var mute_check := $MarginContainer/VBoxContainer/Content/TabContainer/Audio/Settings/MuteCheck

# Gameplay controls
@onready var show_fps_check := $MarginContainer/VBoxContainer/Content/TabContainer/Gameplay/Settings/ShowFpsCheck
@onready var show_ping_check := $MarginContainer/VBoxContainer/Content/TabContainer/Gameplay/Settings/ShowPingCheck
@onready var screen_shake_check := $MarginContainer/VBoxContainer/Content/TabContainer/Gameplay/Settings/ScreenShakeCheck

# Buttons
@onready var apply_button := $MarginContainer/VBoxContainer/Buttons/ApplyButton
@onready var reset_button := $MarginContainer/VBoxContainer/Buttons/ResetButton
@onready var back_button := $MarginContainer/VBoxContainer/Buttons/BackButton

var resolutions: Array[Vector2i] = []
var pending_changes := false


func _ready() -> void:
	# Get available resolutions
	resolutions = SettingsManager.get_available_resolutions()

	# Populate resolution dropdown
	for res in resolutions:
		resolution_option.add_item("%d x %d" % [res.x, res.y])

	# Populate window mode dropdown
	window_mode_option.add_item("Windowed")
	window_mode_option.add_item("Fullscreen")
	window_mode_option.add_item("Borderless")

	# Populate quality dropdown
	quality_option.add_item("Low")
	quality_option.add_item("Medium")
	quality_option.add_item("High")
	quality_option.add_item("Ultra")

	# Load current settings
	_load_current_settings()

	# Connect signals
	_connect_signals()

	# Initial apply button state
	apply_button.disabled = true


func _connect_signals() -> void:
	# Graphics
	resolution_option.item_selected.connect(_on_setting_changed)
	window_mode_option.item_selected.connect(_on_setting_changed)
	vsync_check.toggled.connect(_on_setting_changed)
	quality_option.item_selected.connect(_on_setting_changed)
	max_fps_slider.value_changed.connect(_on_setting_changed)

	# Audio
	master_slider.value_changed.connect(_on_setting_changed)
	music_slider.value_changed.connect(_on_setting_changed)
	sfx_slider.value_changed.connect(_on_setting_changed)
	ui_slider.value_changed.connect(_on_setting_changed)
	mute_check.toggled.connect(_on_setting_changed)

	# Gameplay
	show_fps_check.toggled.connect(_on_setting_changed)
	show_ping_check.toggled.connect(_on_setting_changed)
	screen_shake_check.toggled.connect(_on_setting_changed)

	# Buttons
	apply_button.pressed.connect(_on_apply_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _load_current_settings() -> void:
	var gfx: Dictionary = SettingsManager.settings.graphics
	var audio: Dictionary = SettingsManager.settings.audio
	var gameplay: Dictionary = SettingsManager.settings.gameplay

	# Graphics
	var current_res: Vector2i = gfx.resolution
	for i in resolutions.size():
		if resolutions[i] == current_res:
			resolution_option.selected = i
			break

	window_mode_option.selected = gfx.window_mode
	vsync_check.button_pressed = gfx.vsync

	match gfx.quality:
		"low": quality_option.selected = 0
		"medium": quality_option.selected = 1
		"high": quality_option.selected = 2
		"ultra": quality_option.selected = 3

	max_fps_slider.value = gfx.max_fps

	# Audio
	master_slider.value = audio.master_volume
	music_slider.value = audio.music_volume
	sfx_slider.value = audio.sfx_volume
	ui_slider.value = audio.ui_volume
	mute_check.button_pressed = audio.muted

	# Gameplay
	show_fps_check.button_pressed = gameplay.show_fps
	show_ping_check.button_pressed = gameplay.show_ping
	screen_shake_check.button_pressed = gameplay.screen_shake


func _on_setting_changed(_value = null) -> void:
	pending_changes = true
	apply_button.disabled = false


func _on_apply_pressed() -> void:
	_apply_settings()
	SettingsManager.save_settings()
	pending_changes = false
	apply_button.disabled = true
	print("OptionsMenu: Settings applied and saved")


func _apply_settings() -> void:
	# Graphics
	var selected_res_idx: int = resolution_option.selected
	SettingsManager.set_setting("graphics", "resolution", resolutions[selected_res_idx])
	SettingsManager.set_setting("graphics", "window_mode", window_mode_option.selected)
	SettingsManager.set_setting("graphics", "vsync", vsync_check.button_pressed)

	var quality_names := ["low", "medium", "high", "ultra"]
	SettingsManager.set_setting("graphics", "quality", quality_names[quality_option.selected])
	SettingsManager.set_setting("graphics", "max_fps", int(max_fps_slider.value))

	# Audio
	SettingsManager.set_setting("audio", "master_volume", master_slider.value)
	SettingsManager.set_setting("audio", "music_volume", music_slider.value)
	SettingsManager.set_setting("audio", "sfx_volume", sfx_slider.value)
	SettingsManager.set_setting("audio", "ui_volume", ui_slider.value)
	SettingsManager.set_setting("audio", "muted", mute_check.button_pressed)

	# Gameplay
	SettingsManager.set_setting("gameplay", "show_fps", show_fps_check.button_pressed)
	SettingsManager.set_setting("gameplay", "show_ping", show_ping_check.button_pressed)
	SettingsManager.set_setting("gameplay", "screen_shake", screen_shake_check.button_pressed)

	# Apply all settings
	SettingsManager.apply_all_settings()


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_load_current_settings()
	pending_changes = false
	apply_button.disabled = true


func _on_back_pressed() -> void:
	if pending_changes:
		# TODO: Show confirmation dialog
		print("OptionsMenu: Discarding unsaved changes")

	queue_free()
