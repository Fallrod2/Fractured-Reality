extends Control
## Main menu scene for Fractured Reality
## Handles navigation to multiplayer lobby and settings

@onready var background: ColorRect = $Background
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

# Glitch shader for background
var glitch_shader: Shader = preload("res://assets/shaders/ui_glitch.gdshader")


func _ready() -> void:
	# Ensure buttons are properly initialized
	if not host_button or not join_button or not settings_button or not quit_button:
		push_error("MainMenu: Failed to find required button nodes")
		return

	# Apply glitch shader to background
	_setup_glitch_background()

	# Setup button animations
	_setup_button_animations()

	# Setup keyboard navigation
	_setup_keyboard_navigation()


func _setup_glitch_background() -> void:
	"""Apply the glitch shader effect to the background."""
	if not background:
		push_warning("MainMenu: Background node not found")
		return

	var material := ShaderMaterial.new()
	material.shader = glitch_shader
	# Set shader parameters for subtle glitch effect
	material.set_shader_parameter("glitch_strength", 0.03)
	material.set_shader_parameter("scan_line_speed", 0.5)
	material.set_shader_parameter("scan_line_density", 600.0)
	material.set_shader_parameter("noise_amount", 0.015)
	material.set_shader_parameter("horizontal_shake", 0.005)
	material.set_shader_parameter("glitch_color", Color(0.0, 1.0, 1.0, 0.2))

	background.material = material


func _setup_button_animations() -> void:
	"""Setup hover and click animations for all buttons."""
	var buttons := [host_button, join_button, settings_button, quit_button]

	for button in buttons:
		if button:
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))
			button.button_down.connect(_on_button_pressed_anim.bind(button))
			button.button_up.connect(_on_button_released_anim.bind(button))


func _setup_keyboard_navigation() -> void:
	"""Setup keyboard/controller focus navigation."""
	# Set initial focus
	host_button.grab_focus()

	# Setup focus neighbors for vertical navigation
	host_button.focus_neighbor_bottom = join_button.get_path()
	join_button.focus_neighbor_top = host_button.get_path()
	join_button.focus_neighbor_bottom = settings_button.get_path()
	settings_button.focus_neighbor_top = join_button.get_path()
	settings_button.focus_neighbor_bottom = quit_button.get_path()
	quit_button.focus_neighbor_top = settings_button.get_path()

	# Wrap around navigation
	quit_button.focus_neighbor_bottom = host_button.get_path()
	host_button.focus_neighbor_top = quit_button.get_path()


func _on_button_hover(button: Button) -> void:
	"""Animate button on hover with scale and subtle glow."""
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)

	# Play hover sound effect
	_play_ui_sound("hover")


func _on_button_unhover(button: Button) -> void:
	"""Return button to normal scale when not hovering."""
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", Vector2.ONE, 0.2)


func _on_button_pressed_anim(button: Button) -> void:
	"""Animate button press with inward scale and glitch ripple."""
	# Scale animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)

	# Glitch ripple effect
	var glitch_material := ShaderMaterial.new()
	glitch_material.shader = glitch_shader
	glitch_material.set_shader_parameter("glitch_strength", 0.2)
	glitch_material.set_shader_parameter("scan_line_speed", 5.0)
	glitch_material.set_shader_parameter("scan_line_density", 800.0)
	glitch_material.set_shader_parameter("noise_amount", 0.1)
	glitch_material.set_shader_parameter("horizontal_shake", 0.02)
	glitch_material.set_shader_parameter("glitch_color", Color(0.0, 1.0, 1.0, 0.5))

	button.material = glitch_material

	# Remove glitch after 0.2s
	var glitch_tween := create_tween()
	glitch_tween.tween_interval(0.2)
	glitch_tween.tween_callback(func(): button.material = null)


func _on_button_released_anim(button: Button) -> void:
	"""Return button to hover scale when released."""
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.1)


func _play_ui_sound(sound_type: String) -> void:
	"""Play UI sound effect (placeholder for future audio implementation)."""
	# TODO: Implement audio system
	# Example: $AudioStreamPlayer.stream = load("res://assets/audio/ui_" + sound_type + ".ogg")
	# $AudioStreamPlayer.play()
	pass


func _on_host_button_pressed() -> void:
	print("Host button pressed")
	_play_ui_sound("click")
	# TODO: Navigate to lobby scene as host
	# get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")


func _on_join_button_pressed() -> void:
	print("Join button pressed")
	_play_ui_sound("click")
	# TODO: Navigate to lobby scene as client
	# get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")


func _on_settings_button_pressed() -> void:
	print("Settings button pressed")
	_play_ui_sound("click")
	# TODO: Navigate to settings scene
	# get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")


func _on_quit_button_pressed() -> void:
	print("Quitting game")
	_play_ui_sound("click")
	get_tree().quit()
