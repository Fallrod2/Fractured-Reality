extends Node
## NetworkManager - Handles all multiplayer synchronization for Fractured Reality
## READ THIS FIRST before modifying any multiplayer code!
## Uses Godot High-Level Multiplayer API with ENetMultiplayerPeer

# Network configuration
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 5
const MAX_REPAIRERS := 4

# Player data structure
var players := {}  # Dictionary of player_id -> player_data
var local_player_id := 1

# Server state
var is_hosting := false
var server_ip := ""
var server_port := DEFAULT_PORT

# Signals
signal player_connected(player_id: int, player_data: Dictionary)
signal player_disconnected(player_id: int)
signal server_created()
signal server_join_failed(error: String)
signal connection_succeeded()
signal connection_failed()
signal game_started()


func _ready() -> void:
	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Create a server/host
func create_server(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS)

	if error != OK:
		push_error("NetworkManager: Failed to create server on port %d" % port)
		return error

	multiplayer.multiplayer_peer = peer
	is_hosting = true
	server_port = port

	# Add local player (host)
	local_player_id = multiplayer.get_unique_id()
	_add_player(local_player_id, _create_player_data("Host"))

	print("NetworkManager: Server created on port %d" % port)
	server_created.emit()
	return OK


## Join a server as client
func join_server(ip: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, port)

	if error != OK:
		push_error("NetworkManager: Failed to connect to %s:%d" % [ip, port])
		server_join_failed.emit("Failed to connect to server")
		return error

	multiplayer.multiplayer_peer = peer
	server_ip = ip
	server_port = port

	print("NetworkManager: Attempting to connect to %s:%d" % [ip, port])
	return OK


## Disconnect from current multiplayer session
func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	players.clear()
	is_hosting = false
	server_ip = ""
	print("NetworkManager: Disconnected from server")


## Get player data by ID
func get_player_data(player_id: int) -> Dictionary:
	return players.get(player_id, {})


## Get all connected players
func get_all_players() -> Dictionary:
	return players.duplicate()


## Get number of connected players
func get_player_count() -> int:
	return players.size()


## Check if we can start the game (have enough players)
func can_start_game() -> bool:
	return is_hosting and players.size() >= 2 and players.size() <= MAX_PLAYERS


## Start the game (host only)
func start_game() -> void:
	if not is_hosting:
		push_warning("NetworkManager: Only host can start the game")
		return

	if not can_start_game():
		push_warning("NetworkManager: Cannot start game - need 2-5 players")
		return

	# Assign roles (1 Corruptor, rest Repairers)
	_assign_roles()

	# Notify all clients to start with updated player data
	_rpc_start_game.rpc(players)

	# Load game scene
	get_tree().change_scene_to_file("res://scenes/levels/test_level.tscn")
	game_started.emit()


## Create player data structure
func _create_player_data(player_name: String) -> Dictionary:
	return {
		"name": player_name,
		"is_corruptor": false,
		"ready": false,
	}


## Add a player to the session
func _add_player(player_id: int, player_data: Dictionary) -> void:
	players[player_id] = player_data
	player_connected.emit(player_id, player_data)
	print("NetworkManager: Player %d (%s) joined" % [player_id, player_data.name])


## Remove a player from the session
func _remove_player(player_id: int) -> void:
	if player_id in players:
		var player_name: String = players[player_id].get("name", "Unknown")
		players.erase(player_id)
		player_disconnected.emit(player_id)
		print("NetworkManager: Player %d (%s) left" % [player_id, player_name])


## Assign roles to players (1 Corruptor, rest Repairers)
func _assign_roles() -> void:
	var player_ids := players.keys()

	if player_ids.is_empty():
		return

	# Randomly select one player as Corruptor
	var corruptor_id: int = player_ids[randi() % player_ids.size()]

	for player_id in player_ids:
		players[player_id].is_corruptor = (player_id == corruptor_id)

	print("NetworkManager: Roles assigned - Corruptor: %d" % corruptor_id)


## Signal handlers

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer %d connected" % id)

	# If we're the server, request player info from new peer
	if multiplayer.is_server():
		_rpc_request_player_info.rpc_id(id)


func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer %d disconnected" % id)
	_remove_player(id)


func _on_connected_to_server() -> void:
	print("NetworkManager: Successfully connected to server")
	local_player_id = multiplayer.get_unique_id()

	# Add ourselves to local players list
	var player_name := "Player_%d" % local_player_id
	_add_player(local_player_id, _create_player_data(player_name))

	# Send our player info to the server
	_rpc_register_player.rpc_id(1, local_player_id, player_name)

	connection_succeeded.emit()


func _on_connection_failed() -> void:
	print("NetworkManager: Failed to connect to server")
	connection_failed.emit()
	server_join_failed.emit("Connection failed")


func _on_server_disconnected() -> void:
	print("NetworkManager: Disconnected from server")
	disconnect_from_server()
	# TODO: Show disconnection screen
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## RPCs

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_player_info() -> void:
	# Client sends their info to server
	if not multiplayer.is_server():
		var player_name := "Player_%d" % multiplayer.get_unique_id()
		_rpc_register_player.rpc_id(1, multiplayer.get_unique_id(), player_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_register_player(player_id: int, player_name: String) -> void:
	# Server receives player registration
	if multiplayer.is_server():
		# Don't add ourselves twice (host is already added in create_server)
		if player_id != 1:
			_add_player(player_id, _create_player_data(player_name))

		# Send all existing players to the new player
		for pid in players.keys():
			var pdata: Dictionary = players[pid]
			_rpc_add_player.rpc_id(player_id, pid, pdata)

		# Broadcast new player to all other clients (except the new player themselves)
		for pid in players.keys():
			if pid != player_id:
				_rpc_add_player.rpc_id(pid, player_id, players[player_id])


@rpc("authority", "call_remote", "reliable")
func _rpc_add_player(player_id: int, player_data: Dictionary) -> void:
	# Client receives player info from server
	print("NetworkManager: Received player data for %d (%s)" % [player_id, player_data.get("name", "Unknown")])
	if player_id != multiplayer.get_unique_id():  # Don't add ourselves twice
		_add_player(player_id, player_data)
	else:
		print("NetworkManager: Skipping adding ourselves (already in list)")


@rpc("authority", "call_remote", "reliable")
func _rpc_start_game(updated_players: Dictionary) -> void:
	# All clients receive game start signal with updated player data
	print("NetworkManager: Game starting! Received %d players" % updated_players.size())

	# Update our local players dictionary with the authoritative data from server
	players = updated_players.duplicate(true)

	# Debug: Print all players
	for player_id in players.keys():
		var pdata: Dictionary = players[player_id]
		print("NetworkManager: Player %d (%s) - Corruptor: %s" % [player_id, pdata.get("name", "Unknown"), pdata.get("is_corruptor", false)])

	get_tree().change_scene_to_file("res://scenes/levels/test_level.tscn")
	game_started.emit()
