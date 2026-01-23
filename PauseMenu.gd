extends CanvasLayer

@onready var main_container = $MainContainer
@onready var settings_panel = $SettingsPanel

# Scene to load when quitting
const START_MENU_PATH = "res://StartMenu.tscn"

# Track the player to lock/unlock them
var player_ref = null
# Store previous mouse state to restore it later
var previous_mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready():
	# 1. Capture current mouse state so we can restore it
	previous_mouse_mode = Input.mouse_mode
	
	# 2. FORCE MOUSE VISIBLE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 3. Lock Player Input
	player_ref = get_tree().root.find_child("Player", true, false)
	if player_ref and player_ref.has_method("set_input_locked"):
		player_ref.set_input_locked(true)
	
	# 4. Setup Initial UI State
	main_container.visible = true
	settings_panel.visible = false
	
	# 5. Connect Buttons
	$MainContainer/VBox/ResumeBtn.pressed.connect(_on_resume_pressed)
	$MainContainer/VBox/SettingsBtn.pressed.connect(_on_settings_pressed)
	$MainContainer/VBox/QuitBtn.pressed.connect(_on_quit_pressed)
	$SettingsPanel/Margin/VBox/CloseSettings.pressed.connect(_on_close_settings)

func _exit_tree():
	# CRITICAL: Unlock player when menu closes
	if player_ref and is_instance_valid(player_ref) and player_ref.has_method("set_input_locked"):
		player_ref.set_input_locked(false)
	
	# RESTORE MOUSE STATE (If your game hides it during gameplay)
	# If you want the mouse ALWAYS visible during gameplay, you can remove this line.
	# Input.mouse_mode = previous_mouse_mode 

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_on_close_settings()
		else:
			_on_resume_pressed()

func _on_resume_pressed():
	queue_free() # Destroys menu -> triggers _exit_tree

func _on_settings_pressed():
	main_container.visible = false
	settings_panel.visible = true

func _on_close_settings():
	settings_panel.visible = false
	main_container.visible = true

func _on_quit_pressed():
	# Unlock player before leaving just in case
	if player_ref and player_ref.has_method("set_input_locked"):
		player_ref.set_input_locked(false)
	
	# Ensure mouse is visible for the main menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	get_tree().change_scene_to_file(START_MENU_PATH)
