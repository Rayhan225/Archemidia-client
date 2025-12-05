extends Node2D

@onready var world_builder = get_node_or_null("../TileMapLayer")
@onready var player = get_node_or_null("../Objects/Player")
var game_ui = null
var hovered_object = null

var space_was_pressed = false
var c_was_pressed = false

func _ready():
	NetworkManager.server_message_received.connect(_on_server_event)
	game_ui = get_node_or_null("../GameUI")
	# Fallback search if path fails
	if not game_ui:
		game_ui = get_tree().root.find_child("GameUI", true, false)

func _process(delta):
	handle_hover_logic()
	handle_input_logic()

func handle_input_logic():
	# --- C Key: Crafting UI ---
	if Input.is_key_pressed(KEY_C):
		if not c_was_pressed:
			if game_ui:
				# 1. If UI is already open, close it
				if game_ui.crafting_window.visible:
					game_ui.toggle_crafting(false)
				
				# 2. Open Condition: Facing Table + Empty Hands
				elif is_instance_valid(hovered_object):
					var name_lower = hovered_object.name.to_lower()
					
					# [FIX] Check for both space and underscore names
					var is_table = "crafting table" in name_lower or "crafting_table" in name_lower
					
					# Check if it is a Crafting Table AND Hands are Empty (index -1)
					if is_table and game_ui.active_hotbar_index == -1:
						game_ui.toggle_crafting(true)
						
		c_was_pressed = true
	else:
		c_was_pressed = false

	# --- Space Key: Attack / Interact / Pickup ---
	if Input.is_key_pressed(KEY_SPACE):
		if not space_was_pressed:
			# 1. Prioritize Monsters
			var monster_hit = false
			if world_builder.active_monsters.size() > 0:
				for id in world_builder.active_monsters:
					var m = world_builder.active_monsters[id]
					if is_instance_valid(m) and player.global_position.distance_to(m.global_position) < 50:
						attempt_interaction(m)
						monster_hit = true
						break
			
			# 2. If no monster, interact with object
			if not monster_hit:
				if is_instance_valid(hovered_object):
					var name_lower = hovered_object.name.to_lower()
					
					# Check for pickup-able buildings logic
					# [FIX] Robust check for various naming conventions
					var is_building = "table" in name_lower or "bonfire" in name_lower or "fence" in name_lower
					
					if is_building:
						# If holding Space on a building -> Pickup
						var obj_pos = world_builder.to_local(hovered_object.global_position)
						var coord = world_builder.local_to_map(obj_pos)
						NetworkManager.send_pickup_object(coord.x, coord.y)
						# Ensure UI closes if we picked up the table
						if game_ui: game_ui.toggle_crafting(false)
					else:
						# Standard interact (Hit/Harvest)
						attempt_interaction(hovered_object)
				else:
					# 3. Fallback: Interact with tile in front
					var p_tile = get_facing_tile_coord()
					NetworkManager.send_data({ "action": "interact", "x": p_tile.x, "y": p_tile.y })

		space_was_pressed = true
	else:
		space_was_pressed = false

func attempt_interaction(obj):
	var obj_pos = world_builder.to_local(obj.global_position)
	var coord = world_builder.local_to_map(obj_pos)
	NetworkManager.send_data({ "action": "interact", "x": coord.x, "y": coord.y })

func apply_highlight(obj):
	var s = get_sprite(obj)
	if s: s.modulate = Color(1.432, 1.432, 1.432, 1.0)

func reset_highlight(obj):
	var s = get_sprite(obj)
	if s: s.modulate = Color(1, 1, 1, 1)

func get_sprite(obj):
	if not is_instance_valid(obj): return null
	for child in obj.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

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

func get_facing_tile_coord() -> Vector2i:
	if not is_instance_valid(player) or not world_builder: return Vector2i.ZERO
	
	var player_map = world_builder.local_to_map(world_builder.to_local(player.global_position))
	
	var facing = Vector2i.DOWN
	if player.facing_dir == "up": facing = Vector2i.UP
	elif player.facing_dir == "side":
		if player.sprite.flip_h: facing = Vector2i.LEFT
		else: facing = Vector2i.RIGHT
	
	return player_map + facing

func handle_hover_logic():
	if not is_instance_valid(player) or not world_builder: return
	
	var found_obj = null
	var target_coord = get_facing_tile_coord()
	
	# Check facing tile
	var obj = world_builder.objects_by_coord.get(target_coord, null)
	
	# Check feet if facing is empty (allows interacting while standing on something)
	if not obj:
		var feet_coord = world_builder.local_to_map(world_builder.to_local(player.global_position))
		obj = world_builder.objects_by_coord.get(feet_coord, null)

	if obj and not "Grass" in obj.name:
		found_obj = obj

	if is_instance_valid(hovered_object) and hovered_object != found_obj:
		reset_highlight(hovered_object)
	
	hovered_object = found_obj
	
	if is_instance_valid(hovered_object):
		apply_highlight(hovered_object)
