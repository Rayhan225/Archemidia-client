extends Node2D

var my_coord: Vector2i
var world_ref = null
var connectors = {} 

func setup_visuals(connector_texture):
	# Create 4 "Arms" (Connectors)
	# Directions: Up, Down, Left, Right
	var dirs = {
		Vector2i(0, -1): "Up",
		Vector2i(0, 1): "Down",
		Vector2i(-1, 0): "Left",
		Vector2i(1, 0): "Right"
	}
	
	for d in dirs:
		var arm = Sprite2D.new()
		arm.texture = connector_texture
		arm.visible = false # Hidden by default
		arm.z_index = -1 # Behind the post
		
		# Center the rail
		arm.position = Vector2(0, 0) 
		
		# Rotate vertical rails if needed, but for "Wood Rail" texture 
		# we assume it's horizontal bars.
		# For Up/Down neighbors, we rotate 90 degrees? 
		# No, fences usually connect sideways. 
		# Let's keep it simple: Fences connect Left/Right visually with rails.
		# Up/Down connections might need a vertical rail texture, 
		# but for now, let's just rotate the horizontal rail 90 deg.
		
		if dirs[d] == "Up" or dirs[d] == "Down":
			arm.rotation_degrees = 90
			
		add_child(arm)
		connectors[d] = arm

# The "Collapse" function
func collapse_state(world, coord):
	my_coord = coord
	world_ref = world
	
	for dir in connectors:
		var neighbor_coord = my_coord + dir
		var neighbor_obj = world.objects_by_coord.get(neighbor_coord, null)
		var is_connected = false
		
		if neighbor_obj and is_instance_valid(neighbor_obj):
			# [FIX] Check CHILDREN for this script, not the parent object
			for child in neighbor_obj.get_children():
				if child.has_method("collapse_state"):
					is_connected = true
					break
		
		connectors[dir].visible = is_connected
