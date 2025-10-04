extends Node2D
## Level Manager for Fractured Reality
## Handles level state, fragment spawning, and round management

# Player spawning
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
var spawn_points := [
	Vector2(-200, 300),
	Vector2(200, 300),
	Vector2(0, 200),
	Vector2(-300, 100),
	Vector2(300, 100),
]

# Level state
var round_time: float = 300.0  # 5 minutes per round
var time_elapsed: float = 0.0
var fragments_collected: int = 0
var total_fragments: int = 15
var players_node: Node2D

# Signals
signal round_started()
signal round_ended()
signal fragment_collected(total: int, max: int)
signal time_updated(remaining: float)


func _ready() -> void:
	# Level initialization
	print("Level loaded: ", get_name())

	# Create players node
	players_node = Node2D.new()
	players_node.name = "Players"
	add_child(players_node)

	# Spawn players for multiplayer
	if multiplayer.get_peers().size() > 0 or multiplayer.is_server():
		_spawn_players()
	else:
		# Single player mode
		_spawn_local_player()

	# Start the round
	round_started.emit()


func _spawn_players() -> void:
	"""Spawn a player for each connected peer."""
	var all_players := NetworkManager.get_all_players()
	var spawn_index := 0

	for player_id in all_players.keys():
		var player_data: Dictionary = all_players[player_id]
		_spawn_player(player_id, player_data, spawn_index)
		spawn_index += 1


func _spawn_player(player_id: int, player_data: Dictionary, spawn_index: int) -> void:
	"""Spawn a single player at the given spawn point."""
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % player_id
	player.player_id = player_id

	# Set spawn position
	var spawn_pos := spawn_points[spawn_index % spawn_points.size()]
	player.position = spawn_pos

	# Set player role
	var is_corruptor: bool = player_data.get("is_corruptor", false)
	player.set_player_role(is_corruptor)

	players_node.add_child(player, true)
	print("LevelManager: Spawned player %d at %v" % [player_id, spawn_pos])


func _spawn_local_player() -> void:
	"""Spawn a single local player for testing."""
	var player := PLAYER_SCENE.instantiate()
	player.name = "LocalPlayer"
	player.player_id = 1
	player.position = Vector2(0, 300)
	players_node.add_child(player)
	print("LevelManager: Spawned local player")


func _process(delta: float) -> void:
	# Update round timer (will be moved to game manager later)
	time_elapsed += delta
	var time_remaining := round_time - time_elapsed

	if time_remaining <= 0.0:
		_end_round()
	else:
		time_updated.emit(time_remaining)


func _end_round() -> void:
	"""End the current round and determine winner."""
	round_ended.emit()
	print("Round ended! Fragments collected: ", fragments_collected, "/", total_fragments)
	# TODO: Determine winner (Repairers or Corruptor)
	# TODO: Show end screen


func collect_fragment() -> void:
	"""Called when a player collects a fragment."""
	fragments_collected += 1
	fragment_collected.emit(fragments_collected, total_fragments)
	print("Fragment collected: ", fragments_collected, "/", total_fragments)

	# Check win condition
	if fragments_collected >= total_fragments:
		_end_round()
