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

const SIDEBAR_WIDTH := 400.0
const SLIDE_DURATION := 0.3

var is_open := false


func _ready() -> void:
	# Connect signals
	toggle_button.pressed.connect(_on_toggle_pressed)
	close_button.pressed.connect(_on_close_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

	# Connect account manager signals
	AccountManager.login_succeeded.connect(_on_login_succeeded)
	AccountManager.friends_updated.connect(_on_friends_updated)

	# Initial position (hidden off-screen)
	sidebar_panel.position.x = -SIDEBAR_WIDTH

	# Update UI with current account state
	_update_user_info()

	# Load friends if logged in
	if AccountManager.is_logged_in:
		_on_friends_updated(AccountManager.friends_list)


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
	tween.tween_property(sidebar_panel, "position:x", -SIDEBAR_WIDTH, SLIDE_DURATION)


func _update_user_info() -> void:
	if AccountManager.is_logged_in:
		username_label.text = AccountManager.current_user.username
		status_label.text = "Online"
		status_label.add_theme_color_override("font_color", Color(0, 1, 0))
		logout_button.disabled = false
	else:
		username_label.text = "Not logged in"
		status_label.text = "Offline"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
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
			name_label.text += " (Pending)"
			name_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
		else:
			name_label.text += " (Sent)"
			name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif friend.get("online", false):
		name_label.add_theme_color_override("font_color", Color(0, 1, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	hbox.add_child(name_label)

	return panel


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
