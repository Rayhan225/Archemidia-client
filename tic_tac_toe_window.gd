extends CanvasLayer

# --- SCENE REFERENCES ---
# [FIX] Preload the Hub so we can go back to it
var hub_scene = preload("res://game_hub_ui.tscn")

# --- UI ELEMENTS ---
var center_container: CenterContainer
var bg_panel: Panel
var board_control: Control
var status_lbl: Label
var close_btn: Button
var reset_btn: Button

# --- GAME STATE ---
var board_state = [0,0,0, 0,0,0, 0,0,0] 
var game_active = true

func _ready():
	# Ensure this layer sits on top of everything
	layer = 101 
	
	# 1. SETUP LAYOUT ROOTS
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.4)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_STOP 
	add_child(center_container)
	
	# 2. SETUP WINDOW PANEL
	bg_panel = Panel.new()
	bg_panel.name = "BG"
	bg_panel.custom_minimum_size = Vector2(320, 420) 
	center_container.add_child(bg_panel)
	
	# 3. SETUP INNER UI
	status_lbl = Label.new()
	status_lbl.text = "Player vs AI"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.size = Vector2(320, 30)
	status_lbl.position = Vector2(0, 10)
	bg_panel.add_child(status_lbl)
	
	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(30, 30)
	close_btn.position = Vector2(285, 5)
	close_btn.pressed.connect(_close_game)
	bg_panel.add_child(close_btn)
	
	board_control = Control.new()
	board_control.custom_minimum_size = Vector2(300, 300)
	board_control.position = Vector2(10, 50)
	board_control.mouse_filter = Control.MOUSE_FILTER_STOP 
	bg_panel.add_child(board_control)
	
	reset_btn = Button.new()
	reset_btn.text = "PLAY AGAIN"
	reset_btn.size = Vector2(200, 40)
	reset_btn.position = Vector2(60, 365)
	reset_btn.visible = false
	reset_btn.pressed.connect(_on_reset_pressed)
	bg_panel.add_child(reset_btn)

	# 4. CONNECT SIGNALS
	if not NetworkManager.server_message_received.is_connected(_on_server_event):
		NetworkManager.server_message_received.connect(_on_server_event)
	
	board_control.draw.connect(_on_draw_board)
	board_control.gui_input.connect(_on_board_input)
	
	# Start Game
	NetworkManager.send_data({"action": "start_ttt"})

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_close_game()

func _close_game():
	# [FIX] Spawn the Hub again before closing this window
	var hub = hub_scene.instantiate()
	get_tree().root.add_child(hub)
	queue_free()

func _on_reset_pressed():
	# 1. Send Reset Command
	NetworkManager.send_data({"action": "reset_ttt"})
	
	# 2. Reset Local State Immediately
	game_active = true
	board_state = [0,0,0, 0,0,0, 0,0,0]
	status_lbl.text = "Player vs AI"
	status_lbl.modulate = Color.WHITE
	reset_btn.visible = false
	board_control.queue_redraw()

func _on_server_event(data):
	if data.get("event") == "ttt_update":
		board_state = data.get("board", [])
		board_control.queue_redraw()
		
		if data.has("winner"):
			game_active = false
			var w = data["winner"]
			if w == "Draw": 
				status_lbl.text = "It's a Draw!"
				status_lbl.modulate = Color(1, 1, 0) 
			elif w == "AI": 
				status_lbl.text = "AI Wins!"
				status_lbl.modulate = Color(1, 0.3, 0.3) 
			else: 
				status_lbl.text = "You Won!"
				status_lbl.modulate = Color(0.3, 1, 0.3) 
			
			reset_btn.visible = true

func _on_board_input(event):
	if not game_active: return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var size = board_control.custom_minimum_size
		var cell_w = size.x / 3.0
		var cell_h = size.y / 3.0
		var col = int(event.position.x / cell_w)
		var row = int(event.position.y / cell_h)
		var idx = row * 3 + col
		
		if idx >= 0 and idx < 9 and board_state[idx] == 0:
			board_state[idx] = 1 
			board_control.queue_redraw()
			NetworkManager.send_data({"action": "move_ttt", "index": idx})

func _on_draw_board():
	var canvas = board_control
	var w = board_control.custom_minimum_size.x
	var h = board_control.custom_minimum_size.y
	var col_grid = Color(1, 1, 1, 0.5)
	var col_x = Color(0.2, 0.8, 1.0, 1.0)
	var col_o = Color(1.0, 0.4, 0.4, 1.0)
	var thick = 4.0
	var pad = 20.0

	canvas.draw_line(Vector2(w/3, 0), Vector2(w/3, h), col_grid, thick)
	canvas.draw_line(Vector2(w*2/3, 0), Vector2(w*2/3, h), col_grid, thick)
	canvas.draw_line(Vector2(0, h/3), Vector2(w, h/3), col_grid, thick)
	canvas.draw_line(Vector2(0, h*2/3), Vector2(w, h*2/3), col_grid, thick)

	var cell_w = w / 3
	var cell_h = h / 3
	for i in range(9):
		var val = int(board_state[i])
		if val == 0: continue
		var col = i % 3
		var row = floor(i / 3)
		var center = Vector2(col * cell_w + cell_w/2, row * cell_h + cell_h/2)
		if val == 1: 
			var start_x = center.x - cell_w/2 + pad
			var end_x = center.x + cell_w/2 - pad
			var start_y = center.y - cell_h/2 + pad
			var end_y = center.y + cell_h/2 - pad
			canvas.draw_line(Vector2(start_x, start_y), Vector2(end_x, end_y), col_x, 6.0)
			canvas.draw_line(Vector2(end_x, start_y), Vector2(start_x, end_y), col_x, 6.0)
		elif val == 2:
			var radius = min(cell_w, cell_h) / 2 - pad
			canvas.draw_arc(center, radius, 0, TAU, 32, col_o, 5.0)
