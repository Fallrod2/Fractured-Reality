extends Control
## Multiplayer Lobby for Fractured Reality
## Shows connected players and allows host to start the game

@onready var server_info: Label = $VBoxContainer/ServerInfo
@onready var player_list_label: Label = $VBoxContainer/PlayerListLabel
@onready var player_list: VBoxContainer = $VBoxContainer/PlayerListContainer/PlayerList
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var connection_status: Label = $ConnectionStatus

# Is this player the host?
var is_host := false


func _ready() -> void:
	# Connect to NetworkManager signals
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.game_started.connect(_on_game_started)

	# Update UI based on current state
	_update_lobby_ui()


func setup_as_host(port: int) -> void:
	"""Setup lobby as host."""
	is_host = true
	server_info.text = "Hosting on port %d" % port
	connection_status.text = "Status: Hosting - Waiting for players..."
	start_button.disabled = not NetworkManager.can_start_game()
	_update_player_list()


func setup_as_client(ip: String, port: int) -> void:
	"""Setup lobby as client."""
	is_host = false
	server_info.text = "Connecting to %s:%d..." % [ip, port]
	connection_status.text = "Status: Connecting..."
	start_button.disabled = true
	start_button.text = "Waiting for Host to Start"


func _update_lobby_ui() -> void:
	"""Update the lobby UI with current player count and state."""
	_update_player_list()

	if is_host:
		var can_start := NetworkManager.can_start_game()
		start_button.disabled = not can_start

		if can_start:
			start_button.text = "Start Game"
		else:
			var player_count := NetworkManager.get_player_count()
			if player_count < 2:
				start_button.text = "Start Game (Need 2+ Players)"
			else:
				start_button.text = "Start Game (%d/%d Players)" % [player_count, NetworkManager.MAX_PLAYERS]


func _update_player_list() -> void:
	"""Update the player list display."""
	# Clear existing list
	for child in player_list.get_children():
		child.queue_free()

	# Get all players
	var players := NetworkManager.get_all_players()
	var player_count := players.size()

	# Update header
	player_list_label.text = "CONNECTED PLAYERS (%d/%d)" % [player_count, NetworkManager.MAX_PLAYERS]

	# Add player entries
	for player_id in players.keys():
		var player_data: Dictionary = players[player_id]
		var player_entry := _create_player_entry(player_id, player_data)
		player_list.add_child(player_entry)

	# Update connection status
	if is_host:
		connection_status.text = "Status: Hosting - %d player(s) connected" % player_count
	else:
		connection_status.text = "Status: Connected - %d player(s) in lobby" % player_count


func _create_player_entry(player_id: int, player_data: Dictionary) -> PanelContainer:
	"""Create a visual entry for a player in the list."""
	var panel := PanelContainer.new()
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.498039, 0, 1, 0.2)
	style_box.border_color = Color(0, 1, 1, 0.5)
	style_box.set_border_width_all(1)
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style_box)

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	# Player name
	var name_label := Label.new()
	var player_name: String = player_data.get("name", "Unknown")

	# Add (You) or (Host) indicator
	if player_id == NetworkManager.local_player_id:
		name_label.text = "%s (You)" % player_name
		name_label.add_theme_color_override("font_color", Color(0, 1, 1, 1))  # Neon Cyan
	elif player_id == 1:
		name_label.text = "%s (Host)" % player_name
		name_label.add_theme_color_override("font_color", Color(0.498039, 0, 1, 1))  # Electric Purple
	else:
		name_label.text = player_name

	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	# Player ID
	var id_label := Label.new()
	id_label.text = "#%d" % player_id
	id_label.add_theme_color_override("font_color", Color(0.666667, 0.666667, 0.666667, 0.7))
	hbox.add_child(id_label)

	return panel


## Signal handlers

func _on_player_connected(_player_id: int, _player_data: Dictionary) -> void:
	print("Lobby: Player connected")
	_update_lobby_ui()


func _on_player_disconnected(_player_id: int) -> void:
	print("Lobby: Player disconnected")
	_update_lobby_ui()


func _on_connection_succeeded() -> void:
	print("Lobby: Connection succeeded")
	connection_status.text = "Status: Connected to server"
	_update_lobby_ui()


func _on_connection_failed() -> void:
	print("Lobby: Connection failed")
	connection_status.text = "Status: Connection Failed!"
	connection_status.add_theme_color_override("font_color", Color(1, 0.25, 0.25, 1))  # Red


func _on_game_started() -> void:
	print("Lobby: Game starting!")


## Button handlers

func _on_start_button_pressed() -> void:
	if is_host and NetworkManager.can_start_game():
		print("Lobby: Host starting game")
		NetworkManager.start_game()


func _on_back_button_pressed() -> void:
	print("Lobby: Returning to main menu")
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
