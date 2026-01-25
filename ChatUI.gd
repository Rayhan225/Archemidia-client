extends Control

@onready var chat_display = $Panel/VBox/RichTextLabel
@onready var input_field = $Panel/VBox/HBox/LineEdit
@onready var send_btn = $Panel/VBox/HBox/SendButton
@onready var friend_list_container = $FriendPanel/Scroll/VBox
@onready var tab_container = $Panel/VBox/TabBox

var current_mode = "GLOBAL" # GLOBAL or PRIVATE
var private_target = ""

func _ready():
	NetworkManager.server_message_received.connect(_on_server_message)
	send_btn.pressed.connect(_on_send_pressed)
	input_field.text_submitted.connect(func(t): _on_send_pressed())
	
	# Initial UI State
	add_message("System", "Welcome " + NetworkManager.my_name + "!", "SYSTEM")
	_update_input_placeholder()

func _on_send_pressed():
	var text = input_field.text.strip_edges()
	if text == "": return
	
	# COMMANDS
	if text.begins_with("/add "):
		var target = text.replace("/add ", "").strip_edges()
		# Send Friend Request BY NAME
		NetworkManager.send_data({"action": "friend_request", "targetName": target})
		add_message("System", "Sending friend request to " + target + "...", "SYSTEM")
		
	elif text.begins_with("/accept "):
		var target = text.replace("/accept ", "").strip_edges()
		# Accept Friend Request BY NAME
		NetworkManager.send_data({"action": "friend_accept", "targetName": target})
		
	else:
		# Standard Chat
		if current_mode == "GLOBAL":
			NetworkManager.send_data({
				"action": "chat_send", 
				"type": "GLOBAL", 
				"message": text
			})
		elif current_mode == "PRIVATE":
			if private_target == "":
				add_message("System", "No private chat target selected.", "SYSTEM")
			else:
				NetworkManager.send_data({
					"action": "chat_send", 
					"type": "PRIVATE", 
					"target": private_target, # This is now a Name
					"message": text
				})
				
	input_field.text = ""
	input_field.release_focus() # Unfocus so user can move again

func _on_server_message(data):
	var event = data.get("event")
	
	if event == "chat_message":
		add_message(data["sender"], data["text"], data["type"])
		
	elif event == "friend_update":
		_refresh_friend_list(data.get("friends", []), data.get("requests", []))

func add_message(sender, text, type):
	var color = "white"
	if type == "SYSTEM": color = "yellow"
	elif type == "PRIVATE": color = "magenta"
	elif type == "GLOBAL": color = "cyan"
	
	var timestamp = Time.get_time_string_from_system().substr(0, 5) # HH:MM
	var bbcode = "[color=#888][%s][/color] [color=%s][b]%s:[/b] %s[/color]" % [timestamp, color, sender, text]
	
	chat_display.append_text(bbcode + "\n")

func _refresh_friend_list(friends, requests):
	# Clear old list
	for c in friend_list_container.get_children(): c.queue_free()
	
	# 1. Pending Requests (Now contains NAMES)
	if requests.size() > 0:
		var header = Label.new()
		header.text = "-- REQUESTS --"
		header.add_theme_color_override("font_color", Color.YELLOW)
		friend_list_container.add_child(header)
		
		for req_name in requests:
			var row = HBoxContainer.new()
			var lbl = Label.new(); lbl.text = str(req_name); lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var btn = Button.new(); btn.text = "Accept"
			btn.pressed.connect(func(): 
				NetworkManager.send_data({"action": "friend_accept", "targetName": req_name})
			)
			row.add_child(lbl)
			row.add_child(btn)
			friend_list_container.add_child(row)
		
		friend_list_container.add_child(HSeparator.new())

	# 2. Friends (Now contains NAMES)
	for f_name in friends:
		var btn = Button.new()
		btn.text = "Chat: " + str(f_name)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _switch_to_private(f_name))
		friend_list_container.add_child(btn)

func _switch_to_private(target_name):
	current_mode = "PRIVATE"
	private_target = target_name
	_update_input_placeholder()
	
	# Optionally auto-focus input
	input_field.grab_focus()

func _on_global_tab_pressed():
	current_mode = "GLOBAL"
	private_target = ""
	_update_input_placeholder()

func _update_input_placeholder():
	if current_mode == "GLOBAL":
		input_field.placeholder_text = "[Global] Type message..."
	else:
		input_field.placeholder_text = "[Private -> " + private_target + "] Type message..."
