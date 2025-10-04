extends Node
## AccountManager - Handles user accounts, friends, and master server communication
## Connects to Node.js backend for WAN multiplayer

# Master server configuration
# CHANGE THIS to your deployed server URL (Render/Railway/Fly.io)
const MASTER_SERVER_URL := "http://localhost:3000"  # Local development
# const MASTER_SERVER_URL := "https://your-app.onrender.com"  # Production

# User state
var is_logged_in := false
var current_user := {
	"id": "",
	"username": ""
}

# Friends data
var friends_list := []  # Array of friend dictionaries

# WebSocket for real-time signaling
var ws: WebSocketPeer
var ws_connected := false

# Signals
signal login_succeeded(user: Dictionary)
signal login_failed(error: String)
signal register_succeeded(user: Dictionary)
signal register_failed(error: String)
signal friends_updated(friends: Array)
signal friend_request_received(user_id: String)
signal friend_came_online(user_id: String, username: String)
signal friend_went_offline(user_id: String)
signal webrtc_offer_received(from_id: String, from_username: String, offer: String)
signal webrtc_answer_received(from_id: String, answer: String)
signal webrtc_ice_candidate_received(from_id: String, candidate: String)


func _ready() -> void:
	print("AccountManager: Initialized")


func _process(_delta: float) -> void:
	# Poll WebSocket
	if ws:
		ws.poll()
		var state := ws.get_ready_state()

		if state == WebSocketPeer.STATE_OPEN:
			if not ws_connected:
				ws_connected = true
				print("AccountManager: WebSocket connected")
				_send_ws_auth()

			# Receive messages
			while ws.get_available_packet_count():
				var packet := ws.get_packet()
				var message_text := packet.get_string_from_utf8()
				_handle_ws_message(message_text)

		elif state == WebSocketPeer.STATE_CLOSED:
			if ws_connected:
				ws_connected = false
				print("AccountManager: WebSocket disconnected")


## Register new account
func register(username: String, password: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"username": username,
		"password": password
	})

	var error := http.request(
		MASTER_SERVER_URL + "/api/register",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_error("AccountManager: Failed to send register request")
		register_failed.emit("Network error")
		http.queue_free()
		return

	var result = await http.request_completed
	_handle_register_response(result, http)


func _handle_register_response(result: Array, http: HTTPRequest) -> void:
	var response_code = result[1]
	var body = result[3]

	http.queue_free()

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		register_failed.emit("Invalid server response")
		return

	var data: Dictionary = json.data

	if response_code == 200:
		current_user = data.user
		is_logged_in = true
		_connect_websocket()
		register_succeeded.emit(data.user)
	else:
		register_failed.emit(data.get("error", "Unknown error"))


## Login to existing account
func login(username: String, password: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"username": username,
		"password": password
	})

	var error := http.request(
		MASTER_SERVER_URL + "/api/login",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_error("AccountManager: Failed to send login request")
		login_failed.emit("Network error")
		http.queue_free()
		return

	var result = await http.request_completed
	_handle_login_response(result, http)


func _handle_login_response(result: Array, http: HTTPRequest) -> void:
	var response_code = result[1]
	var body = result[3]

	http.queue_free()

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		login_failed.emit("Invalid server response")
		return

	var data: Dictionary = json.data

	if response_code == 200:
		current_user = data.user
		is_logged_in = true
		_connect_websocket()
		login_succeeded.emit(data.user)
		# Fetch friends list
		refresh_friends()
	else:
		login_failed.emit(data.get("error", "Unknown error"))


## Logout
func logout() -> void:
	is_logged_in = false
	current_user.clear()
	friends_list.clear()

	if ws:
		ws.close()
		ws = null
		ws_connected = false

	print("AccountManager: Logged out")


## Get friends list from server
func refresh_friends() -> void:
	if not is_logged_in:
		return

	var http := HTTPRequest.new()
	add_child(http)

	var error := http.request(
		MASTER_SERVER_URL + "/api/friends/" + current_user.id,
		[],
		HTTPClient.METHOD_GET
	)

	if error != OK:
		push_error("AccountManager: Failed to fetch friends")
		http.queue_free()
		return

	var result = await http.request_completed
	_handle_friends_response(result, http)


func _handle_friends_response(result: Array, http: HTTPRequest) -> void:
	var response_code = result[1]
	var body = result[3]

	http.queue_free()

	if response_code != 200:
		return

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		return

	var data: Dictionary = json.data
	friends_list = data.get("friends", [])
	friends_updated.emit(friends_list)


## Send friend request
func add_friend(friend_username: String) -> void:
	if not is_logged_in:
		return

	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"userId": current_user.id,
		"friendUsername": friend_username
	})

	var error := http.request(
		MASTER_SERVER_URL + "/api/friends/add",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_error("AccountManager: Failed to send friend request")
		http.queue_free()
		return

	var result = await http.request_completed
	var response_code = result[1]

	http.queue_free()

	if response_code == 200:
		# Refresh friends list
		refresh_friends()


## Accept/reject friend request
func respond_friend_request(friend_id: String, accept: bool) -> void:
	if not is_logged_in:
		return

	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"userId": current_user.id,
		"friendId": friend_id,
		"accept": accept
	})

	var error := http.request(
		MASTER_SERVER_URL + "/api/friends/respond",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_error("AccountManager: Failed to respond to friend request")
		http.queue_free()
		return

	var result = await http.request_completed
	var response_code = result[1]

	http.queue_free()

	if response_code == 200:
		# Refresh friends list
		refresh_friends()


## Connect to WebSocket for real-time communication
func _connect_websocket() -> void:
	# Extract WebSocket URL from HTTP URL
	var ws_url := MASTER_SERVER_URL.replace("http://", "ws://").replace("https://", "wss://")

	# Note: Godot doesn't have Socket.IO support, so we're using direct WebSocket
	# This is a simplified implementation - production would need Socket.IO GDScript plugin
	# For now, we'll implement essential signaling through HTTP polling
	# TODO: Add proper WebSocket/Socket.IO integration

	print("AccountManager: WebSocket connection pending full implementation")
	print("AccountManager: Using HTTP polling for now")


## Send authentication to WebSocket
func _send_ws_auth() -> void:
	if not ws or not ws_connected:
		return

	var auth_msg := JSON.stringify({
		"event": "authenticate",
		"data": {
			"userId": current_user.id,
			"username": current_user.username
		}
	})

	ws.send_text(auth_msg)


## Handle incoming WebSocket messages
func _handle_ws_message(message: String) -> void:
	var json := JSON.new()
	var parse_result := json.parse(message)

	if parse_result != OK:
		return

	var data: Dictionary = json.data
	var event: String = data.get("event", "")

	match event:
		"friend_request":
			friend_request_received.emit(data.data.userId)
			refresh_friends()

		"friend_accepted":
			refresh_friends()

		"friend_online":
			friend_came_online.emit(data.data.userId, data.data.username)
			refresh_friends()

		"friend_offline":
			friend_went_offline.emit(data.data.userId)
			refresh_friends()

		"webrtc_offer":
			webrtc_offer_received.emit(
				data.data.fromId,
				data.data.fromUsername,
				data.data.offer
			)

		"webrtc_answer":
			webrtc_answer_received.emit(
				data.data.fromId,
				data.data.answer
			)

		"webrtc_ice_candidate":
			webrtc_ice_candidate_received.emit(
				data.data.fromId,
				data.data.candidate
			)


## Send WebRTC offer (for future WebRTC implementation)
func send_webrtc_offer(target_id: String, offer: String) -> void:
	if not ws or not ws_connected:
		return

	var msg := JSON.stringify({
		"event": "webrtc_offer",
		"data": {
			"targetId": target_id,
			"offer": offer
		}
	})

	ws.send_text(msg)


## Send WebRTC answer (for future WebRTC implementation)
func send_webrtc_answer(target_id: String, answer: String) -> void:
	if not ws or not ws_connected:
		return

	var msg := JSON.stringify({
		"event": "webrtc_answer",
		"data": {
			"targetId": target_id,
			"answer": answer
		}
	})

	ws.send_text(msg)


## Send ICE candidate (for future WebRTC implementation)
func send_ice_candidate(target_id: String, candidate: String) -> void:
	if not ws or not ws_connected:
		return

	var msg := JSON.stringify({
		"event": "webrtc_ice_candidate",
		"data": {
			"targetId": target_id,
			"candidate": candidate
		}
	})

	ws.send_text(msg)
