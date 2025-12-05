extends CanvasLayer

# References to scene nodes
@onready var inventory_window = $InventoryWindow
@onready var inv_panel = $InventoryWindow/Panel
@onready var inv_grid = $InventoryWindow/Panel/GridContainer

# UI Elements
var crafting_window: Panel
var building_slots = []
var remove_button: Button 
var slot_scene = preload("res://Slot.tscn")
var selected_slot = null 

# Hotbar Elements
var hotbar_container: HBoxContainer
var hotbar_slots = []
var active_hotbar_index = -1

# Health Bar Elements
var health_bar_container: PanelContainer
var heart_nodes = []
var heart_texture = preload("res://heart pixel art 16x16.png")

# Time & Day UI
var time_label: Label
var day_count = 1
var last_game_time = 0.0

# Pickup Notification
var pickup_container: VBoxContainer
var previous_inventory = {}
var active_pickups = {}

# Placement Hologram
var placement_mode = false
var placement_type = ""
var hologram: Sprite2D

var was_i_pressed = false

# Font Resource
var pixel_font: FontFile = null 

# --- STYLING CONSTANTS ---
const COL_TEXT_MAIN = Color(0.98, 0.98, 0.95, 1.0) # Cream White
const COL_TEXT_GOLD = Color(1.0, 0.9, 0.6, 1.0)    # Soft Gold (Hotbar numbers)
const COL_OUTLINE = Color(0.05, 0.05, 0.05, 1.0)   # Near Black
const OUTLINE_SIZE = 4

# Item Categories
const CAT_BUILDINGS = ["Fence", "Bonfire", "Crafting Table"]
const CAT_WEAPONS = ["Sword", "Bow"]
const CAT_TOOLS = ["Pickaxe"]

func _ready():
	NetworkManager.server_message_received.connect(_on_server_message)
	
	if ResourceLoader.exists("res://Assets/pixel.ttf"):
		pixel_font = load("res://Assets/pixel.ttf")
	
	if inventory_window:
		inventory_window.visible = false
		if inv_grid: inv_grid.columns = 8
		inventory_window.position.y -= 150 
		
	create_building_slots() 
	create_remove_button()
	create_crafting_ui()
	create_hotbar_ui()
	create_health_ui() 
	create_pickup_ui() 
	create_clock_ui() 
	
	hologram = Sprite2D.new()
	hologram.modulate = Color(1, 1, 1, 0.5) 
	hologram.z_index = 100 
	hologram.visible = false
	
	var world = get_tree().root.find_child("World", true, false)
	if world:
		var objects = world.find_child("Objects", true, false)
		if objects: objects.add_child(hologram)
		else: world.add_child(hologram)
	else:
		add_child(hologram) 
	
	update_inventory_display({})
	
	var title = Label.new()
	title.text = "INVENTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(100, -40)
	title.size = Vector2(300, 30)
	_apply_text_style(title) # Apply Style
	if pixel_font: title.add_theme_font_override("font", pixel_font)
	inventory_window.add_child(title)
	
	update_cursor_state()

# --- HELPER: APPLY UNIFIED TEXT STYLE ---
func _apply_text_style(lbl: Label, color: Color = COL_TEXT_MAIN):
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", COL_OUTLINE)
	lbl.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	# Removing modulate to let font_color take full effect cleanly
	lbl.modulate = Color(1, 1, 1, 1) 

func update_cursor_state():
	if inventory_window.visible or crafting_window.visible or placement_mode:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func create_clock_ui():
	var panel = PanelContainer.new()
	panel.name = "ClockPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(10, 10) 
	
	time_label = Label.new()
	time_label.text = "Day 1 - 06:00 AM"
	time_label.add_theme_font_size_override("font_size", 16)
	_apply_text_style(time_label) # Apply Style
	if pixel_font: time_label.add_theme_font_override("font", pixel_font)
	panel.add_child(time_label)
	
	add_child(panel)

func update_clock(server_time):
	if server_time < last_game_time and last_game_time > 0.8:
		day_count += 1
	last_game_time = server_time
	
	var total_minutes = int(server_time * 24 * 60)
	var hours = int(total_minutes / 60)
	var minutes = total_minutes % 60
	
	var period = "AM"
	if hours >= 12:
		period = "PM"
	if hours > 12:
		hours -= 12
	if hours == 0:
		hours = 12
		
	var time_str = "%02d:%02d %s" % [hours, minutes, period]
	time_label.text = "Day %d - %s" % [day_count, time_str]

func create_pickup_ui():
	pickup_container = VBoxContainer.new()
	pickup_container.name = "PickupContainer"
	pickup_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	pickup_container.position.x = -10 
	pickup_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pickup_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	pickup_container.add_theme_constant_override("separation", 5)
	add_child(pickup_container)

func show_pickup_notification(item_name, count):
	if active_pickups.has(item_name):
		var info = active_pickups[item_name]
		info.count += int(count)
		var label = info.node.get_node("HBoxContainer/Label")
		label.text = item_name + " x" + str(info.count)
		
		if info.tween: info.tween.kill()
		
		var icon = info.node.get_node("HBoxContainer/Icon")
		var t_pop = create_tween()
		t_pop.tween_property(icon, "scale", Vector2(1.4, 1.4), 0.1)
		t_pop.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)
		
		info.node.modulate.a = 1.0
		
		var t = create_tween()
		t.tween_interval(2.5) 
		t.tween_property(info.node, "modulate:a", 0.0, 0.5) 
		t.tween_callback(func(): _remove_popup_data(item_name))
		t.tween_callback(info.node.queue_free)
		info.tween = t
	else:
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.6)
		style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox = HBoxContainer.new()
		hbox.name = "HBoxContainer"
		panel.add_child(hbox)
		
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.pivot_offset = Vector2(12, 12) 
		
		var path = "res://Assets/icons/" + item_name + ".png"
		if item_name == "Crafting Table": path = "res://Assets/Crafting Table.png"
		elif item_name == "Pickaxe": path = "res://Assets/pickaxe-iron.png"
		elif item_name == "Bonfire": path = "res://Assets/Bonfire_02-Sheet.png"
		elif item_name == "Fence": path = "res://Assets/FENCE 1 - DAY.png"
		
		if ResourceLoader.exists(path):
			icon.texture = load(path)
			if item_name == "Bonfire" and icon.texture:
				var atlas = AtlasTexture.new()
				atlas.atlas = icon.texture
				atlas.region = Rect2(0, 0, 32, 32)
				icon.texture = atlas
		
		hbox.add_child(icon)
		
		var lbl = Label.new()
		lbl.name = "Label"
		lbl.text = item_name + " x" + str(int(count))
		lbl.add_theme_font_size_override("font_size", 12)
		
		# --- STYLE PICKUP ---
		_apply_text_style(lbl)
		if pixel_font: lbl.add_theme_font_override("font", pixel_font)
		
		hbox.add_child(lbl)
		
		pickup_container.add_child(panel)
		
		var t = create_tween()
		t.tween_interval(2.5) 
		t.tween_property(panel, "modulate:a", 0.0, 0.5) 
		t.tween_callback(func(): _remove_popup_data(item_name)) 
		t.tween_callback(panel.queue_free)
		
		active_pickups[item_name] = { "node": panel, "count": int(count), "tween": t }

func _remove_popup_data(item_name):
	if active_pickups.has(item_name):
		active_pickups.erase(item_name)

func create_health_ui():
	health_bar_container = PanelContainer.new()
	health_bar_container.name = "HealthBarPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5) 
	style.set_corner_radius_all(5)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	health_bar_container.add_theme_stylebox_override("panel", style)
	
	health_bar_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	health_bar_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	health_bar_container.offset_left = 0
	health_bar_container.offset_right = 0
	health_bar_container.position.y = 10
	
	add_child(health_bar_container)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2) 
	health_bar_container.add_child(hbox)
	
	for i in range(5):
		var heart = TextureProgressBar.new()
		heart.texture_progress = heart_texture
		heart.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
		heart.min_value = 0
		heart.max_value = 20 
		heart.value = 20
		heart.custom_minimum_size = Vector2(16, 16) 
		hbox.add_child(heart)
		heart_nodes.append(heart)

func update_health_display(current_hp):
	for i in range(5):
		var heart = heart_nodes[i]
		var heart_min = i * 20
		var heart_max = (i + 1) * 20
		
		if current_hp >= heart_max:
			heart.value = 20 
		elif current_hp <= heart_min:
			heart.value = 0 
		else:
			heart.value = current_hp - heart_min

func create_hotbar_ui():
	var panel = PanelContainer.new()
	panel.name = "HotbarPanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position.y -= 50
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	
	hotbar_container = HBoxContainer.new()
	hotbar_container.add_theme_constant_override("separation", 2)
	panel.add_child(hotbar_container)
	
	for i in range(9):
		var s = slot_scene.instantiate()
		s.custom_minimum_size = Vector2(40, 40) 
		s.name = "HotbarSlot_" + str(i+1)
		s.connect("slot_selected", _on_hotbar_click.bind(i))
		
		var num_lbl = Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		num_lbl.position = Vector2(2, 0)
		num_lbl.add_theme_font_size_override("font_size", 8) 
		
		# --- STYLE HOTBAR NUMBERS ---
		_apply_text_style(num_lbl, COL_TEXT_GOLD)
		if pixel_font: num_lbl.add_theme_font_override("font", pixel_font)
		
		s.add_child(num_lbl)
		
		hotbar_container.add_child(s)
		hotbar_slots.append(s)

func create_building_slots():
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(-140, 20) 
	vbox.add_theme_constant_override("separation", 5)
	inv_panel.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "BUILDING"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	_apply_text_style(lbl, COL_TEXT_GOLD)
	if pixel_font: lbl.add_theme_font_override("font", pixel_font)
	vbox.add_child(lbl)
	
	for i in range(5):
		var s = slot_scene.instantiate()
		s.custom_minimum_size = Vector2(55, 55) 
		s.connect("slot_selected", _on_slot_selected)
		vbox.add_child(s)
		building_slots.append(s)

func create_remove_button():
	remove_button = Button.new()
	remove_button.text = "X"
	remove_button.size = Vector2(40, 40)
	remove_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	remove_button.position = Vector2(470, 250) 
	
	remove_button.pressed.connect(_on_remove_button_pressed)
	remove_button.disabled = true
	inv_panel.add_child(remove_button)

func create_crafting_ui():
	crafting_window = Panel.new()
	crafting_window.name = "CraftingWindow"
	crafting_window.size = Vector2(300, 320) 
	
	var vp_size = get_viewport().get_visible_rect().size
	crafting_window.position = (vp_size / 2) - (crafting_window.size / 2)
	crafting_window.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5) 
	style.set_corner_radius_all(5)
	crafting_window.add_theme_stylebox_override("panel", style)
	add_child(crafting_window)
	
	var title = Label.new()
	title.text = "WORKBENCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 10)
	title.size = Vector2(300, 30)
	
	_apply_text_style(title, COL_TEXT_GOLD)
	if pixel_font: title.add_theme_font_override("font", pixel_font)
	
	crafting_window.add_child(title)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(25, 50)
	vbox.size = Vector2(250, 240)
	vbox.add_theme_constant_override("separation", 10)
	crafting_window.add_child(vbox)
	
	var btn_pick = Button.new()
	btn_pick.text = "Craft Pickaxe\n(3 Wood, 2 Stone, 1 Rope)"
	btn_pick.custom_minimum_size = Vector2(0, 50)
	apply_craft_btn_style(btn_pick)
	btn_pick.pressed.connect(func(): _craft_item("Pickaxe"))
	vbox.add_child(btn_pick)
	
	var btn_bonfire = Button.new()
	btn_bonfire.text = "Craft Bonfire\n(10 Wood, 5 Stone)"
	btn_bonfire.custom_minimum_size = Vector2(0, 50)
	apply_craft_btn_style(btn_bonfire)
	btn_bonfire.pressed.connect(func(): _craft_item("Bonfire"))
	vbox.add_child(btn_bonfire)

	var btn_fence = Button.new()
	btn_fence.text = "Craft Fence\n(2 Wood)"
	btn_fence.custom_minimum_size = Vector2(0, 50)
	apply_craft_btn_style(btn_fence)
	btn_fence.pressed.connect(func(): _craft_item("Fence"))
	vbox.add_child(btn_fence)
	
	var hint = Label.new()
	hint.text = "Press C to Close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 290)
	hint.size = Vector2(300, 20)
	_apply_text_style(hint)
	if pixel_font: hint.add_theme_font_override("font", pixel_font)
	crafting_window.add_child(hint)

func apply_craft_btn_style(btn):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.598, 0.441, 0.049, 1.0) 
	style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	if pixel_font: btn.add_theme_font_override("font", pixel_font)
	# Also style button text? Button uses internal label, hard to target directly without theme.
	# But generally overrides propagate.

func _process(delta):
	if Input.is_key_pressed(KEY_I):
		if not was_i_pressed:
			toggle_inventory()
		was_i_pressed = true
	else:
		was_i_pressed = false
	
	if placement_mode and hologram:
		var world = get_tree().root.find_child("TileMapLayer", true, false)
		if world:
			var mouse_pos = get_viewport().get_mouse_position()
			var local_pos = world.to_local(get_viewport().canvas_transform.affine_inverse() * mouse_pos)
			var map_pos = world.local_to_map(local_pos)
			var snap_pos = world.map_to_local(map_pos)
			
			hologram.global_position = world.to_global(snap_pos)
			
			if world.has_method("is_tile_placeable"):
				if world.is_tile_placeable(map_pos):
					hologram.modulate = Color(0, 1, 0, 0.6) 
				else:
					hologram.modulate = Color(1, 0, 0, 0.6) 

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if placement_mode:
			stop_placement_mode()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var index = event.keycode - KEY_1
			select_hotbar_slot(index)
		elif event.keycode == KEY_H:
			_unequip_all()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if placement_mode:
			_confirm_placement_at_hologram()

func _unequip_all():
	if active_hotbar_index != -1 and active_hotbar_index < hotbar_slots.size():
		hotbar_slots[active_hotbar_index].deselect()
	
	active_hotbar_index = -1
	stop_placement_mode()
	
	var player = get_tree().root.find_child("Player", true, false)
	if player: player.unequip_item()
	
	update_cursor_state()

func select_hotbar_slot(index):
	if active_hotbar_index == index:
		_unequip_current_slot()
		return

	if active_hotbar_index >= 0 and active_hotbar_index < hotbar_slots.size():
		hotbar_slots[active_hotbar_index].deselect()
	
	active_hotbar_index = index
	var slot = hotbar_slots[index]
	slot.select()
	
	stop_placement_mode() 
	
	if slot.data:
		var item_name = slot.data["name"]
		if item_name in CAT_BUILDINGS:
			var player = get_tree().root.find_child("Player", true, false)
			if player: player.unequip_item()
			start_placement_mode(item_name)
		else:
			var player = get_tree().root.find_child("Player", true, false)
			if player: player.equip_item(slot.icon.texture)
	else:
		var player = get_tree().root.find_child("Player", true, false)
		if player: player.unequip_item()
	
	update_cursor_state()

func _unequip_current_slot():
	if active_hotbar_index != -1 and active_hotbar_index < hotbar_slots.size():
		hotbar_slots[active_hotbar_index].deselect()
	
	active_hotbar_index = -1
	stop_placement_mode()
	
	var player = get_tree().root.find_child("Player", true, false)
	if player: player.unequip_item()
	
	update_cursor_state()

func _on_hotbar_click(slot_ref, index):
	select_hotbar_slot(index)

func start_placement_mode(type):
	placement_mode = true
	placement_type = type
	
	var path = "res://Assets/Crafting Table.png"
	if type == "Bonfire": path = "res://Assets/Bonfire_02-Sheet.png"
	elif type == "Fence": path = "res://Assets/FENCE 1 - DAY.png"
	
	if ResourceLoader.exists(path):
		var tex = load(path)
		if type == "Bonfire":
			var atlas = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(0, 0, 32, 32)
			hologram.texture = atlas
			hologram.offset = Vector2(0, -12)
		elif type == "Fence":
			hologram.texture = tex
			hologram.offset = Vector2(0, -16)
		else:
			hologram.texture = tex
			hologram.offset = Vector2(0, -2)
			
	hologram.visible = true
	update_cursor_state()

func stop_placement_mode():
	placement_mode = false
	if hologram: hologram.visible = false
	update_cursor_state()

func _confirm_placement_at_hologram():
	if !hologram or !hologram.visible: return
	
	var world = get_tree().root.find_child("TileMapLayer", true, false)
	if world:
		var map_pos = world.local_to_map(world.to_local(hologram.global_position))
		if world.is_tile_placeable(map_pos):
			NetworkManager.send_place_object(placement_type, map_pos.x, map_pos.y)

func _on_server_message(data):
	var event = data.get("event", "")
	if event == "inventory_update":
		var new_items = data["items"]
		detect_and_show_pickups(new_items)
		update_inventory_display(new_items)
		previous_inventory = new_items.duplicate()
	elif event == "open_crafting":
		toggle_crafting(true)
	elif event == "position_update" and data.has("hp"):
		update_health_display(data["hp"])
		
		var player = get_tree().root.find_child("Player", true, false)
		if player and player.has_method("_on_take_damage_check"):
			player._on_take_damage_check(data["hp"])

func detect_and_show_pickups(new_items):
	for item_name in new_items:
		var new_count = new_items[item_name]
		var old_count = previous_inventory.get(item_name, 0)
		if new_count > old_count:
			var diff = new_count - old_count
			show_pickup_notification(item_name, diff)

func toggle_inventory():
	inventory_window.visible = !inventory_window.visible
	if !inventory_window.visible: 
		_on_slot_selected(null)
	if placement_mode: stop_placement_mode()
	update_cursor_state()

func toggle_crafting(show):
	crafting_window.visible = show
	if show and placement_mode: stop_placement_mode()
	update_cursor_state()

func update_inventory_display(items):
	for s in hotbar_slots:
		if s.data:
			var name = s.data["name"]
			if items.has(name):
				s.set_item({"name": name, "count": int(items[name])})
			else:
				s.set_item(null)
				if s.is_selected: 
					_unequip_current_slot()

	for s in building_slots: s.set_item(null)
	var build_idx = 0
	for k in items:
		if k in CAT_BUILDINGS:
			if build_idx < building_slots.size():
				building_slots[build_idx].set_item({"name": k, "count": int(items[k])})
				build_idx += 1

	var current_slots = inv_grid.get_children()
	while current_slots.size() < 24:
		var s = slot_scene.instantiate()
		s.custom_minimum_size = Vector2(60, 60)
		s.connect("slot_selected", _on_slot_selected)
		inv_grid.add_child(s)
		current_slots = inv_grid.get_children()
	
	for s in current_slots: s.set_item(null)
	
	var main_idx = 0
	for k in items:
		if k in CAT_BUILDINGS: continue
		
		if main_idx < current_slots.size():
			var item_data = {"name": k, "count": int(items[k])}
			current_slots[main_idx].set_item(item_data)
			main_idx += 1

func _on_slot_selected(slot):
	if slot == null:
		if selected_slot: selected_slot.deselect()
		selected_slot = null
		remove_button.disabled = true
		return

	if selected_slot and is_instance_valid(selected_slot) and selected_slot != slot:
		selected_slot.deselect()
	
	if slot.is_selected:
		selected_slot = slot
		remove_button.disabled = false
	else:
		selected_slot = null
		remove_button.disabled = true

func _on_remove_button_pressed():
	if selected_slot and selected_slot.data:
		NetworkManager.send_data({"action": "drop_item", "item": selected_slot.data["name"]})

func _craft_item(recipe):
	NetworkManager.send_craft_item(recipe)
