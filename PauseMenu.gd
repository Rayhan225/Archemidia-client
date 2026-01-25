extends CanvasLayer

@onready var main_container = $MainContainer
@onready var settings_panel = $SettingsPanel
@onready var btn_close_settings = $SettingsPanel/Margin/VBox/CloseSettings

const START_MENU_PATH = "res://StartMenu.tscn"
var profile_scene = preload("res://ProfileUI.tscn")

var player_ref = null

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Lock player input to prevent movement while menu is open 
	player_ref = get_tree().root.find_child("Player", true, false)
	if player_ref and player_ref.has_method("set_input_locked"):
		player_ref.set_input_locked(true)
	
	main_container.visible = true
	settings_panel.visible = false
	
	var vbox = $MainContainer/Panel/VBox
	vbox.get_node("ResumeBtn").pressed.connect(_on_resume_pressed)
	vbox.get_node("SettingsBtn").pressed.connect(_on_settings_pressed)
	vbox.get_node("QuitBtn").pressed.connect(_on_quit_pressed)
	vbox.get_node("ProfileBtn").pressed.connect(_on_profile_pressed)
	btn_close_settings.pressed.connect(_on_close_settings_pressed)

func _exit_tree():
	# Unlock player when the pause menu is closed 
	if player_ref and is_instance_valid(player_ref) and player_ref.has_method("set_input_locked"):
		player_ref.set_input_locked(false)

func _on_resume_pressed():
	queue_free()

func _on_profile_pressed():
	var profile = profile_scene.instantiate()
	add_child(profile)
	main_container.visible = false
	profile.profile_closed.connect(func(): main_container.visible = true)

func _on_settings_pressed():
	main_container.visible = false
	settings_panel.visible = true

func _on_close_settings_pressed():
	settings_panel.visible = false
	main_container.visible = true

func _on_quit_pressed():
	NetworkManager.reset_connection()
	get_tree().change_scene_to_file(START_MENU_PATH)
	queue_free()
