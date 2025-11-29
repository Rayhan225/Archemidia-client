extends CharacterBody2D

const SPEED = 200.0

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

func _ready():
	NetworkManager.server_message_received.connect(_on_server_message)
	if camera:
		camera.enabled = true
		camera.top_level = true 
		camera.position_smoothing_enabled = false
		camera.global_position = global_position
		# --- FIX: Set Camera Zoom to 1.0 ---
		camera.zoom = Vector2(1.0, 1.0)
		camera_pos_float = global_position

	hand_sprite = Sprite2D.new()
	hand_sprite.name = "HandSprite"
	add_child(hand_sprite)
	hand_sprite.position = Vector2(8, 3) 
	hand_sprite.scale = Vector2(0.6, 0.6)
	hand_sprite.z_index = 1
	
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	# Only attack on Spacebar or Enter (ui_accept)
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
			
			if global_position.distance_to(last_sent_pos) > 2.0:
				NetworkManager.send_move_request(global_position)
				last_sent_pos = global_position
		else:
			play_anim("idle")

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
	if dir.y < 0:
		facing_dir = "up"
		sprite.flip_h = false
		hand_sprite.z_index = -1 
		hand_sprite.position = Vector2(-8, -5)
	elif dir.y > 0:
		facing_dir = "down"
		sprite.flip_h = false
		hand_sprite.z_index = 1 
		hand_sprite.position = Vector2(8, 5)
	elif dir.x != 0:
		facing_dir = "side"
		sprite.flip_h = (dir.x < 0)
		if dir.x < 0: 
			hand_sprite.position.x = -10
			hand_sprite.flip_h = true
		else:
			hand_sprite.position.x = 10
			hand_sprite.flip_h = false
		hand_sprite.z_index = 1

func play_anim(action: String):
	var anim_name = action + "_" + facing_dir
	sprite.play(anim_name)

func attack():
	is_attacking = true
	play_anim("hit")
	create_hand_swipe()
	apply_shake(2.0)

func create_hand_swipe():
	var slash = Line2D.new()
	slash.width = 10.0
	slash.default_color = Color(0.701, 0.616, 0.0, 1.0) 
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0, 0.2))
	width_curve.add_point(Vector2(0.5, 1.0))
	width_curve.add_point(Vector2(1, 0.0))
	slash.width_curve = width_curve

	add_child(slash)
	
	var hand_pos = hand_sprite.position
	var arc = []
	var arc_radius = 15.0 
	var segments = 8
	var start_angle = -PI/2.0 
	var end_angle = PI/2.0
	
	if facing_dir == "up":
		start_angle = -PI 
		end_angle = 0.0 
		slash.z_index = -1 
		slash.position = hand_pos 
	elif facing_dir == "down":
		start_angle = 0.0
		end_angle = PI
		slash.z_index = 2 
		slash.position = hand_pos
	elif facing_dir == "side":
		start_angle = -PI/2.0
		end_angle = PI/2.0
		slash.z_index = 2
		slash.position = hand_pos

	for i in range(segments + 1):
		var t = float(i) / segments
		var angle = lerp(start_angle, end_angle, t)
		if sprite.flip_h and facing_dir == "side": angle = PI - angle 
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
	if texture:
		hand_sprite.texture = texture
		hand_sprite.visible = true
	else:
		unequip_item()

func unequip_item():
	hand_sprite.texture = null
	hand_sprite.visible = false

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
