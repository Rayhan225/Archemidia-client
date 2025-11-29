extends Node

signal server_message_received(data: Dictionary)

var _socket = WebSocketPeer.new()
var _server_url = "ws://localhost:8080/game"
var game_time = 0.5 

func _ready():
	connect_to_server()

func connect_to_server():
	var err = _socket.connect_to_url(_server_url)
	if err != OK:
		print("Connection Error: ", err)
		set_process(false)

func _process(delta):
	_socket.poll()
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count():
			var packet = _socket.get_packet()
			var json_str = packet.get_string_from_utf8()
			var json = JSON.parse_string(json_str)
			if json:
				if json.has("time"): game_time = json["time"]
				emit_signal("server_message_received", json)
	elif _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		# Simple reconnect logic
		await get_tree().create_timer(2.0).timeout
		connect_to_server()

func send_data(data: Dictionary):
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))

func send_move_request(pos):
	send_data({"action": "request_move", "x": pos.x, "y": pos.y, "seqId": Time.get_ticks_msec()})

func send_interact(x, y):
	send_data({"action": "interact", "x": x, "y": y})

func send_collect_item(item_name):
	send_data({"action": "collect_item", "item": item_name})

func send_remove_item(item_name, amount=1):
	send_data({"action": "remove_item", "item": item_name, "amount": amount})

func send_craft_item(recipe_name):
	send_data({"action": "craft_item", "recipe": recipe_name})

func send_place_object(type, x, y):
	send_data({"action": "place_object", "type": type, "x": x, "y": y})

# --- NEW METHOD: Pickup Object ---
func send_pickup_object(x, y):
	send_data({"action": "pickup_object", "x": x, "y": y})
