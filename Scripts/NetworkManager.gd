extends Node

signal server_message_received(data: Dictionary)
signal login_result(success: bool)

var _socket = WebSocketPeer.new()
var _server_url = "ws://192.168.0.194:8080/game"

var game_time = 0.5 
var my_name = "Guest" 
var my_avatar_id = 0 

func _ready():
	connect_to_server()

func connect_to_server():
	print("Connecting to: ", _server_url)
	var err = _socket.connect_to_url(_server_url)
	if err != OK: set_process(false)

func _process(delta):
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count():
			var packet = _socket.get_packet()
			var json = JSON.parse_string(packet.get_string_from_utf8())
			
			if json:
				var event = json.get("event", "")
				
				# --- LOGIN RESPONSE ---
				if event == "login_response":
					if json.get("success", false):
						my_name = json.get("name", "Unknown")
						my_avatar_id = int(json.get("avatar", 0))
						emit_signal("login_result", true)
					else:
						print("Login Failed: ", json.get("message"))
						emit_signal("login_result", false)

				# --- PROFILE UPDATE ---
				if event == "profile_update_result":
					if json.get("success", false):
						my_name = json.get("name", "Unknown")
						my_avatar_id = int(json.get("avatar", 0))
						# Update local visuals
						var player = get_tree().root.find_child("Player", true, false)
						if player and player.has_method("update_avatar_visuals"):
							player.update_avatar_visuals(my_avatar_id)
						emit_signal("login_result", true) # Re-use signal for UI refresh

				# --- WORLD UPDATE ---
				if event == "position_update":
					if json.has("time"): game_time = json["time"]
					var world = get_tree().root.find_child("World", true, false)
					if world:
						var builder = world.find_child("TileMapLayer", true, false)
						if builder and builder.has_method("update_remote_players") and json.has("players"):
							builder.update_remote_players(json["players"])

				emit_signal("server_message_received", json)
				
	elif _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		await get_tree().create_timer(2.0).timeout
		connect_to_server()

func send_data(data: Dictionary):
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))
func reset_connection():
	print("Resetting connection to fetch fresh world data...")
	_socket.close()
	# Give it a moment to fully close before reconnecting
	await get_tree().create_timer(0.1).timeout
	connect_to_server()

func send_move_request(pos):
	send_data({"action": "request_move", "x": pos.x, "y": pos.y, "seqId": Time.get_ticks_msec()})

func send_interact(x, y):
	send_data({"action": "interact", "x": x, "y": y})

func send_collect_item(item_name):
	send_data({"action": "collect_item", "item": item_name})

func send_remove_item(item_name, amount=1):
	send_data({"action": "remove_item", "item": item_name, "amount": amount})

# --- AUTH ---
func send_login(name_str):
	send_data({"action": "login", "name": name_str})

func send_set_profile(name_str, avatar_idx):
	send_data({"action": "set_profile", "name": name_str, "avatar": int(avatar_idx)})

# --- GAME ---
func send_request_world_objects(): send_data({"action": "request_world_objects"})
func send_place_object(type, x, y): send_data({"action": "place_object", "type": type, "x": x, "y": y})
func send_craft_item(recipe_name): send_data({"action": "craft_item", "recipe": recipe_name})
# --- NEW METHOD: Pickup Object ---
func send_pickup_object(x, y):
	send_data({"action": "pickup_object", "x": x, "y": y})
