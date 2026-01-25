extends Control

signal profile_closed

@onready var name_input = $Panel/VBoxContainer/NameInput
@onready var avatar_container = $Panel/VBoxContainer/AvatarSelector
var selected_avatar_idx = 0

func _ready():
	# Connect Avatar Buttons (Assuming 4 buttons in the container)
	var idx = 0
	for btn in avatar_container.get_children():
		if btn is Button:
			btn.pressed.connect(_on_avatar_selected.bind(idx))
			idx += 1
			
	$Panel/VBoxContainer/SaveButton.pressed.connect(_on_save_pressed)
	$Panel/VBoxContainer/CloseButton.pressed.connect(_on_close_pressed)
	
	# Load current values from the NetworkManager 
	name_input.text = NetworkManager.my_name
	selected_avatar_idx = NetworkManager.my_avatar_id

func _on_avatar_selected(idx):
	selected_avatar_idx = idx
	# Visual feedback: Reset all buttons to dim, highlight selected
	for btn in avatar_container.get_children():
		btn.modulate.a = 0.5
	avatar_container.get_child(idx).modulate.a = 1.0

func _on_save_pressed():
	var new_name = name_input.text.strip_edges()
	# Send the update to the server 
	NetworkManager.send_set_profile(new_name, selected_avatar_idx)
	_on_close_pressed()

func _on_close_pressed():
	emit_signal("profile_closed")
	queue_free()
