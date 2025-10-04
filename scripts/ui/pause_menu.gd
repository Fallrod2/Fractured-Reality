extends Control
## Pause Menu - In-game pause overlay
## Handles pausing, resuming, settings, and quitting

@onready var resume_button := $Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var options_button := $Panel/MarginContainer/VBoxContainer/OptionsButton
@onready var quit_button := $Panel/MarginContainer/VBoxContainer/QuitButton

const OPTIONS_MENU := preload("res://scenes/ui/options_menu.tscn")

var is_paused := false


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	show()
	resume_button.grab_focus()
	print("PauseMenu: Game paused")


func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	hide()
	print("PauseMenu: Game resumed")


func _on_resume_pressed() -> void:
	resume_game()


func _on_options_pressed() -> void:
	var options_menu := OPTIONS_MENU.instantiate()
	get_tree().root.add_child(options_menu)

	# Hide pause menu while in options
	hide()

	# Wait for options menu to close
	await options_menu.tree_exited

	# Show pause menu again if still paused
	if is_paused:
		show()
		resume_button.grab_focus()


func _on_quit_pressed() -> void:
	print("PauseMenu: Quitting to main menu")

	# Unpause first
	get_tree().paused = false

	# Disconnect from multiplayer if connected
	if NetworkManager.is_hosting or NetworkManager.server_ip != "":
		NetworkManager.disconnect_from_server()

	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
