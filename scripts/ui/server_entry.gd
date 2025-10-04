extends PanelContainer
## Server Entry - Individual server listing in browser
## Displays server info and join button

@onready var server_name_label := $MarginContainer/HBoxContainer/InfoContainer/ServerName
@onready var players_label := $MarginContainer/HBoxContainer/InfoContainer/PlayersLabel
@onready var ping_label := $MarginContainer/HBoxContainer/PingLabel
@onready var join_button := $MarginContainer/HBoxContainer/JoinButton

signal join_requested

var server_data: Dictionary = {}


func setup(data: Dictionary) -> void:
	"""Setup the server entry with data."""
	server_data = data

	server_name_label.text = data.get("name", "Unknown Server")
	players_label.text = "%d/%d players" % [data.get("players", 0), data.get("max_players", 5)]
	ping_label.text = "%d ms" % data.get("ping", 999)

	# Disable join button if server is full
	var is_full: bool = data.get("players", 0) >= data.get("max_players", 5)
	join_button.disabled = is_full
	if is_full:
		join_button.text = "FULL"


func _ready() -> void:
	if join_button:
		join_button.pressed.connect(_on_join_pressed)


func _on_join_pressed() -> void:
	join_requested.emit()
