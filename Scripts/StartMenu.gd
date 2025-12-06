extends Control

@onready var settings_panel = $SettingsPanel
@onready var buttons_container = $VBoxContainer
@onready var anim_player = $AnimationPlayer

# Path to your main game scene
const GAME_SCENE_PATH = "res://world.tscn"

func _ready():
	# Ensure settings are hidden on start
	settings_panel.visible = false
	
	# Optional: Play background music here
	# $AudioStreamPlayer.play()

func _on_enter_world_pressed():
	# Transition to the main game
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_settings_pressed():
	settings_panel.visible = true
	buttons_container.visible = false

func _on_close_settings_pressed():
	settings_panel.visible = false
	buttons_container.visible = true

func _on_quit_pressed():
	get_tree().quit()

# --- Simple Hover Effects ---
func _on_button_mouse_entered(btn: Button):
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1)
	btn.modulate = Color(1.2, 1.2, 1.2) # Brighter

func _on_button_mouse_exited(btn: Button):
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	btn.modulate = Color(1, 1, 1)
