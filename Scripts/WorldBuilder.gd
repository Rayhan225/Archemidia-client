extends TileMapLayer

@export var player_path: NodePath
var player: CharacterBody2D

# Chunk & Object Tracking
var chunk_objects = {} 
var loaded_chunks = {}
var last_player_chunk = Vector2i(-999, -999)

# Spawn Queue
var spawn_queue = [] 

var objects_by_coord = {} 
var active_monsters = {} 
var slime_scene = preload("res://slime.tscn")

const LOAD_RADIUS = 2 
const PRIORITY_RADIUS = 1 
const TILE_PIXEL_SIZE = 64
const CHUNK_SIZE = 16
const CHUNK_PIXEL_SIZE = TILE_PIXEL_SIZE * CHUNK_SIZE

# Loading State
var target_chunk_center = Vector2i(-999, -999)
var is_updating_chunks = false

# Object Scenes
var poof_scene = preload("res://effect_poof.tscn")
var item_drop_scene = preload("res://tree_drop.tscn") 
var stone_drop_scene = preload("res://stone_drop.tscn") 
var rope_drop_scene = preload("res://rope_drop.tscn")
var pickaxe_drop_scene = preload("res://pickaxe_crafted.tscn")
var table_drop_scene = preload("res://crafting_table_drop.tscn")
var bonfire_drop_scene = preload("res://bonfire_drop.tscn")
var fence_scene = preload("res://fence.tscn")

# Coastline Overlay
var coastline_overlay: Node2D

func _ready():
	NetworkManager.server_message_received.connect(_on_server_update)
	if player_path: player = get_node(player_path)
	else: player = get_tree().root.find_child("Player", true, false)
	
	coastline_overlay = Node2D.new()
	coastline_overlay.name = "CoastlineOverlay"
	coastline_overlay.z_index = -1
	add_child(coastline_overlay)
	coastline_overlay.draw.connect(_draw_coastlines)
	
	if player:
		var p = local_to_map(to_local(player.global_position))
		update_chunks_progressive(floor(p.x/float(CHUNK_SIZE)), floor(p.y/float(CHUNK_SIZE)))

func is_tile_placeable(coord: Vector2i) -> bool:
	if objects_by_coord.has(coord): 
		var existing = objects_by_coord.get(coord)
		if is_instance_valid(existing): return false
	
	if get_cell_source_id(coord) == -1: return false
	return true

func _on_server_update(data):
	if data.get("event") == "position_update":
		if data.has("monsters"):
			update_monsters(data["monsters"])
		if data.has("objects"):
			sync_world_objects(data["objects"])
			
	elif data.get("event") == "monster_hit":
		var id = data["id"]
		if active_monsters.has(id):
			var m = active_monsters[id]
			m.update_state({"x": m.position.x, "y": m.position.y, "hp": data["hp"], "state": "HURT"})
			if data.get("destroyed", false):
				m.destroy()
				active_monsters.erase(id)
				# False = Natural Drop (Instant pickup)
				spawn_drops(data.get("drops", []), m.position, false)
				
	elif data.get("event") == "object_removed":
		var coord = Vector2i(data.get("x", 0), data.get("y", 0))
		remove_object_at(coord, data.get("drops", []))
		
	elif data.get("event") == "object_hit":
		var coord = Vector2i(data.get("x", 0), data.get("y", 0))
		hit_object_at(coord, data.get("drops", []))
		
	elif data.get("event") == "object_placed":
		var coord = Vector2i(data.get("x", 0), data.get("y", 0))
		_real_spawn_object(data.get("type", ""), coord)

	# --- NEW: HANDLE ITEM DROPS (FROM INVENTORY) ---
	elif data.get("event") == "item_spawn":
		var drop_pos = Vector2(data.get("x", 0), data.get("y", 0))
		# True = Dropped by Player (Enforce distance rule)
		spawn_drops(data.get("drops", []), drop_pos, true)

func sync_world_objects(list):
	for o in list:
		var c = Vector2i(o.x, o.y)
		if !objects_by_coord.has(c):
			_real_spawn_object(o.type, c)

func update_monsters(monster_list):
	var current_ids = []
	for m_data in monster_list:
		var id = m_data["id"]
		current_ids.append(id)
		if active_monsters.has(id):
			if is_instance_valid(active_monsters[id]):
				active_monsters[id].update_state(m_data)
		else:
			var m = slime_scene.instantiate()
			var objs = get_node_or_null("../Objects")
			if objs: objs.add_child(m)
			else: add_child(m)
			if m.has_method("setup"): 
				m.setup(m_data)
			active_monsters[id] = m
	
	var to_remove = []
	for id in active_monsters:
		if not id in current_ids: to_remove.append(id)
	for id in to_remove:
		if is_instance_valid(active_monsters[id]): active_monsters[id].queue_free()
		active_monsters.erase(id)

func _process(delta):
	var start_time = Time.get_ticks_msec()
	while not spawn_queue.is_empty():
		if Time.get_ticks_msec() - start_time > 3: 
			break
		var item = spawn_queue.pop_front()
		_real_spawn_object(item.type, item.coord)

	if not player:
		player = get_tree().root.find_child("Player", true, false)
		return
		
	var p = local_to_map(to_local(player.global_position))
	var current_chunk = Vector2i(floor(p.x/float(CHUNK_SIZE)), floor(p.y/float(CHUNK_SIZE)))
	
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		update_chunks_progressive(current_chunk.x, current_chunk.y)
		coastline_overlay.queue_redraw()

func update_chunks_progressive(cx, cy):
	target_chunk_center = Vector2i(cx, cy)
	
	if is_updating_chunks: return
	is_updating_chunks = true
	
	while true:
		var current_center = target_chunk_center
		var chunks_to_load = []
		
		for x in range(current_center.x - LOAD_RADIUS, current_center.x + LOAD_RADIUS + 1): 
			for y in range(current_center.y - LOAD_RADIUS, current_center.y + LOAD_RADIUS + 1):
				var c = Vector2i(x, y)
				if not loaded_chunks.has(c): 
					chunks_to_load.append(c)
		
		var chunks_to_remove = []
		for c in loaded_chunks.keys():
			if abs(c.x - current_center.x) > LOAD_RADIUS + 1 or abs(c.y - current_center.y) > LOAD_RADIUS + 1:
				chunks_to_remove.append(c)
		
		for c in chunks_to_remove:
			unload_chunk(c)
			loaded_chunks.erase(c)
		
		if chunks_to_load.is_empty():
			is_updating_chunks = false
			break
			
		var instant_list = []
		var background_list = []
		
		for c in chunks_to_load:
			var dx = abs(c.x - current_center.x)
			var dy = abs(c.y - current_center.y)
			
			if dx <= PRIORITY_RADIUS and dy <= PRIORITY_RADIUS:
				instant_list.append(c)
			else:
				background_list.append(c)
		
		for c in instant_list:
			load_chunk(c, true)
		
		background_list.sort_custom(func(a, b):
			return a.distance_squared_to(current_center) < b.distance_squared_to(current_center)
		)
		
		for c in background_list:
			if c.distance_squared_to(target_chunk_center) > (LOAD_RADIUS + 2) * (LOAD_RADIUS + 2):
				continue
				
			load_chunk(c, false)
			await get_tree().process_frame 
			
			if target_chunk_center != current_center:
				break

func load_chunk(c, is_immediate):
	loaded_chunks[c] = "loading"
	var req = HTTPRequest.new();
	add_child(req)
	req.request_completed.connect(func(r,co,h,b): _on_chunk(c, req, co, b, is_immediate))
	req.request("http://localhost:8080/api/map/chunk?x=%d&y=%d&size=16" % [c.x*16, c.y*16])

func unload_chunk(c):
	var ox = c.x * 16;
	var oy = c.y * 16
	for y in range(16):
		for x in range(16):
			set_cell(Vector2i(ox+x, oy+y), -1)
	
	if chunk_objects.has(c):
		for node in chunk_objects[c]:
			if is_instance_valid(node):
				var coord = local_to_map(to_local(node.position))
				objects_by_coord.erase(coord)
				node.queue_free()
		chunk_objects.erase(c)

func _on_chunk(c, req, code, body, is_immediate):
	if code == 200: 
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json: render_chunk(json, c.x, c.y, is_immediate)
	loaded_chunks[c] = true
	req.queue_free()

func get_hash_noise(x: int, y: int) -> float:
	var seed_val = 12345
	var n = x * 331 + y * 433 + seed_val
	n = (n << 13) ^ n
	n = (n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff
	return float(n) / 2147483647.0

func render_chunk(d, cx, cy, is_immediate):
	var ox = cx*16;
	var oy = cy*16
	var batch_objects = []
	
	for y in range(d.size()): 
		for x in range(d[0].size()):
			var c = Vector2i(ox+x, oy+y)
			var tile_id = d[y][x]
			
			if tile_id == -1:
				set_cell(c, -1)
				continue
				
			if tile_id == 0: set_cell(c, 3, Vector2i(0,0), 0)   
			elif tile_id == 2: set_cell(c, 6, Vector2i(0,0), 0) 
			elif tile_id == 1: set_cell(c, 5, Vector2i(0,0), 0) 
			
			if c.x == 0 and c.y == 0: continue

			var r = get_hash_noise(c.x, c.y)
			var boundary_noise = (get_hash_noise(c.x, 0) - 0.5) * 10.0
			var isSnow = c.y < -30 + boundary_noise
			var isDesert = c.y > 30 + boundary_noise
			var obj_type = ""
			
			if !isSnow and !isDesert and r > 0.045 and r < 0.3: obj_type = "Grass"
			
			if obj_type != "":
				batch_objects.append({"type": obj_type, "coord": c})

	if is_immediate:
		for item in batch_objects:
			_real_spawn_object(item.type, item.coord)
	else:
		spawn_queue.append_array(batch_objects)
	
	coastline_overlay.queue_redraw()

func _draw_coastlines():
	var line_color = Color.AQUA 
	var line_width = 3.0
	
	if not player: return
	
	for chunk_coord in loaded_chunks:
		if typeof(loaded_chunks[chunk_coord]) != TYPE_BOOL: continue
		
		var ox = chunk_coord.x * CHUNK_SIZE
		var oy = chunk_coord.y * CHUNK_SIZE
		
		for x in range(CHUNK_SIZE):
			for y in range(CHUNK_SIZE):
				var c = Vector2i(ox + x, oy + y)
				
				if get_cell_source_id(c) == -1: continue
				
				var local_pos = map_to_local(c)
				var bottom = local_pos + Vector2(0, 16)
				var right = local_pos + Vector2(32, 0)
				var left = local_pos + Vector2(-32, 0)
				
				var n_br = c + Vector2i(1, 0)
				if is_tile_empty(n_br):
					coastline_overlay.draw_line(right, bottom, line_color, line_width)
					
				var n_bl = c + Vector2i(0, 1)
				if is_tile_empty(n_bl):
					coastline_overlay.draw_line(bottom, left, line_color, line_width)

func is_tile_empty(c):
	var chunk_c = Vector2i(floor(c.x/float(CHUNK_SIZE)), floor(c.y/float(CHUNK_SIZE)))
	if loaded_chunks.has(chunk_c):
		return get_cell_source_id(c) == -1
	else:
		return false

func queue_spawn(type, coord):
	spawn_queue.append({"type": type, "coord": coord})

func _real_spawn_object(type, coord):
	if objects_by_coord.has(coord): return
	var scene = null
	
	if type == "Tree": scene = load("res://tree.tscn")
	elif type == "Snow Tree": scene = load("res://snow_tree.tscn")
	elif type == "Palm Tree": scene = load("res://palm_tree.tscn")
	elif type == "Stone": scene = load("res://stone.tscn")
	elif type == "Snow Rock": scene = load("res://snow_rock.tscn")
	elif type == "Sand Rock": scene = load("res://sand_rock.tscn")
	elif type == "Cactus": scene = load("res://cactus.tscn")
	elif type == "Trunk": scene = load("res://trunk.tscn")
	elif type == "Crafting Table": scene = load("res://crafting_table.tscn")
	elif type == "Bonfire": scene = load("res://bonfire.tscn")
	elif type == "Fence": scene = fence_scene
	
	if !scene: return
	var s = scene.instantiate()
	s.position = map_to_local(coord)
	
	if type == "Grass": 
		s.position += Vector2(randf_range(-16,16), randf_range(-16,16))
		
	var par = get_node_or_null("../Objects")
	if par:
		par.add_child(s)
		objects_by_coord[coord] = s
		
		if type == "Fence":
			if s.has_method("update_connections"):
				s.call_deferred("update_connections")
				s.call_deferred("update_neighbors")
		
		var chunk_coord = Vector2i(floor(coord.x/float(CHUNK_SIZE)), floor(coord.y/float(CHUNK_SIZE)))
		if not chunk_objects.has(chunk_coord): chunk_objects[chunk_coord] = []
		chunk_objects[chunk_coord].append(s)

func spawn_object(type, coord):
	_real_spawn_object(type, coord)

func remove_object_at(coord, drops_list):
	var target = objects_by_coord.get(coord, null)
	if target and is_instance_valid(target):
		if player and player.has_method("apply_shake"): player.apply_shake(3.0)
		var poof = poof_scene.instantiate()
		poof.position = target.position
		get_parent().add_child(poof)
		poof.emitting = true
		
		# False = Natural Drop
		spawn_drops(drops_list, target.position, false)
		
		if target.has_method("propagate_update"):
			target.propagate_update()
			
		objects_by_coord.erase(coord)
		target.queue_free()

func hit_object_at(coord, drops_list):
	var target = objects_by_coord.get(coord, null)
	if target and is_instance_valid(target):
		var s = target.get_node_or_null("Sprite2D")
		if !s: s = target.get_node_or_null("AnimatedSprite2D")
		if s:
			var t = create_tween()
			s.modulate = Color(10,10,10)
			t.tween_property(s, "modulate", Color(1,1,1), 0.1)
			if player and player.has_method("apply_shake"): player.apply_shake(1.0)
		# False = Natural Drop
		spawn_drops(drops_list, target.position, false)

# --- UPDATED: Accepts Player Drop Flag ---
func spawn_drops(drops_list, pos, is_player_drop=false):
	for d in drops_list:
		var type = d["type"]
		var amount = int(d["amount"])
		for i in range(amount):
			var drop = null
			if type == "Wood": drop = item_drop_scene.instantiate()
			elif type == "Stone": drop = stone_drop_scene.instantiate()
			elif type == "Rope": drop = rope_drop_scene.instantiate()
			elif type == "Pickaxe": drop = pickaxe_drop_scene.instantiate()
			elif type == "Crafting Table": drop = table_drop_scene.instantiate()
			elif type == "Bonfire": drop = bonfire_drop_scene.instantiate()
			elif type == "Fence": 
				drop = item_drop_scene.instantiate()
				if drop.has_method("setup"): drop.setup("Fence", is_player_drop)
			else: drop = item_drop_scene.instantiate() 
			
			if drop:
				drop.position = pos + Vector2(randf_range(-15,15), randf_range(-15,15))
				var par = get_node_or_null("../Objects")
				if par: par.add_child(drop)
				
				# Pass the flag to setup
				if drop.has_method("setup"): 
					drop.setup(type, is_player_drop)
