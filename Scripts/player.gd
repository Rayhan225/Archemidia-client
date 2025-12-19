extends CharacterBody2D

const SPEED = 100.0
const PICKAXE_SCENE = preload("res://pickaxe_crafted.tscn")
const HOE_SCENE = preload("res://hoe_crafted.tscn")
const FLOATING_TEXT_SCENE = preload("res://floating_text.tscn")

@onready var sprite = $AnimatedSprite2D
@onready var camera = $Camera2D
var hand_sprite: Sprite2D

var facing_dir = "down"
var is_attacking = false
var last_sent_pos = Vector2.ZERO
var shake_strength: float = 0.0
var shake_decay: float = 5.0
var current_hp = 100

var deadzone_size = Vector2(40, 30) 
var camera_smooth_speed = 5.0 
var camera_pos_float = Vector2.ZERO

# --- Visual Vars ---
var bob_time = 0.0
var base_hand_pos = Vector2.ZERO

func _ready():
	NetworkManager.server_message_received.connect(_on_server_message)
	if camera:
		camera.enabled = true
		camera.top_level = true 
		camera.position_smoothing_enabled = false
		camera.global_position = global_position
		camera.zoom = Vector2(1.0, 1.0)
		camera_pos_float = global_position

	# Create the Hand Sprite dynamically
	hand_sprite = Sprite2D.new()
	hand_sprite.name = "HandSprite"
	add_child(hand_sprite)
	hand_sprite.scale = Vector2(0.6, 0.6)
	
	# Keep Z=0 so shadows (Z=1) draw over it
	hand_sprite.z_index = 0
	
	# Initial Position
	base_hand_pos = Vector2(6, -10) 
	hand_sprite.position = base_hand_pos
	
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		if not is_attacking:
			attack()

	if is_attacking:
		velocity = Vector2.ZERO
	else:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_dir.normalized() * SPEED
		
		if input_dir != Vector2.ZERO:
			update_facing_direction(input_dir)
			play_anim("walk")
			
			bob_time += delta * 20.0 
			var bob_offset = Vector2(0, sin(bob_time) * 1.5)
			hand_sprite.position = base_hand_pos + bob_offset
			
			if global_position.distance_to(last_sent_pos) > 2.0:
				NetworkManager.send_move_request(global_position)
				last_sent_pos = global_position
		else:
			play_anim("idle")
			bob_time = 0.0
			hand_sprite.position = hand_sprite.position.lerp(base_hand_pos, delta * 10.0)

	move_and_slide()

func _process(delta):
	if camera:
		var target_x = camera_pos_float.x
		var target_y = camera_pos_float.y
		
		if global_position.x > camera_pos_float.x + deadzone_size.x:
			target_x = global_position.x - deadzone_size.x
		elif global_position.x < camera_pos_float.x - deadzone_size.x:
			target_x = global_position.x + deadzone_size.x
			
		if global_position.y > camera_pos_float.y + deadzone_size.y:
			target_y = global_position.y - deadzone_size.y
		elif global_position.y < camera_pos_float.y - deadzone_size.y:
			target_y = global_position.y + deadzone_size.y
		
		var target_pos = Vector2(target_x, target_y)
		camera_pos_float = camera_pos_float.lerp(target_pos, camera_smooth_speed * delta)
		
		var final_pos = camera_pos_float
		if shake_strength > 0:
			shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
			var shake_offset = Vector2(
				randf_range(-shake_strength, shake_strength),
				randf_range(-shake_strength, shake_strength)
			)
			final_pos += shake_offset
		
		camera.global_position = final_pos.round()

func apply_shake(intensity: float = 5.0):
	shake_strength = intensity

func update_facing_direction(dir: Vector2):
	if not is_attacking:
		hand_sprite.rotation = 0
		
	if dir.y < 0: # UP
		facing_dir = "up"
		sprite.flip_h = false
		hand_sprite.show_behind_parent = true 
		base_hand_pos = Vector2(6, -22) 
		hand_sprite.scale.x = 0.6
		
	elif dir.y > 0: # DOWN
		facing_dir = "down"
		sprite.flip_h = false
		hand_sprite.show_behind_parent = false
		base_hand_pos = Vector2(6, -10)
		hand_sprite.scale.x = 0.6
		
	elif dir.x != 0: # SIDE
		facing_dir = "side"
		sprite.flip_h = (dir.x < 0)
		hand_sprite.show_behind_parent = false
		
		if dir.x < 0: # LEFT
			base_hand_pos = Vector2(-10, -14)
			hand_sprite.scale.x = -0.6 
			if not is_attacking: hand_sprite.rotation = deg_to_rad(-15) 
		else: # RIGHT
			base_hand_pos = Vector2(10, -14)
			hand_sprite.scale.x = 0.6
			if not is_attacking: hand_sprite.rotation = deg_to_rad(15)

func play_anim(action: String):
	var anim_name = action + "_" + facing_dir
	sprite.play(anim_name)

func attack():
	is_attacking = true
	play_anim("hit")
	
	# --- DETECT TOOL TYPE ---
	var is_pickaxe = false
	var is_hoe = false
	
	if hand_sprite.get_child_count() > 0:
		var tool_node = hand_sprite.get_child(0)
		if "Pickaxe" in tool_node.name: is_pickaxe = true
		elif "Hoe" in tool_node.name: is_hoe = true
	
	# --- REACH ---
	var reach = 35.0
	if is_pickaxe: reach = 70.0 
	elif is_hoe: reach = 50.0 
	
	# --- COLORS ---
	var slash_color = Color(0.7, 0.6, 0.0, 1.0) # Gold
	if is_hoe: slash_color = Color(0.9, 1.0, 1.0, 1.0) # Bright Cyan/White
	
	create_hand_swipe(reach, slash_color, is_hoe)

	# --- DIRECTION VECTOR ---
	var dir_vec = Vector2.DOWN
	if facing_dir == "up": dir_vec = Vector2.UP
	elif facing_dir == "side":
		if sprite.flip_h: dir_vec = Vector2.LEFT
		else: dir_vec = Vector2.RIGHT

	# --- ANIMATION TWEEN ---
	if hand_sprite.visible:
		var tween = create_tween()
		var start_rot = hand_sprite.rotation
		
		if is_hoe:
			# === CHOP ANIMATION (Deep Swing) ===
			var windup = deg_to_rad(-60) if not sprite.flip_h else deg_to_rad(60)
			if facing_dir == "up": windup *= -1
			
			hand_sprite.rotation += windup
			
			var chop_amount = deg_to_rad(135) 
			var chop_target = start_rot + (chop_amount if not sprite.flip_h else -chop_amount)
			if facing_dir == "up": 
				chop_target = start_rot - (chop_amount if not sprite.flip_h else -chop_amount)
			
			tween.tween_property(hand_sprite, "rotation", chop_target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(hand_sprite, "rotation", start_rot, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		else:
			# === SWIPE ANIMATION ===
			var swing_amount = PI / 1.5
			if sprite.flip_h or facing_dir == "up": 
				swing_amount *= -1
				
			tween.tween_property(hand_sprite, "rotation", start_rot + swing_amount, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(hand_sprite, "rotation", start_rot, 0.2).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)

	# --- HIT DETECTION ---
	var points_to_check = [reach]
	if is_pickaxe or is_hoe: points_to_check.push_front(reach * 0.5)

	var sent_tiles = {}
	var TILE_SIZE = 64.0
	
	var world_builder = null
	var world_node = get_tree().root.find_child("World", true, false)
	if world_node: world_builder = world_node.find_child("TileMapLayer", true, false)
	if not world_builder: world_builder = get_tree().root.find_child("TileMapLayer", true, false)

	for dist in points_to_check:
		var check_pos = global_position + (dir_vec * dist)
		var grid_x = floor(check_pos.x / TILE_SIZE)
		var grid_y = floor(check_pos.y / TILE_SIZE)
		var key = str(grid_x) + "_" + str(grid_y)
		var vector_key = Vector2i(grid_x, grid_y)
		
		if sent_tiles.has(key): continue

		var has_object = false
		if world_builder and world_builder.objects_by_coord.has(vector_key):
			has_object = true
		
		if is_hoe:
			if has_object:
				show_wrong_tool_feedback()
				sent_tiles[key] = true
				continue
			else:
				NetworkManager.send_interact(int(grid_x), int(grid_y))
				sent_tiles[key] = true
		else:
			NetworkManager.send_interact(int(grid_x), int(grid_y))
			sent_tiles[key] = true

	apply_shake(2.0)

func show_wrong_tool_feedback():
	var txt = FLOATING_TEXT_SCENE.instantiate()
	txt.global_position = hand_sprite.global_position + Vector2(0, -50)
	get_tree().root.add_child(txt)

# --- QUADRATIC BEZIER HELPER ---
func get_bezier_point(t: float, p0: Vector2, p1: Vector2, p2: Vector2) -> Vector2:
	var u = 1 - t
	var tt = t * t
	var uu = u * u
	return (uu * p0) + (2 * u * t * p1) + (tt * p2)

# --- REWORKED SLASH EFFECT ---
func create_hand_swipe(reach, color, is_chop_anim):
	var slash = Line2D.new()
	slash.width = 10.0 
	
	slash.default_color = color
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# Visual taper
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0, 0.2)) 
	width_curve.add_point(Vector2(0.4, 1.0)) 
	width_curve.add_point(Vector2(1, 0.0)) 
	slash.width_curve = width_curve

	slash.z_index = 0 
	
	add_child(slash)
	slash.position = hand_sprite.position
	
	var arc = []
	var segments = 10
	
	if is_chop_anim:
		# === HOE CURVE: TILLING MOTION (Down & Inwards) ===
		var p0 = Vector2.ZERO # Start (Shoulder/Head)
		var p1 = Vector2.ZERO # Control (Swing Out)
		var p2 = Vector2.ZERO # End (Ground/Feet - Pulled In)
		
		if facing_dir == "down":
			slash.show_behind_parent = false
			p0 = Vector2(0, -30)      
			p1 = Vector2(0, 20)       # Straight out
			p2 = Vector2(0, 40)       # Straight down (Standard chop)
			
		elif facing_dir == "up":
			slash.show_behind_parent = true 
			p0 = Vector2(0, -30)
			p1 = Vector2(0, -40)
			p2 = Vector2(0, -50) 
			
		elif facing_dir == "side":
			slash.show_behind_parent = false
			var x_dir = 35.0 if not sprite.flip_h else -35.0
			
			# SCOOP LOGIC:
			# Start high -> Swing Wide (x * 1.5) -> Pull IN at bottom (x * 0.5)
			p0 = Vector2(0, -25)               # Shoulder height
			p1 = Vector2(x_dir * 1.4, -5)      # Swing OUT wide
			p2 = Vector2(x_dir * 0.4, 35)      # Pull IN to feet
		
		# Generate Curve
		for i in range(segments + 1):
			var t = float(i) / segments
			arc.append(get_bezier_point(t, p0, p1, p2))
		
	else:
		# === PICKAXE SWIPE (Extended Tip Radius) ===
		# [UPDATED] Radius matched to 1.0x reach to follow the tool TIP
		var arc_radius = reach * 0.7 
		
		var start_angle = 0.0
		var end_angle = 0.0
		
		if facing_dir == "down":
			slash.show_behind_parent = false
			start_angle = PI/4.0
			end_angle = 3.0*PI/4.0
		elif facing_dir == "up":
			slash.show_behind_parent = true
			start_angle = -3.0*PI/4.0
			end_angle = -PI/4.0
		elif facing_dir == "side":
			slash.show_behind_parent = false
			start_angle = -PI/3.0
			end_angle = PI/3.0
			
			if sprite.flip_h:
				start_angle = PI - start_angle
				end_angle = PI - end_angle

		for i in range(segments + 1):
			var t = float(i) / segments
			var angle = lerp(start_angle, end_angle, t)
			arc.append(Vector2(cos(angle), sin(angle)) * arc_radius)
	
	slash.points = PackedVector2Array(arc)
	slash.modulate.a = 0.0
	
	var t = create_tween()
	t.tween_property(slash, "modulate:a", 1.0, 0.05).set_trans(Tween.TRANS_QUART)
	t.tween_interval(0.05)
	t.tween_property(slash, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	t.tween_callback(slash.queue_free)

func _on_animation_finished():
	if "hit" in sprite.animation:
		is_attacking = false
		play_anim("idle")

func equip_item(texture):
	for child in hand_sprite.get_children():
		child.queue_free()

	if texture:
		var path = texture.resource_path.to_lower()
		
		if "pickaxe" in path:
			hand_sprite.texture = null
			var inst = PICKAXE_SCENE.instantiate()
			inst.name = "Pickaxe"
			_setup_tool_instance(inst)
			
		elif "hoe" in path:
			hand_sprite.texture = null
			var inst = HOE_SCENE.instantiate()
			inst.name = "Hoe"
			_setup_tool_instance(inst)
			
		else:
			hand_sprite.texture = texture
			
		hand_sprite.visible = true
		
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if input_dir != Vector2.ZERO:
			update_facing_direction(input_dir)
		else:
			if facing_dir == "side":
				if sprite.flip_h: 
					hand_sprite.scale.x = -0.6
					hand_sprite.rotation = deg_to_rad(-15)
				else:
					hand_sprite.scale.x = 0.6
					hand_sprite.rotation = deg_to_rad(15)
			else:
				hand_sprite.rotation = 0
				hand_sprite.scale.x = 0.6
	else:
		unequip_item()

func _setup_tool_instance(inst):
	inst.set_script(null)
	inst.monitoring = false
	inst.monitorable = false
	
	var col = inst.get_node_or_null("CollisionShape2D")
	if col: col.queue_free()
	
	hand_sprite.add_child(inst)
	inst.position = Vector2.ZERO
	inst.rotation_degrees = -45 

func unequip_item():
	hand_sprite.texture = null
	hand_sprite.visible = false
	for child in hand_sprite.get_children():
		child.queue_free()

func _on_server_message(data):
	if data.get("event") == "position_update":
		var server_pos = Vector2(data.get("x", 0.0), data.get("y", 0.0))
		if global_position.distance_to(server_pos) > 50.0:
			global_position = server_pos
			camera_pos_float = server_pos
			
		if data.has("hp"):
			var new_hp = data["hp"]
			if new_hp < current_hp: _on_take_damage()
			current_hp = new_hp

func _on_take_damage():
	sprite.modulate = Color(10, 0, 0)
	var t = create_tween()
	t.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)
	apply_shake(8.0)
