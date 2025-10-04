extends CharacterBody2D
## Player controller for Fractured Reality
## Handles movement, jumping, and basic physics for both Repairers and Corruptor

# Movement parameters
@export var move_speed: float = 300.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
@export var jump_velocity: float = -500.0
@export var gravity: float = 1500.0
@export var max_fall_speed: float = 1000.0

# Player state
var player_id: int = -1
var is_corruptor: bool = false

# Signals
signal player_jumped()
signal player_landed()
signal player_died(player_id: int)


func _ready() -> void:
	# Set up multiplayer authority
	if player_id > 0:
		set_multiplayer_authority(player_id)

	# Disable camera for non-local players
	if $Camera2D and not is_multiplayer_authority():
		$Camera2D.enabled = false


func _physics_process(delta: float) -> void:
	# Only process input for local player (authority)
	if not is_multiplayer_authority():
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	# Get input direction
	var input_dir := _get_input_direction()

	# Apply horizontal movement
	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Handle jump
	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = jump_velocity
		player_jumped.emit()

	# Move the player
	var was_on_floor := is_on_floor()
	move_and_slide()

	# Detect landing
	if not was_on_floor and is_on_floor():
		player_landed.emit()


func _get_input_direction() -> float:
	"""Get the horizontal input direction from player input."""
	var direction := 0.0

	if Input.is_action_pressed("move_right"):
		direction += 1.0
	if Input.is_action_pressed("move_left"):
		direction -= 1.0

	return direction


func set_player_role(is_corrupt: bool) -> void:
	"""Set whether this player is the Corruptor or a Repairer."""
	is_corruptor = is_corrupt

	# Update visual appearance based on role
	if is_corruptor:
		$Sprite.color = Color(1.0, 0.0, 0.5, 1.0)  # Glitch Red/Purple for Corruptor
	else:
		$Sprite.color = Color(0.0, 1.0, 1.0, 1.0)  # Neon Cyan for Repairers


func take_damage() -> void:
	"""Handle player taking damage/death."""
	player_died.emit(player_id)
	# Death logic will be expanded with ghost recording
