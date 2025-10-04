extends CanvasLayer
## Account Login/Register screen
## Allows users to create accounts or login to existing ones

@onready var title := $CenterContainer/Panel/MarginContainer/VBoxContainer/Title
@onready var mode_label := $CenterContainer/Panel/MarginContainer/VBoxContainer/ModeLabel
@onready var username_input := $CenterContainer/Panel/MarginContainer/VBoxContainer/UsernameInput
@onready var password_input := $CenterContainer/Panel/MarginContainer/VBoxContainer/PasswordInput
@onready var error_label := $CenterContainer/Panel/MarginContainer/VBoxContainer/ErrorLabel
@onready var action_button := $CenterContainer/Panel/MarginContainer/VBoxContainer/ActionButton
@onready var toggle_mode_button := $CenterContainer/Panel/MarginContainer/VBoxContainer/ToggleModeButton
@onready var back_button := $CenterContainer/Panel/MarginContainer/VBoxContainer/BackButton

enum Mode {
	LOGIN,
	REGISTER
}

var current_mode := Mode.LOGIN


func _ready() -> void:
	# Connect signals
	action_button.pressed.connect(_on_action_pressed)
	toggle_mode_button.pressed.connect(_on_toggle_mode_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Connect account manager signals
	AccountManager.login_succeeded.connect(_on_login_succeeded)
	AccountManager.login_failed.connect(_on_login_failed)
	AccountManager.register_succeeded.connect(_on_register_succeeded)
	AccountManager.register_failed.connect(_on_register_failed)

	# Set initial mode
	_update_mode_ui()

	# Focus username input
	username_input.grab_focus()


func _update_mode_ui() -> void:
	if current_mode == Mode.LOGIN:
		title.text = "ACCOUNT LOGIN"
		mode_label.text = "Login to your account"
		action_button.text = "LOGIN"
		toggle_mode_button.text = "Don't have an account? Register"
	else:
		title.text = "CREATE ACCOUNT"
		mode_label.text = "Register a new account"
		action_button.text = "REGISTER"
		toggle_mode_button.text = "Already have an account? Login"

	error_label.text = ""


func _on_action_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text

	# Validation
	if username.is_empty() or password.is_empty():
		error_label.text = "Username and password required"
		return

	if username.length() < 3:
		error_label.text = "Username must be at least 3 characters"
		return

	if password.length() < 6:
		error_label.text = "Password must be at least 6 characters"
		return

	# Disable inputs
	_set_inputs_enabled(false)
	error_label.text = "Connecting to server..."

	if current_mode == Mode.LOGIN:
		AccountManager.login(username, password)
	else:
		AccountManager.register(username, password)


func _on_toggle_mode_pressed() -> void:
	if current_mode == Mode.LOGIN:
		current_mode = Mode.REGISTER
	else:
		current_mode = Mode.LOGIN

	_update_mode_ui()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_login_succeeded(_user: Dictionary) -> void:
	print("AccountLogin: Login successful")
	# Navigate to online lobby
	get_tree().change_scene_to_file("res://scenes/ui/online_lobby.tscn")


func _on_login_failed(error: String) -> void:
	error_label.text = "Login failed: " + error
	_set_inputs_enabled(true)


func _on_register_succeeded(_user: Dictionary) -> void:
	print("AccountLogin: Registration successful")
	# Navigate to online lobby
	get_tree().change_scene_to_file("res://scenes/ui/online_lobby.tscn")


func _on_register_failed(error: String) -> void:
	error_label.text = "Registration failed: " + error
	_set_inputs_enabled(true)


func _set_inputs_enabled(enabled: bool) -> void:
	username_input.editable = enabled
	password_input.editable = enabled
	action_button.disabled = not enabled
	toggle_mode_button.disabled = not enabled
	back_button.disabled = not enabled
