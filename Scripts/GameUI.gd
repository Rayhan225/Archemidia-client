extends CanvasLayer

# References to scene nodes
@onready var inventory_window = $InventoryWindow
@onready var inv_panel = $InventoryWindow/Panel
@onready var inv_grid = $InventoryWindow/Panel/GridContainer

# UI Elements
var crafting_window: Panel
# [UPDATED] Building Slots Array
var building_slots = [] 
var remove_button: Button 
var slot_scene = preload("res://Slot.tscn")
var selected_slot = null 

# Hotbar Elements
var hotbar_container: HBoxContainer
var hotbar_slots = []
var active_hotbar_index = -1

# Health Bar Elements
var health_container: HBoxContainer
var heart_texture = preload("res://heart pixel art 16x16.png")
var heart_clippers = [] 

# Pickup Notification
var pickup_container: VBoxContainer
var previous_inventory = {}

# [NEW] Placement Hologram
var placement_mode = false
var placement_type = ""
var hologram: Sprite2D

var was_i_pressed = false

func _ready():
	NetworkManager.server_message_received.connect(_on_server_message)
	
	if inventory_window:
		inventory_window.visible = false
		if inv_grid: inv_grid.columns = 8
		
	create_building_slots() # [UPDATED]
	create_remove_button()
	create_crafting_ui()
	create_hotbar_ui()
	create_health_ui()
	create_pickup_ui() 
	
	# Create Hologram Node
	hologram = Sprite2D.new()
	hologram.modulate = Color(1, 1, 1, 0.5) # Transparent
	hologram.z_index = 100 # Always on top
	hologram.visible = false
	# Add to World, not UI, so it follows camera properly
	var world = get_tree().root.find_child("World", true, false)
	if world:
		var objects = world.find_child("Objects", true, false)
		if objects: objects.add_child(hologram)
		else: world.add_child(hologram)
	else:
		add_child(hologram) # Fallback
	
	update_inventory_display({})
	
	var title = Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(100, -50)
	title.size = Vector2(300, 30)
	title.modulate = Color(1.0, 1.0, 1.0, 1.0)
	inventory_window.add_child(title)

func create_pickup_ui():
	# Container on Right Center
	pickup_container = VBoxContainer.new()
	pickup_container.name = "PickupContainer"
	# Anchor to Right Center (1, 0.5)
	pickup_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	# Offset: -120 from right edge, 0 from vertical center
	pickup_container.position.x -= 120 
	# Ensure it grows from center
	pickup_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pickup_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	pickup_container.add_theme_constant_override("separation", 5)
	add_child(pickup_container)

func show_pickup_notification(item_name, count):
	# Create notification panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(5)
	style.content_margin_left = 10; style.content_margin_right = 10
	style.content_margin_top = 5; style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var path = "res://Assets/icons/" + item_name + ".png"
	if item_name == "Crafting Table": path = "res://Assets/Crafting Table.png"
	elif item_name == "Pickaxe": path = "res://Assets/pickaxe-iron.png"
	elif item_name == "Bonfire": path = "res://Assets/Bonfire_02-Sheet.png"
	elif item_name == "Fence": path = "res://Assets/FENCE 1 - DAY.png"
	
	if ResourceLoader.exists(path):
		icon.texture = load(path)
		# Special handling for Bonfire sprite sheet used as icon
		if item_name == "Bonfire" and icon.texture:
			var atlas = AtlasTexture.new()
			atlas.atlas = icon.texture
			atlas.region = Rect2(0, 0, 32, 32)
			icon.texture = atlas
	
	hbox.add_child(icon)
	
	# Text
	var lbl = Label.new()
	# [FIX] Cast count to int for display
	lbl.text = item_name + " x" + str(int(count))
	lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(lbl)
	
	pickup_container.add_child(panel)
	
	# Animate and Destroy
	var t = create_tween()
	t.tween_interval(0.5) 
	t.tween_property(panel, "modulate:a", 0.0, 0.5) 
	t.tween_callback(panel.queue_free)

func create_health_ui():
	health_container = HBoxContainer.new()
	health_container.name = "HealthBar"
	health_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	health_container.position.y += 10 
	health_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# [FIX] Separation 0 ensures slots touch perfectly
	health_container.add_theme_constant_override("separation", 0)
	add_child(health_container)
	
	for i in range(5):
		var slot_bg = PanelContainer.new()
		slot_bg.custom_minimum_size = Vector2(20, 20) 
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.5)
		
		# [FIX] Zero radius for perfect blending between slots
		style.set_corner_radius_all(0)
		style.border_width_left = 0
		style.border_width_right = 0
		style.border_width_top = 0
		style.border_width_bottom = 0
		
		if i == 0:
			# Round left edge of the first heart
			style.corner_radius_top_left = 5
			style.corner_radius_bottom_left = 5
		elif i == 4:
			# Round right edge of the last heart
			style.corner_radius_top_right = 5
			style.corner_radius_bottom_right = 5
		
		slot_bg.add_theme_stylebox_override("panel", style)
		
		var center = CenterContainer.new()
		slot_bg.add_child(center)
		
		var clipper = Control.new()
		clipper.custom_minimum_size = Vector2(16, 16) 
		clipper.clip_contents = true 
		# Ensure clipping happens from top (for top-down cut effect)
		# Control nodes by default clip from top-left, we'll manipulate height
		clipper.set_anchors_preset(Control.PRESET_BOTTOM_WIDE) 
		center.add_child(clipper)
		
		var heart = TextureRect.new()
		heart.texture = heart_texture
		heart.custom_minimum_size = Vector2(16, 16)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Anchor to BOTTOM so when height reduces, top gets cut off
		heart.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		heart.position = Vector2.ZERO
		clipper.add_child(heart)
		
		health_container.add_child(slot_bg)
		heart_clippers.append(clipper)

func update_health_display(current_hp):
	for i in range(5):
		var clipper = heart_clippers[i]
		var heart_min = i * 20
		var heart_max = (i + 1) * 20
		
		# Set full size first
		clipper.visible = true
		clipper.custom_minimum_size.y = 16 
		clipper.size.y = 16 # Force update
		
		if current_hp >= heart_max:
			# Full Heart
			clipper.custom_minimum_size.y = 16
		elif current_hp <= heart_min:
			# Empty Heart 
			clipper.visible = false 
			clipper.custom_minimum_size.y = 16
		else:
			# Partial Heart - Cut from Top
			var local_hp = current_hp - heart_min
			var percent = float(local_hp) / 20.0
			# Reducing height clips the top part because sprite is anchored to bottom
			clipper.custom_minimum_size.y = 16 * percent

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
	
	for i in range(8):
		var s = slot_scene.instantiate()
		s.custom_minimum_size = Vector2(40, 40) 
		s.name = "HotbarSlot_" + str(i+1)
		
		var num_lbl = Label.new()
		num_lbl.text = str(i + 1)
		# [FIX] Anchor to Top Left
		num_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		num_lbl.position = Vector2(2, 0)
		num_lbl.add_theme_font_size_override("font_size", 8) 
		num_lbl.modulate = Color(1, 1, 0.5, 0.8)
		s.add_child(num_lbl)
		
		hotbar_container.add_child(s)
		hotbar_slots.append(s)

# [UPDATED] Create 3 Building Slots (Table, Bonfire, Fence)
func create_building_slots():
	# We need a VBox to hold them vertically on the left
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(-100, 20)
	vbox.add_theme_constant_override("separation", 10)
	inv_panel.add_child(vbox)
	
	# Increased from 2 to 3 slots
	for i in range(3):
		var s = slot_scene.instantiate()
		s.custom_minimum_size = Vector2(80, 80)
		s.connect("slot_selected", _on_slot_selected)
		vbox.add_child(s)
		building_slots.append(s)

func create_remove_button():
	remove_button = Button.new()
	remove_button.text = "X"
	remove_button.size = Vector2(40, 40)
	remove_button.position = Vector2(470, 150) 
	remove_button.pressed.connect(_on_remove_button_pressed)
	remove_button.disabled = true
	inv_panel.add_child(remove_button)

func create_crafting_ui():
	crafting_window = Panel.new()
	crafting_window.name = "CraftingWindow"
	crafting_window.size = Vector2(300, 320) # Made Taller
	
	var vp_size = get_viewport().get_visible_rect().size
	crafting_window.position = (vp_size / 2) - (crafting_window.size / 2)
	crafting_window.visible = false
	
	# [FIX] Match Inventory UI Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5) # Matches inventory/hotbar
	style.set_corner_radius_all(5)
	crafting_window.add_theme_stylebox_override("panel", style)
	add_child(crafting_window)
	
	var title = Label.new()
	title.text = "WORKBENCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 10)
	title.size = Vector2(300, 30)
	title.modulate = Color(1, 0.84, 0)
	crafting_window.add_child(title)
	
	# VBox for multiple buttons
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(25, 50)
	vbox.size = Vector2(250, 240)
	vbox.add_theme_constant_override("separation", 10)
	crafting_window.add_child(vbox)
	
	# Pickaxe Button
	var btn_pick = Button.new()
	btn_pick.text = "Craft Pickaxe\n(3 Wood, 2 Stone, 1 Rope)"
	btn_pick.custom_minimum_size = Vector2(0, 50)
	apply_craft_btn_style(btn_pick)
	btn_pick.pressed.connect(func(): _craft_item("Pickaxe"))
	vbox.add_child(btn_pick)
	
	# Bonfire Button
	var btn_bonfire = Button.new()
	btn_bonfire.text = "Craft Bonfire\n(10 Wood, 5 Stone)"
	btn_bonfire.custom_minimum_size = Vector2(0, 50)
	apply_craft_btn_style(btn_bonfire)
	btn_bonfire.pressed.connect(func(): _craft_item("Bonfire"))
	vbox.add_child(btn_bonfire)

	# [NEW] Fence Button
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
	hint.modulate = Color(1, 1, 1, 0.5)
	crafting_window.add_child(hint)

func apply_craft_btn_style(btn):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.598, 0.441, 0.049, 1.0) 
	style.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func _process(delta):
	if Input.is_key_pressed(KEY_I):
		if not was_i_pressed:
			toggle_inventory()
		was_i_pressed = true
	else:
		was_i_pressed = false
	
	# [NEW] Handle Placement Mode Hologram
	if placement_mode and hologram:
		var mouse_pos = get_viewport().get_mouse_position()
		var world = get_tree().root.find_child("TileMapLayer", true, false)
		if world:
			var local_pos = world.to_local(get_viewport().canvas_transform.affine_inverse() * mouse_pos)
			var map_pos = world.local_to_map(local_pos)
			var snap_pos = world.map_to_local(map_pos)
			hologram.global_position = world.to_global(snap_pos)
			
			# Check Validity
			if world.has_method("is_tile_placeable"):
				if world.is_tile_placeable(map_pos):
					hologram.modulate = Color(0, 1, 0, 0.6) # Green
				else:
					hologram.modulate = Color(1, 0, 0, 0.6) # Red

func _input(event):
	# Cancel Placement
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if placement_mode:
			stop_placement_mode()

	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_8:
			var index = event.keycode - KEY_1
			select_hotbar_slot(index)

func select_hotbar_slot(index):
	if active_hotbar_index >= 0 and active_hotbar_index < hotbar_slots.size():
		hotbar_slots[active_hotbar_index].deselect()
	
	active_hotbar_index = index
	var slot = hotbar_slots[index]
	slot.select()
	
	var player = get_tree().root.find_child("Player", true, false)
	if player and player.has_method("equip_item"):
		if slot.data:
			player.equip_item(slot.icon.texture)
		else:
			player.unequip_item()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if placement_mode:
			_confirm_placement()
		# Check if clicked slot is a building slot
		elif selected_slot in building_slots and selected_slot.data:
			# Start placement mode instead of instant placing
			start_placement_mode(selected_slot.data["name"])

func start_placement_mode(type):
	placement_mode = true
	placement_type = type
	
	# Set Hologram Texture
	var path = "res://Assets/Crafting Table.png"
	if type == "Bonfire":
		path = "res://Assets/Bonfire_02-Sheet.png"
	elif type == "Fence":
		path = "res://Assets/FENCE 1 - DAY.png"
	
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

func stop_placement_mode():
	placement_mode = false
	hologram.visible = false

func _confirm_placement():
	var world = get_tree().root.find_child("TileMapLayer", true, false)
	if world:
		var mouse_pos = get_viewport().get_mouse_position()
		var local_pos = world.to_local(get_viewport().canvas_transform.affine_inverse() * mouse_pos)
		var map_pos = world.local_to_map(local_pos)
		
		if world.is_tile_placeable(map_pos):
			NetworkManager.send_place_object(placement_type, map_pos.x, map_pos.y)
			# Only stop placement if you want them to pick it up again
			# But for fences, user might want to drag-place. 
			# For now, let's keep one click = one place logic
			stop_placement_mode()

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
	# Cancel placement if opening inventory
	if placement_mode: stop_placement_mode()

func toggle_crafting(show):
	crafting_window.visible = show
	if show and placement_mode: stop_placement_mode()

func update_inventory_display(items):
	# Clear building slots
	for s in building_slots: s.set_item(null)
	
	# [UPDATED] Assign Buildings to Slots
	var building_idx = 0
	
	var buildings = ["Crafting Table", "Bonfire", "Fence"]
	
	for b_name in buildings:
		if items.has(b_name) and items[b_name] > 0:
			if building_idx < building_slots.size():
				building_slots[building_idx].set_item({"name": b_name, "count": int(items[b_name])})
				building_idx += 1
	
	var current_slots = inv_grid.get_children()
	while current_slots.size() < 16:
		var s = slot_scene.instantiate()
		s.custom_minimum_size = Vector2(60, 60)
		s.connect("slot_selected", _on_slot_selected)
		inv_grid.add_child(s)
		current_slots = inv_grid.get_children()
	
	for s in current_slots: s.set_item(null)
	for i in range(8): hotbar_slots[i].set_item(null)
	
	var idx = 0
	for k in items:
		# Skip buildings in main grid
		if k == "Crafting Table" or k == "Bonfire" or k == "Fence": continue 
		if idx < current_slots.size():
			var item_data = {"name": k, "count": int(items[k])}
			current_slots[idx].set_item(item_data)
			if idx < 8:
				hotbar_slots[idx].set_item(item_data)
			idx += 1
	
	if active_hotbar_index != -1:
		select_hotbar_slot(active_hotbar_index)

func _on_slot_selected(slot):
	if selected_slot and is_instance_valid(selected_slot) and selected_slot != slot:
		selected_slot.deselect()
	selected_slot = slot
	
	if selected_slot and selected_slot.data:
		remove_button.disabled = false
	else:
		remove_button.disabled = true
		selected_slot = null

func _on_remove_button_pressed():
	if selected_slot and selected_slot.data:
		NetworkManager.send_remove_item(selected_slot.data["name"], 1)

func _craft_item(recipe):
	NetworkManager.send_craft_item(recipe)
