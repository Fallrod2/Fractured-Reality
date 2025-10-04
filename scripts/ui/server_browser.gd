extends Control
## Server Browser - Displays available game servers
## Allows filtering and sorting of servers

@onready var server_list := $MarginContainer/VBoxContainer/Content/ServerList
@onready var refresh_button := $MarginContainer/VBoxContainer/Header/RefreshButton
@onready var sort_option := $MarginContainer/VBoxContainer/Header/SortOption
@onready var filter_input := $MarginContainer/VBoxContainer/Header/FilterInput
@onready var back_button := $MarginContainer/VBoxContainer/Footer/BackButton
@onready var direct_connect_button := $MarginContainer/VBoxContainer/Footer/DirectConnectButton

# Server entry scene
const SERVER_ENTRY := preload("res://scenes/ui/server_entry.tscn")

# Server list data
var servers := []
var selected_server: Dictionary = {}

# Sort modes
enum SortMode {
	NAME,
	PLAYERS,
	PING,
}
var current_sort := SortMode.PLAYERS


func _ready() -> void:
	# Connect signals
	refresh_button.pressed.connect(_on_refresh_pressed)
	sort_option.item_selected.connect(_on_sort_changed)
	filter_input.text_changed.connect(_on_filter_changed)
	back_button.pressed.connect(_on_back_pressed)
	direct_connect_button.pressed.connect(_on_direct_connect_pressed)

	# Populate sort dropdown
	sort_option.add_item("Players (High to Low)")
	sort_option.add_item("Name (A-Z)")
	sort_option.add_item("Ping (Low to High)")
	sort_option.selected = 0

	# Initial refresh
	_refresh_servers()


func _refresh_servers() -> void:
	"""Refresh the server list."""
	print("ServerBrowser: Refreshing servers...")

	# Clear existing list
	for child in server_list.get_children():
		child.queue_free()

	# TODO: Implement actual server discovery
	# For now, add localhost as a test server
	servers = _discover_servers()

	# Sort servers
	_sort_servers()

	# Display servers
	_display_servers()


func _discover_servers() -> Array:
	"""Discover available servers on the network."""
	# TODO: Implement actual server discovery via broadcast/LAN
	# For now, return localhost test server
	return [
		{
			"name": "Localhost Test Server",
			"host": "127.0.0.1",
			"port": NetworkManager.DEFAULT_PORT,
			"players": 1,
			"max_players": NetworkManager.MAX_PLAYERS,
			"ping": 5,
		}
	]


func _sort_servers() -> void:
	"""Sort servers based on current sort mode."""
	match current_sort:
		SortMode.NAME:
			servers.sort_custom(func(a, b): return a.name < b.name)
		SortMode.PLAYERS:
			servers.sort_custom(func(a, b): return a.players > b.players)
		SortMode.PING:
			servers.sort_custom(func(a, b): return a.ping < b.ping)


func _display_servers() -> void:
	"""Display servers in the list."""
	var filter_text: String = filter_input.text.to_lower()

	for server_data in servers:
		# Apply filter
		if filter_text != "" and not server_data.name.to_lower().contains(filter_text):
			continue

		# Create server entry
		var entry := SERVER_ENTRY.instantiate()
		entry.setup(server_data)
		entry.join_requested.connect(_on_server_join_requested.bind(server_data))
		server_list.add_child(entry)

	# Show message if no servers found
	if server_list.get_child_count() == 0:
		var label := Label.new()
		label.text = "No servers found. Click Refresh to search again."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		server_list.add_child(label)


func _on_refresh_pressed() -> void:
	print("ServerBrowser: Manual refresh")
	_refresh_servers()


func _on_sort_changed(index: int) -> void:
	current_sort = index as SortMode
	_sort_servers()
	_display_servers()


func _on_filter_changed(_new_text: String) -> void:
	_display_servers()


func _on_server_join_requested(server_data: Dictionary) -> void:
	"""Join the selected server."""
	print("ServerBrowser: Joining server %s at %s:%d" % [server_data.name, server_data.host, server_data.port])

	var error := NetworkManager.join_server(server_data.host, server_data.port)
	if error != OK:
		push_error("Failed to join server")
		return

	# Navigate to lobby as client
	var lobby_scene: PackedScene = load("res://scenes/ui/lobby.tscn")
	var lobby: Control = lobby_scene.instantiate()
	get_tree().root.add_child(lobby)
	lobby.setup_as_client(server_data.host, server_data.port)
	queue_free()


func _on_back_pressed() -> void:
	print("ServerBrowser: Back to main menu")

	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_direct_connect_pressed() -> void:
	"""Open direct connect dialog."""
	# TODO: Implement direct connect dialog with IP input
	print("ServerBrowser: Direct connect not yet implemented")
	# For now, just connect to localhost
	_on_server_join_requested({
		"name": "Direct Connect",
		"host": "127.0.0.1",
		"port": NetworkManager.DEFAULT_PORT,
	})
