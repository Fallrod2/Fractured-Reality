extends Node
## AccountManager - Supabase authentication and friends system
## Handles user accounts, friends, and online multiplayer via Supabase

# Supabase configuration
const SUPABASE_URL := "https://bszhtjjxncnzzupzairu.supabase.co"
const SUPABASE_ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzemh0amp4bmNuenp1cHphaXJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk2MDUxNDYsImV4cCI6MjA3NTE4MTE0Nn0.P_ERnc_e4jtAvyvY7WPmeJtb70e-U_R4Sm8fJ5Y6XHA"

# User state
var is_logged_in := false
var current_user := {
	"id": "",
	"username": "",
	"email": ""
}
var access_token := ""
var refresh_token := ""

# Friends data
var friends_list := []  # Array of friend dictionaries

# Signals
signal login_succeeded(user: Dictionary)
signal login_failed(error: String)
signal register_succeeded(user: Dictionary)
signal register_failed(error: String)
signal friends_updated(friends: Array)
signal friend_request_received(user_id: String)
signal friend_came_online(user_id: String, username: String)
signal friend_went_offline(user_id: String)


func _ready() -> void:
	print("AccountManager: Initialized with Supabase")
	# Try to restore session from saved tokens
	_try_restore_session()


## Register new account
func register(username: String, password: String) -> void:
	# Generate email from username (since we don't collect emails in UI)
	var email := username + "@fractured-reality.local"

	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"email": email,
		"password": password,
		"data": {
			"username": username
		}
	})

	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]

	var error := http.request(
		SUPABASE_URL + "/auth/v1/signup",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_error("AccountManager: Failed to send register request")
		register_failed.emit("Network error")
		http.queue_free()
		return

	var result = await http.request_completed
	_handle_auth_response(result, http, true)


## Login to existing account
func login(username: String, password: String) -> void:
	# Generate email from username
	var email := username + "@fractured-reality.local"

	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"email": email,
		"password": password
	})

	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Content-Type: application/json"
	]

	var error := http.request(
		SUPABASE_URL + "/auth/v1/token?grant_type=password",
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		push_error("AccountManager: Failed to send login request")
		login_failed.emit("Network error")
		http.queue_free()
		return

	var result = await http.request_completed
	_handle_auth_response(result, http, false)


func _handle_auth_response(result: Array, http: HTTPRequest, is_register: bool) -> void:
	var response_code = result[1]
	var body = result[3]

	http.queue_free()

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		var error_msg := "Invalid server response"
		if is_register:
			register_failed.emit(error_msg)
		else:
			login_failed.emit(error_msg)
		return

	var data: Dictionary = json.data

	if response_code == 200:
		# Success!
		access_token = data.get("access_token", "")
		refresh_token = data.get("refresh_token", "")

		var user_data: Dictionary = data.get("user", {})
		var user_metadata: Dictionary = user_data.get("user_metadata", {})

		current_user = {
			"id": user_data.get("id", ""),
			"username": user_metadata.get("username", ""),
			"email": user_data.get("email", "")
		}

		is_logged_in = true

		# Save session
		_save_session()

		# Set online status
		_set_online_status(true)

		print("AccountManager: Login successful - %s" % current_user.username)

		if is_register:
			register_succeeded.emit(current_user)
		else:
			login_succeeded.emit(current_user)

		# Fetch friends list
		refresh_friends()
	else:
		var error_msg: String = data.get("error_description", data.get("msg", "Unknown error"))
		print("AccountManager: Auth failed - %s" % error_msg)

		if is_register:
			register_failed.emit(error_msg)
		else:
			login_failed.emit(error_msg)


## Logout
func logout() -> void:
	# Set offline status
	if is_logged_in:
		_set_online_status(false)

	is_logged_in = false
	current_user.clear()
	access_token = ""
	refresh_token = ""
	friends_list.clear()

	# Clear saved session
	var config := ConfigFile.new()
	config.set_value("session", "access_token", "")
	config.set_value("session", "refresh_token", "")
	config.save("user://session.cfg")

	print("AccountManager: Logged out")


## Get friends list from Supabase
func refresh_friends() -> void:
	if not is_logged_in:
		return

	var http := HTTPRequest.new()
	add_child(http)

	# Query friends table with profile data
	var query := "select=*,friend_profile:friend_id(id,username,is_online)"

	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

	var error := http.request(
		SUPABASE_URL + "/rest/v1/friends?" + query,
		headers,
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
		print("AccountManager: Failed to fetch friends")
		return

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())

	if parse_result != OK:
		return

	var data = json.data
	if not data is Array:
		return

	# Transform data to match UI expectations
	friends_list.clear()
	for friend_row in data:
		var friend_profile = friend_row.get("friend_profile", {})
		if friend_profile:
			friends_list.append({
				"id": friend_profile.get("id", ""),
				"username": friend_profile.get("username", ""),
				"status": friend_row.get("status", "pending"),
				"online": friend_profile.get("is_online", false),
				"requestType": "sent" if friend_row.get("user_id") == current_user.id else "received"
			})

	print("AccountManager: Friends updated - %d friends" % friends_list.size())
	friends_updated.emit(friends_list)


## Send friend request
func add_friend(friend_username: String) -> void:
	if not is_logged_in:
		return

	# First, find the friend's user ID by username
	var http := HTTPRequest.new()
	add_child(http)

	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json"
	]

	var error := http.request(
		SUPABASE_URL + "/rest/v1/profiles?username=eq." + friend_username.uri_encode(),
		headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		push_error("AccountManager: Failed to find user")
		http.queue_free()
		return

	var result = await http.request_completed
	var response_code = result[1]
	var body = result[3]

	http.queue_free()

	if response_code != 200:
		print("AccountManager: User not found")
		return

	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())

	if parse_result != OK or not json.data is Array:
		return

	var profiles = json.data
	if profiles.is_empty():
		print("AccountManager: User '%s' not found" % friend_username)
		return

	var friend_id: String = profiles[0].get("id", "")

	# Now send friend request
	_send_friend_request(friend_id)


func _send_friend_request(friend_id: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"user_id": current_user.id,
		"friend_id": friend_id,
		"status": "pending"
	})

	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	]

	var error := http.request(
		SUPABASE_URL + "/rest/v1/friends",
		headers,
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

	if response_code == 201:
		print("AccountManager: Friend request sent")
		# Refresh friends list
		refresh_friends()
	else:
		print("AccountManager: Failed to send friend request (code %d)" % response_code)


## Accept/reject friend request
func respond_friend_request(friend_id: String, accept: bool) -> void:
	if not is_logged_in:
		return

	var http := HTTPRequest.new()
	add_child(http)

	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	]

	if accept:
		# Update status to accepted
		var body := JSON.stringify({
			"status": "accepted"
		})

		var error := http.request(
			SUPABASE_URL + "/rest/v1/friends?user_id=eq." + friend_id.uri_encode() + "&friend_id=eq." + current_user.id.uri_encode(),
			headers,
			HTTPClient.METHOD_PATCH,
			body
		)

		if error != OK:
			push_error("AccountManager: Failed to accept friend request")
			http.queue_free()
			return
	else:
		# Delete the friend request
		var error := http.request(
			SUPABASE_URL + "/rest/v1/friends?user_id=eq." + friend_id.uri_encode() + "&friend_id=eq." + current_user.id.uri_encode(),
			headers,
			HTTPClient.METHOD_DELETE
		)

		if error != OK:
			push_error("AccountManager: Failed to reject friend request")
			http.queue_free()
			return

	var result = await http.request_completed
	http.queue_free()

	# Refresh friends list
	refresh_friends()


## Set online/offline status
func _set_online_status(online: bool) -> void:
	if not is_logged_in:
		return

	var http := HTTPRequest.new()
	add_child(http)

	var body := JSON.stringify({
		"is_online": online
	})

	var headers := [
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + access_token,
		"Content-Type: application/json",
		"Prefer: return=minimal"
	]

	var error := http.request(
		SUPABASE_URL + "/rest/v1/profiles?id=eq." + current_user.id.uri_encode(),
		headers,
		HTTPClient.METHOD_PATCH,
		body
	)

	if error != OK:
		push_error("AccountManager: Failed to set online status")
		http.queue_free()
		return

	await http.request_completed
	http.queue_free()


## Save session to disk
func _save_session() -> void:
	var config := ConfigFile.new()
	config.set_value("session", "access_token", access_token)
	config.set_value("session", "refresh_token", refresh_token)
	config.save("user://session.cfg")


## Try to restore session from saved tokens
func _try_restore_session() -> void:
	var config := ConfigFile.new()
	if config.load("user://session.cfg") != OK:
		return

	var saved_access := config.get_value("session", "access_token", "")
	var saved_refresh := config.get_value("session", "refresh_token", "")

	if saved_access.is_empty() or saved_refresh.is_empty():
		return

	# TODO: Implement token refresh and session validation
	# For now, require manual login
	print("AccountManager: Session restore not yet implemented")
