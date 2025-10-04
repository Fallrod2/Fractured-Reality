extends Node
## Server Discovery - UDP broadcast for LAN server detection
## Servers broadcast their info, clients listen and discover

signal server_discovered(server_info: Dictionary)
signal server_list_updated(servers: Array)

const BROADCAST_PORT := 8910
const BROADCAST_INTERVAL := 1.0  # Broadcast every 1 second
const SERVER_TIMEOUT := 5.0  # Remove servers not seen for 5 seconds

var udp_server: UDPServer
var udp_client: PacketPeerUDP

var is_broadcasting := false
var is_scanning := false

var broadcast_timer := 0.0
var cleanup_timer := 0.0

# Server info to broadcast (when hosting)
var server_info := {}

# Discovered servers (when scanning)
var discovered_servers := {}  # IP -> {info, last_seen}


func _ready() -> void:
	print("ServerDiscovery: Initialized")


func _process(delta: float) -> void:
	# Server broadcasting
	if is_broadcasting:
		broadcast_timer += delta
		if broadcast_timer >= BROADCAST_INTERVAL:
			broadcast_timer = 0.0
			_broadcast_server()

	# Client scanning
	if is_scanning:
		_check_for_broadcasts()

		# Cleanup old servers
		cleanup_timer += delta
		if cleanup_timer >= 1.0:
			cleanup_timer = 0.0
			_cleanup_old_servers()


## Start broadcasting server info (call when hosting)
func start_broadcasting(info: Dictionary) -> void:
	if is_broadcasting:
		print("ServerDiscovery: Already broadcasting")
		return

	server_info = info.duplicate()
	is_broadcasting = true
	broadcast_timer = 0.0

	print("ServerDiscovery: Started broadcasting server: %s" % server_info.get("name", "Unknown"))


## Stop broadcasting (call when closing server)
func stop_broadcasting() -> void:
	if not is_broadcasting:
		return

	is_broadcasting = false
	server_info.clear()

	print("ServerDiscovery: Stopped broadcasting")


## Start scanning for servers (call when opening server browser)
func start_scanning() -> void:
	if is_scanning:
		print("ServerDiscovery: Already scanning")
		return

	# Create UDP client for receiving broadcasts
	udp_client = PacketPeerUDP.new()
	var error := udp_client.bind(BROADCAST_PORT)

	if error != OK:
		push_error("ServerDiscovery: Failed to bind UDP client to port %d: %s" % [BROADCAST_PORT, error_string(error)])
		return

	is_scanning = true
	discovered_servers.clear()
	cleanup_timer = 0.0

	print("ServerDiscovery: Started scanning for servers on port %d" % BROADCAST_PORT)


## Stop scanning for servers
func stop_scanning() -> void:
	if not is_scanning:
		return

	is_scanning = false
	discovered_servers.clear()

	if udp_client:
		udp_client.close()
		udp_client = null

	print("ServerDiscovery: Stopped scanning")


## Get list of discovered servers
func get_discovered_servers() -> Array:
	var servers := []

	for ip in discovered_servers.keys():
		var server_data: Dictionary = discovered_servers[ip]
		var info: Dictionary = server_data.info.duplicate()
		info["host"] = ip  # Add host IP
		servers.append(info)

	return servers


func _broadcast_server() -> void:
	"""Broadcast server info via UDP."""
	if server_info.is_empty():
		return

	# Prepare broadcast data
	var data := server_info.duplicate()
	var json := JSON.stringify(data)
	var packet := json.to_utf8_buffer()

	# Create broadcast socket
	var broadcast_peer := PacketPeerUDP.new()
	broadcast_peer.set_broadcast_enabled(true)
	broadcast_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)

	# Send broadcast
	var error := broadcast_peer.put_packet(packet)
	if error != OK:
		push_warning("ServerDiscovery: Failed to send broadcast: %s" % error_string(error))
	else:
		print("ServerDiscovery: Broadcast sent - %s" % server_info.get("name", "Unknown"))

	broadcast_peer.close()


func _check_for_broadcasts() -> void:
	"""Check for incoming server broadcasts."""
	if not udp_client:
		return

	while udp_client.get_available_packet_count() > 0:
		var packet := udp_client.get_packet()
		var ip := udp_client.get_packet_ip()
		var port := udp_client.get_packet_port()

		# Parse JSON data
		var json := JSON.new()
		var parse_result := json.parse(packet.get_string_from_utf8())

		if parse_result != OK:
			push_warning("ServerDiscovery: Failed to parse broadcast from %s:%d" % [ip, port])
			continue

		var data: Dictionary = json.data
		if not data is Dictionary:
			continue

		# Ignore broadcasts from ourselves
		if ip == "127.0.0.1" and data.get("host_id") == multiplayer.get_unique_id():
			continue

		# Add/update server
		var current_time := Time.get_ticks_msec() / 1000.0

		if not discovered_servers.has(ip):
			# New server discovered
			discovered_servers[ip] = {
				"info": data,
				"last_seen": current_time,
			}

			var server_data := data.duplicate()
			server_data["host"] = ip
			server_discovered.emit(server_data)

			print("ServerDiscovery: Discovered server '%s' at %s" % [data.get("name", "Unknown"), ip])
		else:
			# Update existing server
			discovered_servers[ip].info = data
			discovered_servers[ip].last_seen = current_time

		# Emit updated server list
		server_list_updated.emit(get_discovered_servers())


func _cleanup_old_servers() -> void:
	"""Remove servers that haven't been seen recently."""
	var current_time := Time.get_ticks_msec() / 1000.0
	var removed := []

	for ip in discovered_servers.keys():
		var server_data: Dictionary = discovered_servers[ip]
		var last_seen: float = server_data.last_seen

		if current_time - last_seen > SERVER_TIMEOUT:
			removed.append(ip)

	for ip in removed:
		var server_name: String = discovered_servers[ip].info.get("name", "Unknown")
		discovered_servers.erase(ip)
		print("ServerDiscovery: Removed stale server '%s' at %s" % [server_name, ip])

	if removed.size() > 0:
		server_list_updated.emit(get_discovered_servers())
