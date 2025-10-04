extends Control
## Online Lobby - WAN multiplayer with friends system
## Test implementation for P2P over internet

@onready var username_label := $MarginContainer/VBoxContainer/Header/UsernameLabel
@onready var add_friend_input := $MarginContainer/VBoxContainer/ContentContainer/FriendsPanel/AddFriendContainer/AddFriendInput
@onready var add_friend_button := $MarginContainer/VBoxContainer/ContentContainer/FriendsPanel/AddFriendContainer/AddFriendButton
@onready var friends_list := $MarginContainer/VBoxContainer/ContentContainer/FriendsPanel/FriendsScroll/FriendsList
@onready var status_label := $MarginContainer/VBoxContainer/ContentContainer/ActionsPanel/StatusLabel
@onready var host_button := $MarginContainer/VBoxContainer/ContentContainer/ActionsPanel/HostButton
@onready var logout_button := $MarginContainer/VBoxContainer/Footer/LogoutButton
@onready var back_button := $MarginContainer/VBoxContainer/Footer/BackButton


func _ready() -> void:
	# Check if logged in
	if not AccountManager.is_logged_in:
		print("OnlineLobby: Not logged in, returning to menu")
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return

	# Update UI with username
	username_label.text = "Logged in as: " + AccountManager.current_user.username

	# Connect signals
	add_friend_button.pressed.connect(_on_add_friend_pressed)
	host_button.pressed.connect(_on_host_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Connect account manager signals
	AccountManager.friends_updated.connect(_on_friends_updated)
	AccountManager.friend_request_received.connect(_on_friend_request_received)
	AccountManager.friend_came_online.connect(_on_friend_online)
	AccountManager.friend_went_offline.connect(_on_friend_offline)

	# Load friends list
	AccountManager.refresh_friends()


func _on_add_friend_pressed() -> void:
	var friend_username: String = add_friend_input.text.strip_edges()

	if friend_username.is_empty():
		status_label.text = "Enter a username to add"
		return

	if friend_username == AccountManager.current_user.username:
		status_label.text = "Cannot add yourself as friend"
		return

	status_label.text = "Sending friend request..."
	AccountManager.add_friend(friend_username)
	add_friend_input.text = ""


func _on_friends_updated(friends: Array) -> void:
	print("OnlineLobby: Friends list updated - %d friends" % friends.size())

	# Clear existing list
	for child in friends_list.get_children():
		child.queue_free()

	if friends.is_empty():
		var label := Label.new()
		label.text = "No friends yet. Add some above!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		friends_list.add_child(label)
		return

	# Display friends
	for friend in friends:
		var friend_entry := _create_friend_entry(friend)
		friends_list.add_child(friend_entry)

	status_label.text = "Ready to play!"


func _create_friend_entry(friend: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	# Friend name
	var name_label := Label.new()
	name_label.text = friend.username
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Online indicator
	if friend.get("online", false):
		name_label.text += " (Online)"
		name_label.add_theme_color_override("font_color", Color(0, 1, 0))
	else:
		name_label.text += " (Offline)"
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	hbox.add_child(name_label)

	# Status/action buttons
	var status: String = friend.get("status", "")
	if status == "pending":
		var request_type: String = friend.get("requestType", "")
		if request_type == "received":
			# Received friend request - show accept/reject
			var accept_btn := Button.new()
			accept_btn.text = "Accept"
			accept_btn.pressed.connect(func(): _accept_friend_request(friend.id))
			hbox.add_child(accept_btn)

			var reject_btn := Button.new()
			reject_btn.text = "Reject"
			reject_btn.pressed.connect(func(): _reject_friend_request(friend.id))
			hbox.add_child(reject_btn)
		else:
			# Sent friend request - show pending
			var pending_label := Label.new()
			pending_label.text = "(Pending)"
			pending_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
			hbox.add_child(pending_label)

	elif status == "accepted" and friend.get("online", false):
		# Can invite to game
		var invite_btn := Button.new()
		invite_btn.text = "Invite"
		invite_btn.disabled = true  # TODO: Implement invites
		hbox.add_child(invite_btn)

	return panel


func _accept_friend_request(friend_id: String) -> void:
	status_label.text = "Accepting friend request..."
	AccountManager.respond_friend_request(friend_id, true)


func _reject_friend_request(friend_id: String) -> void:
	status_label.text = "Rejecting friend request..."
	AccountManager.respond_friend_request(friend_id, false)


func _on_friend_request_received(_user_id: String) -> void:
	status_label.text = "New friend request received!"
	# List will auto-update via friends_updated signal


func _on_friend_online(user_id: String, username: String) -> void:
	print("OnlineLobby: Friend %s came online" % username)
	status_label.text = "%s came online!" % username


func _on_friend_offline(user_id: String) -> void:
	print("OnlineLobby: Friend went offline: %s" % user_id)


func _on_host_pressed() -> void:
	status_label.text = "Hosting game... (WAN P2P not yet fully implemented)"
	# TODO: Implement WebRTC P2P hosting
	# For now, fall back to LAN hosting
	var error := NetworkManager.create_server()
	if error == OK:
		get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")


func _on_logout_pressed() -> void:
	AccountManager.logout()
	get_tree().change_scene_to_file("res://scenes/ui/account_login.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
