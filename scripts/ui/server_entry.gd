extends PanelContainer
## Server Entry - Individual server listing in browser
## Displays server info and join button

@onready var server_name_label := $MarginContainer/HBoxContainer/InfoContainer/ServerName
@onready var players_label := $MarginContainer/HBoxContainer/InfoContainer/PlayersLabel
@onready var ping_label := $MarginContainer/HBoxContainer/PingLabel
@onready var join_button := $MarginContainer/HBoxContainer/JoinButton

signal join_requested

var server_data: Dictionary = {}
var is_ready := false


func setup(data: Dictionary) -> void:
	"""Setup the server entry with data."""
	server_data = data

	# If nodes are ready, apply data immediately
	if is_ready:
		_apply_data()


func _ready() -> void:
	is_ready = true

	# Connect join button
	if join_button:
		join_button.pressed.connect(_on_join_pressed)

	# Apply data if it was set before _ready
	if not server_data.is_empty():
		_apply_data()


func _apply_data() -> void:
	"""Apply server data to UI elements."""
	server_name_label.text = server_data.get("name", "Unknown Server")
	players_label.text = "%d/%d players" % [server_data.get("players", 0), server_data.get("max_players", 5)]
	ping_label.text = "%d ms" % server_data.get("ping", 999)

	# Disable join button if server is full
	var is_full: bool = server_data.get("players", 0) >= server_data.get("max_players", 5)
	join_button.disabled = is_full
	if is_full:
		join_button.text = "FULL"


func _on_join_pressed() -> void:
	join_requested.emit()
