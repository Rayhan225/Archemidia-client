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
	if not game_ui:
		game_ui = get_tree().root.find_child("GameUI", true, false)

func _process(delta):
	handle_hover_logic()
	handle_input_logic()

# --- FIX: Remove Mouse Click Interaction ---
# Interaction logic is now completely keyboard based (Space/C)
# func _unhandled_input(event) -> Removed

func handle_input_logic():
	if Input.is_key_pressed(KEY_C):
		if not c_was_pressed:
			if game_ui and game_ui.crafting_window.visible:
				game_ui.toggle_crafting(false)
			else:
				if is_instance_valid(hovered_object):
					var name_lower = hovered_object.name.to_lower()
					if "table" in name_lower or "crafting" in name_lower:
						game_ui.toggle_crafting(true)
		c_was_pressed = true
	else:
		c_was_pressed = false

	if Input.is_key_pressed(KEY_SPACE):
		if not space_was_pressed:
			var monster_hit = false
			if world_builder.active_monsters.size() > 0:
				for id in world_builder.active_monsters:
					var m = world_builder.active_monsters[id]
					if is_instance_valid(m) and player.global_position.distance_to(m.global_position) < 80:
						attempt_interaction(m)
						monster_hit = true
						break
			
			if not monster_hit:
				if is_instance_valid(hovered_object):
					var name_lower = hovered_object.name.to_lower()
					if "table" in name_lower or "crafting" in name_lower:
						var obj_pos = world_builder.to_local(hovered_object.global_position)
						var coord = world_builder.local_to_map(obj_pos)
						NetworkManager.send_pickup_object(coord.x, coord.y)
						if game_ui: game_ui.toggle_crafting(false)
					else:
						attempt_interaction(hovered_object)
				else:
					var p_tile = world_builder.local_to_map(world_builder.to_local(player.global_position))
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

func handle_hover_logic():
	if not is_instance_valid(player) or not world_builder: return
	
	# Keep highlighting based on mouse simply to show what Space will interact with
	var mouse_pos = get_global_mouse_position()
	var found_obj = null
	
	# Priority 1: Monsters
	if world_builder.get("active_monsters"):
		for id in world_builder.active_monsters:
			var m = world_builder.active_monsters[id]
			if is_instance_valid(m):
				if m.global_position.distance_to(mouse_pos) < 20:
					found_obj = m
					break
	
	# Priority 2: Objects at Mouse
	if not found_obj:
		var map_pos = world_builder.local_to_map(world_builder.to_local(mouse_pos))
		var obj = world_builder.objects_by_coord.get(map_pos, null)
		if obj and not "Grass" in obj.name:
			found_obj = obj
	
	# Priority 3: Objects near Player (Auto-select)
	if not found_obj:
		var player_center = player.global_position + Vector2(0, -8)
		var player_map = world_builder.local_to_map(world_builder.to_local(player_center))
		var obj = world_builder.objects_by_coord.get(player_map, null)
		if obj and not "Grass" in obj.name:
			found_obj = obj

	if is_instance_valid(hovered_object) and hovered_object != found_obj:
		reset_highlight(hovered_object)
	
	hovered_object = found_obj
	
	if is_instance_valid(hovered_object):
		apply_highlight(hovered_object)
