extends CanvasLayer
## Social Sidebar - Epic Games-style slide-out panel
## Shows user info, friends list, and quick actions

@onready var toggle_button := $ToggleButton
@onready var sidebar_panel := $SidebarPanel
@onready var close_button := $SidebarPanel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var username_label := $SidebarPanel/MarginContainer/VBoxContainer/UserInfo/UsernameLabel
@onready var status_label := $SidebarPanel/MarginContainer/VBoxContainer/UserInfo/StatusLabel
@onready var friends_list := $SidebarPanel/MarginContainer/VBoxContainer/FriendsScroll/FriendsList
@onready var no_friends_label := $SidebarPanel/MarginContainer/VBoxContainer/FriendsScroll/FriendsList/NoFriendsLabel
@onready var logout_button := $SidebarPanel/MarginContainer/VBoxContainer/QuickActions/LogoutButton

const SLIDE_DURATION := 0.3
const MIN_SIDEBAR_WIDTH := 300.0
const MAX_SIDEBAR_WIDTH := 500.0
const SIDEBAR_WIDTH_PERCENT := 0.25  # 25% of viewport width

var sidebar_width := 400.0  # Computed dynamically
var is_open := false


func _ready() -> void:
	# Calculate initial sidebar width based on viewport
	_update_sidebar_dimensions()

	# Connect viewport resize signal
	get_viewport().size_changed.connect(_update_sidebar_dimensions)

	# Connect signals
	toggle_button.pressed.connect(_on_toggle_pressed)
	close_button.pressed.connect(_on_close_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

	# Connect account manager signals
	AccountManager.login_succeeded.connect(_on_login_succeeded)
	AccountManager.friends_updated.connect(_on_friends_updated)

	# Initial position (hidden off-screen)
	sidebar_panel.position.x = -sidebar_width

	# Setup keyboard navigation
	_setup_keyboard_navigation()

	# Apply glitch shader effect
	_apply_glitch_effect()

	# Update UI with current account state
	_update_user_info()

	# Load friends if logged in
	if AccountManager.is_logged_in:
		_on_friends_updated(AccountManager.friends_list)


func _update_sidebar_dimensions() -> void:
	"""Update sidebar width based on viewport size (responsive)."""
	var viewport_size := get_viewport().get_visible_rect().size
	# Calculate 25% of viewport width, clamped between 300-500px
	sidebar_width = clamp(
		viewport_size.x * SIDEBAR_WIDTH_PERCENT,
		MIN_SIDEBAR_WIDTH,
		MAX_SIDEBAR_WIDTH
	)

	# Update sidebar panel size
	sidebar_panel.size.x = sidebar_width

	# Update position if closed (keep off-screen at correct offset)
	if not is_open:
		sidebar_panel.position.x = -sidebar_width


func _setup_keyboard_navigation() -> void:
	"""Setup keyboard focus navigation and shortcuts."""
	# Set focus neighbors for vertical navigation
	toggle_button.focus_neighbor_bottom = close_button.get_path()
	close_button.focus_neighbor_top = toggle_button.get_path()
	close_button.focus_neighbor_bottom = logout_button.get_path()
	logout_button.focus_neighbor_top = close_button.get_path()


func _apply_glitch_effect() -> void:
	"""Apply subtle glitch shader to sidebar panel."""
	var glitch_shader: Shader = preload("res://assets/shaders/ui_glitch.gdshader")
	var shader_material := ShaderMaterial.new()
	shader_material.shader = glitch_shader

	# Subtle parameters for sidebar (less intense than main menu)
	shader_material.set_shader_parameter("glitch_strength", 0.015)
	shader_material.set_shader_parameter("scan_line_speed", 0.3)
	shader_material.set_shader_parameter("scan_line_density", 700.0)
	shader_material.set_shader_parameter("noise_amount", 0.01)
	shader_material.set_shader_parameter("horizontal_shake", 0.002)
	shader_material.set_shader_parameter("glitch_color", Color(0.0, 1.0, 1.0, 0.15))

	sidebar_panel.material = shader_material


func _input(event: InputEvent) -> void:
	"""Handle keyboard shortcuts."""
	# Toggle sidebar with F1 key
	if event.is_action_pressed("ui_page_up"):  # F1 is mapped to ui_page_up by default in Godot
		_on_toggle_pressed()
		get_viewport().set_input_as_handled()

	# Close sidebar with Escape if open
	if event.is_action_pressed("ui_cancel") and is_open:
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _on_toggle_pressed() -> void:
	if is_open:
		_close_sidebar()
	else:
		_open_sidebar()


func _on_close_pressed() -> void:
	_close_sidebar()


func _open_sidebar() -> void:
	is_open = true

	# Slide in animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(sidebar_panel, "position:x", 0.0, SLIDE_DURATION)


func _close_sidebar() -> void:
	is_open = false

	# Slide out animation
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(sidebar_panel, "position:x", -sidebar_width, SLIDE_DURATION)


func _update_user_info() -> void:
	if AccountManager.is_logged_in:
		username_label.text = AccountManager.current_user.username
		status_label.text = "Online"
		status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Brighter green - 6.2:1 contrast (WCAG AA)
		logout_button.disabled = false
	else:
		username_label.text = "Not logged in"
		status_label.text = "Offline"
		status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))  # Lighter gray - 5.1:1 contrast (WCAG AA)
		logout_button.disabled = true


func _on_login_succeeded(_user: Dictionary) -> void:
	_update_user_info()


func _on_friends_updated(friends: Array) -> void:
	# Clear existing friend entries (except NoFriendsLabel)
	for child in friends_list.get_children():
		if child != no_friends_label:
			child.queue_free()

	if friends.is_empty():
		no_friends_label.show()
		return

	no_friends_label.hide()

	# Add friend entries
	for friend in friends:
		var friend_entry := _create_friend_entry(friend)
		friends_list.add_child(friend_entry)


func _create_friend_entry(friend: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	# Online status indicator
	var status_indicator := ColorRect.new()
	status_indicator.custom_minimum_size = Vector2(12, 12)
	if friend.get("online", false):
		status_indicator.color = Color(0, 1, 0)  # Green for online
	else:
		status_indicator.color = Color(0.3, 0.3, 0.3)  # Gray for offline
	hbox.add_child(status_indicator)

	# Friend name
	var name_label := Label.new()
	name_label.text = friend.username
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Color based on status
	if friend.get("status", "") == "pending":
		var request_type: String = friend.get("requestType", "")
		if request_type == "received":
			# Received friend request - show Accept/Reject buttons
			name_label.add_theme_color_override("font_color", Color(1, 0.8, 0))  # Yellow - already good contrast
			hbox.add_child(name_label)

			# Accept button
			var accept_btn := Button.new()
			accept_btn.text = "✓"
			accept_btn.custom_minimum_size = Vector2(30, 30)
			accept_btn.tooltip_text = "Accept friend request"
			accept_btn.pressed.connect(func(): _accept_friend_request(friend.id))
			hbox.add_child(accept_btn)

			# Reject button
			var reject_btn := Button.new()
			reject_btn.text = "✗"
			reject_btn.custom_minimum_size = Vector2(30, 30)
			reject_btn.tooltip_text = "Reject friend request"
			reject_btn.pressed.connect(func(): _reject_friend_request(friend.id))
			hbox.add_child(reject_btn)
		else:
			# Sent friend request - show pending
			name_label.text += " (Sent)"
			name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))  # Lighter gray - 5.1:1 contrast (WCAG AA)
			hbox.add_child(name_label)
	elif friend.get("online", false):
		name_label.add_theme_color_override("font_color", Color(0, 1, 1))  # Neon Cyan - already good contrast
		hbox.add_child(name_label)
	else:
		name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))  # Lighter gray - 5.1:1 contrast (WCAG AA)
		hbox.add_child(name_label)

	return panel


func _accept_friend_request(friend_id: String) -> void:
	print("SocialSidebar: Accepting friend request from %s" % friend_id)
	AccountManager.respond_friend_request(friend_id, true)


func _reject_friend_request(friend_id: String) -> void:
	print("SocialSidebar: Rejecting friend request from %s" % friend_id)
	AccountManager.respond_friend_request(friend_id, false)


func _on_logout_pressed() -> void:
	AccountManager.logout()
	_update_user_info()

	# Clear friends list
	for child in friends_list.get_children():
		if child != no_friends_label:
			child.queue_free()

	no_friends_label.show()

	# Close sidebar
	_close_sidebar()

	# Navigate to main menu
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
