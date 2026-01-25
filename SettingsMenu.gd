extends PanelContainer

@onready var master_slider = $Margin/VBox/TabContainer/Audio/MasterVol/MasterSlider
@onready var controls_grid = $Margin/VBox/TabContainer/Controls/Grid
@onready var btn_close_settings = $CanvasLayerUI/SettingsPanel/Margin/VBox/CloseSettings

var remap_actions = [
	["ui_up", "Move Up"],
	["ui_down", "Move Down"],
	["ui_left", "Move Left"],
	["ui_right", "Move Right"],
	["ui_accept", "Interact / Attack"],
	["ui_cancel", "Open Menu"]
]

var active_remap_button: Button = null

func _ready():
	var master_idx = AudioServer.get_bus_index("Master")
	master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_idx))
	master_slider.value_changed.connect(_on_master_vol_changed)
	_populate_controls_list()

func _on_master_vol_changed(value):
	var idx = AudioServer.get_bus_index("Master")
	if value <= 0.05: AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _populate_controls_list():
	for c in controls_grid.get_children(): c.queue_free()
	for action_data in remap_actions:
		var lbl = Label.new()
		lbl.text = action_data[1]
		controls_grid.add_child(lbl)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 40)
		btn.toggle_mode = true
		btn.text = _get_current_key_text(action_data[0])
		btn.pressed.connect(func(): _on_remap_button_pressed(btn, action_data[0]))
		controls_grid.add_child(btn)

func _get_current_key_text(action):
	var events = InputMap.action_get_events(action)
	if events.size() > 0: return events[0].as_text().split(" (")[0]
	return "None"

func _on_remap_button_pressed(btn, action):
	if active_remap_button == btn: _cancel_remap(); return
	if active_remap_button: _cancel_remap()
	active_remap_button = btn
	btn.set_meta("action", action)
	btn.text = "Press Key..."

func _input(event):
	if active_remap_button and event is InputEventKey and event.pressed:
		var action = active_remap_button.get_meta("action")
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)
		active_remap_button.text = event.as_text().split(" (")[0]
		active_remap_button.button_pressed = false
		active_remap_button = null
		get_viewport().set_input_as_handled()

func _cancel_remap():
	if active_remap_button:
		active_remap_button.button_pressed = false
		active_remap_button.text = _get_current_key_text(active_remap_button.get_meta("action"))
		active_remap_button = null
