class_name CustomAStar

# Returns an Array of Vector2i (Grid Coordinates) representing the path
static func find_path(start: Vector2i, end: Vector2i, obstacles: Dictionary, bounds_rect: Rect2i) -> Array:
	# 1. Setup Lists
	var open_set = [start]
	var came_from = {} # Key: Current Node, Value: Previous Node
	
	var g_score = { start: 0 } # Cost from start
	var f_score = { start: _heuristic(start, end) } # Estimated total cost
	
	# Limit iterations to prevent freezing game on impossible paths
	var iterations = 0
	var max_iterations = 1000 

	while open_set.size() > 0:
		iterations += 1
		if iterations > max_iterations:
			print("A* path too long or stuck.")
			return []

		# 2. Get node with lowest F score
		var current = _get_lowest_f_node(open_set, f_score)
		
		# 3. Check if reached target
		if current == end:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		# 4. Check Neighbors
		for neighbor in _get_neighbors(current):
			# Collision Check: Is it an obstacle?
			if obstacles.has(neighbor):
				continue
			
			# Bounds Check: Don't pathfind into the void/unloaded chunks
			# (Optional: Remove if you want infinite search)
			# if not bounds_rect.has_point(neighbor): continue
			
			var tentative_g = g_score[current] + 1 # Assume distance is 1
			
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, end)
				
				if not neighbor in open_set:
					open_set.append(neighbor)
					
	return [] # No path found

static func _heuristic(a: Vector2i, b: Vector2i) -> float:
	# Manhattan distance is fast and good for grid movement
	return abs(a.x - b.x) + abs(a.y - b.y)

static func _get_lowest_f_node(list: Array, scores: Dictionary) -> Vector2i:
	var lowest_node = list[0]
	var lowest_score = scores.get(lowest_node, 999999)
	
	for node in list:
		var score = scores.get(node, 999999)
		if score < lowest_score:
			lowest_score = score
			lowest_node = node
	return lowest_node

static func _get_neighbors(center: Vector2i) -> Array:
	var neighbors = []
	# 4-Directional Movement (Up, Down, Left, Right)
	# Change this to 8-way if you want diagonals
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	
	for dir in directions:
		neighbors.append(center + dir)
	return neighbors

static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var total_path = [current]
	while current in came_from:
		current = came_from[current]
		total_path.push_front(current)
	return total_path
