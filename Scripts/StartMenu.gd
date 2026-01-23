extends Control

const GAME_SCENE_PATH = "res://world.tscn"

@onready var main_menu = $CanvasLayerUI/MainMenu
@onready var settings_panel = $CanvasLayerUI/SettingsPanel
@onready var btn_play = $CanvasLayerUI/MainMenu/PlayButton
@onready var btn_settings = $CanvasLayerUI/MainMenu/SettingsButton
@onready var btn_quit = $CanvasLayerUI/MainMenu/QuitButton
@onready var btn_close_settings = $CanvasLayerUI/SettingsPanel/Margin/VBox/CloseSettings

func _ready():
	btn_play.pressed.connect(_on_play_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_close_settings.pressed.connect(_on_close_settings_pressed)
	
	main_menu.visible = true
	settings_panel.visible = false

func _on_play_pressed():
	if ResourceLoader.exists(GAME_SCENE_PATH):
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		btn_play.text = "ERROR: Missing world.tscn"

func _on_settings_pressed():
	main_menu.visible = false
	settings_panel.visible = true

func _on_close_settings_pressed():
	settings_panel.visible = false
	main_menu.visible = true

func _on_quit_pressed():
	get_tree().quit()
