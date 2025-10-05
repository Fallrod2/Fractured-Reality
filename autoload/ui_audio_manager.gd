extends Node

## UI Audio Manager
## Handles all UI sound effects for buttons, transitions, and interactions
## Autoload singleton for consistent audio feedback across all UI scenes

## Audio players for different UI sound categories
var button_hover_player: AudioStreamPlayer
var button_click_player: AudioStreamPlayer
var menu_open_player: AudioStreamPlayer
var menu_close_player: AudioStreamPlayer
var error_player: AudioStreamPlayer
var success_player: AudioStreamPlayer

## Volume settings (0.0 to 1.0)
var ui_volume: float = 0.7
var enabled: bool = true

## Audio streams (placeholders for when actual audio files are added)
## These should be replaced with actual audio file paths when available
var button_hover_sound: AudioStream = null
var button_click_sound: AudioStream = null
var menu_open_sound: AudioStream = null
var menu_close_sound: AudioStream = null
var error_sound: AudioStream = null
var success_sound: AudioStream = null


func _ready() -> void:
	_initialize_audio_players()
	_load_settings()
	_connect_to_all_buttons()


func _initialize_audio_players() -> void:
	"""Create audio stream players for each UI sound type"""
	button_hover_player = AudioStreamPlayer.new()
	button_hover_player.name = "ButtonHoverPlayer"
	button_hover_player.bus = "UI"
	add_child(button_hover_player)

	button_click_player = AudioStreamPlayer.new()
	button_click_player.name = "ButtonClickPlayer"
	button_click_player.bus = "UI"
	add_child(button_click_player)

	menu_open_player = AudioStreamPlayer.new()
	menu_open_player.name = "MenuOpenPlayer"
	menu_open_player.bus = "UI"
	add_child(menu_open_player)

	menu_close_player = AudioStreamPlayer.new()
	menu_close_player.name = "MenuClosePlayer"
	menu_close_player.bus = "UI"
	add_child(menu_close_player)

	error_player = AudioStreamPlayer.new()
	error_player.name = "ErrorPlayer"
	error_player.bus = "UI"
	add_child(error_player)

	success_player = AudioStreamPlayer.new()
	success_player.name = "SuccessPlayer"
	success_player.bus = "UI"
	add_child(success_player)

	_update_volume()


func _load_settings() -> void:
	"""Load audio settings from configuration"""
	# TODO: Load from settings file when available
	ui_volume = 0.7
	enabled = true


func _update_volume() -> void:
	"""Update volume for all audio players"""
	var volume_db: float = linear_to_db(ui_volume) if ui_volume > 0.0 else -80.0

	button_hover_player.volume_db = volume_db
	button_click_player.volume_db = volume_db
	menu_open_player.volume_db = volume_db
	menu_close_player.volume_db = volume_db
	error_player.volume_db = volume_db
	success_player.volume_db = volume_db


func set_ui_volume(volume: float) -> void:
	"""Set UI volume (0.0 to 1.0)"""
	ui_volume = clamp(volume, 0.0, 1.0)
	_update_volume()


func set_enabled(is_enabled: bool) -> void:
	"""Enable or disable UI audio"""
	enabled = is_enabled


## Play UI sound effects
func play_button_hover() -> void:
	"""Play button hover sound"""
	if not enabled or button_hover_sound == null:
		return
	button_hover_player.stream = button_hover_sound
	button_hover_player.play()


func play_button_click() -> void:
	"""Play button click sound"""
	if not enabled or button_click_sound == null:
		return
	button_click_player.stream = button_click_sound
	button_click_player.play()


func play_menu_open() -> void:
	"""Play menu open sound"""
	if not enabled or menu_open_sound == null:
		return
	menu_open_player.stream = menu_open_sound
	menu_open_player.play()


func play_menu_close() -> void:
	"""Play menu close sound"""
	if not enabled or menu_close_sound == null:
		return
	menu_close_player.stream = menu_close_sound
	menu_close_player.play()


func play_error() -> void:
	"""Play error sound"""
	if not enabled or error_sound == null:
		return
	error_player.stream = error_sound
	error_player.play()


func play_success() -> void:
	"""Play success sound"""
	if not enabled or success_sound == null:
		return
	success_player.stream = success_sound
	success_player.play()


func _connect_to_all_buttons() -> void:
	"""Connect to all buttons in the scene tree for automatic audio feedback"""
	# Wait for scene tree to be ready
	await get_tree().process_frame
	_connect_buttons_recursive(get_tree().root)


func _connect_buttons_recursive(node: Node) -> void:
	"""Recursively connect to all Button nodes"""
	if node is Button:
		_connect_button(node)

	for child in node.get_children():
		_connect_buttons_recursive(child)


func _connect_button(button: Button) -> void:
	"""Connect audio feedback to a button"""
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover)
	if not button.pressed.is_connected(_on_button_click):
		button.pressed.connect(_on_button_click)


func _on_button_hover() -> void:
	"""Called when button is hovered"""
	play_button_hover()


func _on_button_click() -> void:
	"""Called when button is clicked"""
	play_button_click()


## Public API for manual button connections
func connect_button_audio(button: Button) -> void:
	"""Manually connect audio feedback to a button"""
	_connect_button(button)


## NOTE: Audio files should be placed in assets/audio/ui/ directory
## Expected file names (when audio is added):
## - button_hover.wav
## - button_click.wav
## - menu_open.wav
## - menu_close.wav
## - error.wav
## - success.wav
##
## To add audio files later:
## 1. Place audio files in assets/audio/ui/
## 2. Uncomment and update the preload statements below
## 3. Assign to the respective sound variables in _ready()
##
## Example:
## button_hover_sound = preload("res://assets/audio/ui/button_hover.wav")
