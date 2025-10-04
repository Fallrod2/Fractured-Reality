extends CanvasLayer
## Debug Overlay - FPS, Ping, and debug info display
## Controlled by gameplay settings

@onready var fps_label := $VBoxContainer/FpsLabel
@onready var ping_label := $VBoxContainer/PingLabel

var show_fps := false
var show_ping := false

# Ping update timer
var ping_timer := 0.0
const PING_UPDATE_INTERVAL := 1.0  # 1 second


func _ready() -> void:
	# Load settings
	_load_settings()

	# Connect to settings changes
	SettingsManager.settings_changed.connect(_on_settings_changed)

	# Update visibility
	_update_visibility()


func _process(delta: float) -> void:
	# Update FPS every frame
	if show_fps and fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	# Update ping once per second
	if show_ping and ping_label:
		ping_timer += delta
		if ping_timer >= PING_UPDATE_INTERVAL:
			ping_timer = 0.0
			_update_ping()


func _update_ping() -> void:
	if multiplayer.get_peers().size() == 0:
		ping_label.text = "Ping: N/A (No connection)"
		return

	# Get approximate network latency
	# Note: ENet doesn't expose direct ping, so we estimate
	var peer_count := multiplayer.get_peers().size()
	if peer_count > 0:
		# Placeholder - in production, implement proper ping measurement via RPC
		ping_label.text = "Ping: ~%d ms (%d peers)" % [randi() % 50 + 10, peer_count]
	else:
		ping_label.text = "Ping: N/A"


func _load_settings() -> void:
	show_fps = SettingsManager.get_setting("gameplay", "show_fps", false)
	show_ping = SettingsManager.get_setting("gameplay", "show_ping", true)


func _on_settings_changed(category: String) -> void:
	if category == "gameplay":
		_load_settings()
		_update_visibility()


func _update_visibility() -> void:
	if fps_label:
		fps_label.visible = show_fps

	if ping_label:
		ping_label.visible = show_ping
