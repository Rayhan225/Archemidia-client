extends Control

# [FIX] This MUST end in .tscn, not .gd
var ttt_scene = preload("res://tic_tac_toe_window.tscn")
var party_scene = preload("res://party_window.tscn") 

func _ready():
	# Force Centering
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = get_node_or_null("Panel")
	if panel:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.offset_left = -panel.size.x / 2
		panel.offset_top = -panel.size.y / 2
		panel.offset_right = panel.size.x / 2
		panel.offset_bottom = panel.size.y / 2

		# Connect Close Button
		var btn_close = panel.find_child("CloseButton", true, false)
		if btn_close: btn_close.pressed.connect(_on_close_pressed)

		# Connect Tic-Tac-Toe Button
		var btn_ttt = panel.find_child("BtnTicTacToe", true, false)
		if btn_ttt: btn_ttt.pressed.connect(func(): _spawn_game(ttt_scene))
		
		# Connect Party Button
		var btn_party = panel.find_child("BtnParty", true, false)
		if btn_party: btn_party.pressed.connect(func(): _spawn_game(party_scene))



func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func _on_close_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	queue_free()

func _spawn_game(scene_res):
	if scene_res:
		var game_instance = scene_res.instantiate()
		get_tree().root.add_child(game_instance)
		queue_free()
