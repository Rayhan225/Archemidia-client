extends StaticBody2D

var world_builder = null
var connectors = {}

func _ready():
	# 1. Map grid directions to your specific Scene Nodes (StaticBody2D)
	# We iterate through children to find which StaticBody2D contains which "Bar" sprite.
	# This adapts to your "StaticBody2D", "StaticBody2D2" naming automatically.
	for child in get_children():
		if child is StaticBody2D:
			if child.has_node("BarRight"): connectors[Vector2i(1, 0)] = child
			elif child.has_node("BarLeft"): connectors[Vector2i(-1, 0)] = child
			elif child.has_node("BarUp"): connectors[Vector2i(0, -1)] = child
			elif child.has_node("BarDown"): connectors[Vector2i(0, 1)] = child
	
	# Hide all by default (Disable collision too)
	for dir in connectors:
		set_connector_state(connectors[dir], false)

	# 2. Find WorldBuilder safely
	var world = get_tree().root.find_child("World", true, false)
	if world:
		world_builder = world.find_child("TileMapLayer", true, false)

	# 3. Delay logic slightly to allow neighbors to spawn/register
	await get_tree().process_frame
	collapse()
	propagate_update()

# Helper to toggle visual and collision
func set_connector_state(connector, active: bool):
	if not is_instance_valid(connector): return
	
	connector.visible = active
	
	# Find collision shape child and toggle it
	# We use call_deferred for "disabled" to be safe during physics steps
	var shape = connector.get_node_or_null("CollisionShape2D")
	if shape:
		shape.set_deferred("disabled", !active)

# Check neighbors and show appropriate connector bars
func collapse():
	if not is_instance_valid(world_builder): return

	var my_coord = world_builder.local_to_map(position)
	
	for dir in connectors:
		var connector = connectors[dir]
		if not connector: continue
		
		var neighbor_coord = my_coord + dir
		var neighbor = world_builder.objects_by_coord.get(neighbor_coord, null)
		
		# Connect if the neighbor exists and is also a Fence
		if is_instance_valid(neighbor) and neighbor.has_method("collapse"):
			set_connector_state(connector, true)
		else:
			set_connector_state(connector, false)

# Tell neighbors to update themselves (so they connect back to me)
func propagate_update():
	if not is_instance_valid(world_builder): return
	var my_coord = world_builder.local_to_map(position)
	
	# Use standard directions to ensure we notify all potential neighbors
	var directions = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	
	for dir in directions:
		var neighbor = world_builder.objects_by_coord.get(my_coord + dir, null)
		if is_instance_valid(neighbor) and neighbor.has_method("collapse"):
			neighbor.collapse()

# Called by neighbors
func update_connections():
	collapse()

func _exit_tree():
	if is_instance_valid(world_builder):
		call_deferred("propagate_update")
