extends Node2D
## Level Manager for Fractured Reality
## Handles level state, fragment spawning, and round management

# Level state
var round_time: float = 300.0  # 5 minutes per round
var time_elapsed: float = 0.0
var fragments_collected: int = 0
var total_fragments: int = 15

# Signals
signal round_started()
signal round_ended()
signal fragment_collected(total: int, max: int)
signal time_updated(remaining: float)


func _ready() -> void:
	# Level initialization
	print("Level loaded: ", get_name())
	# TODO: Spawn fragments
	# TODO: Setup multiplayer synchronization

	# Start the round
	round_started.emit()


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
