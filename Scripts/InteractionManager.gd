extends Node2D

@onready var world_builder = get_node_or_null("../TileMapLayer")
@onready var player = get_node_or_null("../Objects/Player")
var game_ui = null
var hovered_object = null

# Input Debounce Flags
var space_was_pressed = false
var c_was_pressed = false
var g_was_pressed = false 

func _ready():
	NetworkManager.server_message_received.connect(_on_server_event)
	game_ui = get_node_or_null("../GameUI")
	if not game_ui:
		game_ui = get_tree().root.find_child("GameUI", true, false)

func _process(delta):
	handle_hover_logic()
	handle_input_logic()

func handle_input_logic():
	# --- C Key: Toggle Crafting UI ---
	if Input.is_key_pressed(KEY_C):
		if not c_was_pressed:
			if game_ui:
				if game_ui.crafting_window.visible:
					game_ui.toggle_crafting(false)
				
				# Contextual Open: If hovering over a Crafting Table
				elif is_instance_valid(hovered_object):
					var name_lower = hovered_object.name.to_lower()
					var is_table = "crafting table" in name_lower or "crafting_table" in name_lower
					
					# Only open if hands are empty (hotbar index -1) to avoid accidental placement
					if is_table and game_ui.active_hotbar_index == -1:
						game_ui.toggle_crafting(true)
						
		c_was_pressed = true
	else:
		c_was_pressed = false

	# --- G Key: Open Game Hub (Lighthouse Interaction) ---
	if Input.is_key_pressed(KEY_G):
		if not g_was_pressed:
			# [FIXED] Send specific 'open_hub' action.
			# The server will calculate distance to Lighthouse (0,0) and decide if it opens.
			NetworkManager.send_data({ "action": "open_hub" })
		g_was_pressed = true
	else:
		g_was_pressed = false

	# --- Space Key: Physical Interaction (Attack / Harvest / Pickup) ---
	if Input.is_key_pressed(KEY_SPACE):
		if not space_was_pressed:
			# 1. Priority: Combat (Check for monsters within 50px)
			var monster_hit = false
			if world_builder and world_builder.active_monsters.size() > 0:
				for id in world_builder.active_monsters:
					var m = world_builder.active_monsters[id]
					if is_instance_valid(m) and is_instance_valid(player):
						if player.global_position.distance_to(m.global_position) < 50:
							attempt_interaction(m)
							monster_hit = true
							break
			
			# 2. Secondary: Object Interaction (Harvesting or Pickup)
			if not monster_hit:
				if is_instance_valid(hovered_object):
					var name_lower = hovered_object.name.to_lower()
					
					# Check if it's a "furniture" type object that should be picked up
					var is_building = "table" in name_lower or "bonfire" in name_lower or "fence" in name_lower
					
					if is_building:
						# Pickup Logic
						var obj_pos = world_builder.to_local(hovered_object.global_position)
						var coord = world_builder.local_to_map(obj_pos)
						NetworkManager.send_pickup_object(coord.x, coord.y)
						if game_ui: game_ui.toggle_crafting(false)
					else:
						# Harvest Logic (Trees, Rocks, Crops)
						attempt_interaction(hovered_object)
				else:
					# 3. Fallback: Interact with empty air (e.g. tilling ground)
					# This sends "interact" to the player's current tile.
					# Server logic ensures this DOES NOT trigger the Game Hub.
					var p_tile = get_facing_tile_coord()
					NetworkManager.send_data({ "action": "interact", "x": p_tile.x, "y": p_tile.y })

		space_was_pressed = true
	else:
		space_was_pressed = false

func attempt_interaction(obj):
	if not is_instance_valid(world_builder) or not is_instance_valid(obj): return
	var obj_pos = world_builder.to_local(obj.global_position)
	var coord = world_builder.local_to_map(obj_pos)
	NetworkManager.send_data({ "action": "interact", "x": coord.x, "y": coord.y })

# --- Visual Feedback (Highlighting) ---
func apply_highlight(obj):
	var s = get_sprite(obj)
	if s: s.modulate = Color(1.432, 1.432, 1.432, 1.0) # Brighten

func reset_highlight(obj):
	var s = get_sprite(obj)
	if s: s.modulate = Color(1, 1, 1, 1) # Reset

func get_sprite(obj):
	if not is_instance_valid(obj): return null
	for child in obj.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

# --- Network Event Handling ---
func _on_server_event(data):
	var event = data.get("event", "")
	var coord = Vector2i(data.get("x", 0), data.get("y", 0))
	var drops_list = data.get("drops", [])
	
	if event == "object_removed":
		world_builder.remove_object_at(coord, drops_list)
	elif event == "object_hit":
		world_builder.hit_object_at(coord, drops_list)
	elif event == "object_placed":
		world_builder.spawn_object(data.get("type", ""), coord)

# --- Helper: Get Tile Under Player ---
func get_facing_tile_coord() -> Vector2i:
	if not is_instance_valid(player) or not world_builder: return Vector2i.ZERO
	# Return the tile the player is currently standing on/facing
	return world_builder.local_to_map(world_builder.to_local(player.global_position))

# --- Helper: Mouse Hover Detection ---
func handle_hover_logic():
	if not is_instance_valid(player) or not world_builder: return
	
	var found_obj = null
	
	# Check the tile we are currently facing/standing on
	var target_coord = get_facing_tile_coord()
	
	if world_builder.objects_by_coord.has(target_coord):
		var obj = world_builder.objects_by_coord[target_coord]
		# Ignore ground tiles like Grass so we only highlight interactables
		if obj and not "Grass" in obj.name:
			found_obj = obj

	# Handle switching highlights
	if is_instance_valid(hovered_object) and hovered_object != found_obj:
		reset_highlight(hovered_object)
	
	hovered_object = found_obj
	
	if is_instance_valid(hovered_object):
		apply_highlight(hovered_object)
