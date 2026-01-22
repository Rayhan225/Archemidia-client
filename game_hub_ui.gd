extends Control

var ttt_scene = preload("res://tic_tac_toe_window.tscn")

func _ready():
	# --- 1. FORCE UI CENTERING ---
	# We set the root control to cover the whole screen (to block clicks behind it)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Find the background panel (ensure your node is named "Panel" in the scene!)
	var panel = get_node_or_null("Panel")
	if panel:
		# Set a fixed size for the hub
		panel.custom_minimum_size = Vector2(400, 300)
		panel.size = Vector2(400, 300)
		
		# Calculate the exact center position
		# (Viewport Size / 2) - (Panel Size / 2)
		var viewport_size = get_viewport_rect().size
		panel.position = (viewport_size / 2) - (panel.size / 2)
		
		# [FIXED] Use PRESET_TOP_LEFT. This frees the anchors so 'position' works manually.
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)

	# --- 2. WIRE UP BUTTONS ---
	# We look inside the panel for the buttons
	if panel:
		var btn_close = panel.find_child("CloseButton", true, false)
		if btn_close: btn_close.pressed.connect(_on_close_pressed)

		var btn_ttt = panel.find_child("BtnTicTacToe", true, false)
		if btn_ttt: btn_ttt.pressed.connect(_on_ttt_pressed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func _on_close_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	queue_free()

func _on_ttt_pressed():
	var game = ttt_scene.instantiate()
	# Add to the CURRENT scene root (GameUI's parent usually)
	# This ensures it floats above everything else
	get_tree().root.add_child(game)
	queue_free()
