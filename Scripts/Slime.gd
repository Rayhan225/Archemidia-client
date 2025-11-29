extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = null 

# --- INTERPOLATION VARS ---
var buffer_pos_a = Vector2.ZERO # The position we are coming FROM
var buffer_pos_b = Vector2.ZERO # The position we are going TO
var last_packet_time = 0.0
var tick_rate = 0.05 # 50ms (Matches Server Tick)

var monster_id = ""
var hp = 10
var server_state = "IDLE"

# Visuals
var facing_dir = "down" 
var is_locked = false
var hp_timer = 0.0 
var bounce_time = 0.0 

func _ready():
	# Initialize buffers to current position to prevent start-up snapping
	buffer_pos_a = global_position
	buffer_pos_b = global_position
	sprite.animation_finished.connect(_on_anim_finished)
	create_hp_bar()

func setup(data):
	monster_id = data["id"]
	global_position = Vector2(data["x"], data["y"])
	
	# Reset interpolation buffers on spawn
	buffer_pos_a = global_position
	buffer_pos_b = global_position
	
	update_state(data)

func update_state(data):
	if data.has("x") and data.has("y"):
		var new_server_pos = Vector2(data["x"], data["y"])
		
		# 1. Shift Buffers: Old Target (B) becomes new Start (A)
		buffer_pos_a = buffer_pos_b
		buffer_pos_b = new_server_pos
		
		# 2. Reset Timer
		last_packet_time = Time.get_ticks_msec() / 1000.0
		
		# 3. Teleport if distance is too large (lag spike or spawn)
		if buffer_pos_a.distance_to(buffer_pos_b) > 200:
			global_position = buffer_pos_b
			buffer_pos_a = buffer_pos_b

	if data.has("hp"):
		var new_hp = data["hp"]
		if new_hp < hp:
			animate_hp_loss(hp, new_hp)
		hp = new_hp
		if hp_bar: hp_bar.value = hp

	if data.has("state"):
		var new_state = data["state"]
		if new_state == "HURT":
			if not is_locked:
				play_priority_anim("hurt", 0.4)
				flash_damage()
				hp_bar.visible = true
				hp_timer = 3.0
		elif new_state == "ATTACK":
			play_priority_anim("attack", 0.8) 
		server_state = new_state

func _physics_process(delta):
	# --- INTERPOLATION LOGIC ---
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_packet = current_time - last_packet_time
	
	# Calculate percentage (0.0 to 1.0) of the way through the current tick
	var t = clamp(time_since_packet / tick_rate, 0.0, 1.0)
	
	# Smoothly slide from A to B
	global_position = buffer_pos_a.lerp(buffer_pos_b, t)

	# --- VISUALS ---
	if hp_timer > 0:
		hp_timer -= delta
		if hp_timer <= 0: hp_bar.visible = false

	# Calculate movement vector based on buffers, not raw position
	var move_vec = buffer_pos_b - buffer_pos_a
	var is_moving = move_vec.length_squared() > 1.0

	if is_moving:
		bounce_time += delta * 15.0 
		sprite.offset.y = -8 + (sin(bounce_time) * 4.0) 
		sprite.scale.x = 1.0 + (cos(bounce_time) * 0.05)
		sprite.scale.y = 1.0 - (cos(bounce_time) * 0.05)
		
		# Determine Facing
		if abs(move_vec.x) > abs(move_vec.y):
			facing_dir = "right" if move_vec.x > 0 else "left"
		else:
			facing_dir = "down" if move_vec.y > 0 else "up"
	else:
		bounce_time = 0
		sprite.offset.y = lerp(sprite.offset.y, -8.0, 10 * delta)
		sprite.scale = sprite.scale.lerp(Vector2(1.0, 1.0), 10 * delta)

	if is_locked: return

	var anim_prefix = "idle"
	if is_moving:
		if server_state == "CHASE" or server_state == "RETREAT":
			anim_prefix = "run"
		else:
			anim_prefix = "walk"
	
	play_dir_anim(anim_prefix)

# ... [Keep your existing helper functions below: create_hp_bar, play_dir_anim, _on_anim_finished, play_priority_anim, flash_damage, destroy] ...
# (They do not need changes, just paste them here from your original file)
func create_hp_bar():
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.max_value = 10
	hp_bar.value = 10
	hp_bar.custom_minimum_size = Vector2(24, 4)
	hp_bar.position = Vector2(-12, -20)
	hp_bar.modulate = Color(1, 0, 0)
	hp_bar.visible = false
	var style_bg = StyleBoxFlat.new(); style_bg.bg_color = Color(0.2,0,0); style_bg.corner_radius_top_left=2; style_bg.corner_radius_top_right=2; style_bg.corner_radius_bottom_left=2; style_bg.corner_radius_bottom_right=2
	var style_fg = StyleBoxFlat.new(); style_fg.bg_color = Color(1,0.2,0.2); style_fg.corner_radius_top_left=2; style_fg.corner_radius_top_right=2; style_fg.corner_radius_bottom_left=2; style_fg.corner_radius_bottom_right=2
	hp_bar.add_theme_stylebox_override("background", style_bg)
	hp_bar.add_theme_stylebox_override("fill", style_fg)
	add_child(hp_bar)

func animate_hp_loss(old_hp, new_hp):
	var t = create_tween()
	t.tween_property(hp_bar, "value", new_hp, 0.2).from(old_hp)
	var t2 = create_tween()
	t2.tween_property(sprite, "offset:x", 2, 0.05)
	t2.tween_property(sprite, "offset:x", -2, 0.05)
	t2.tween_property(sprite, "offset:x", 0, 0.05)

func play_dir_anim(prefix):
	var anim_name = prefix + "_" + facing_dir
	if not sprite.sprite_frames.has_animation(anim_name):
		if sprite.sprite_frames.has_animation(prefix): anim_name = prefix 
		elif sprite.sprite_frames.has_animation("idle_" + facing_dir): anim_name = "idle_" + facing_dir 
	if sprite.animation != anim_name: sprite.play(anim_name)
	if not sprite.is_playing(): sprite.play(anim_name)

func _on_anim_finished():
	if is_locked: is_locked = false; return
	sprite.play()

func play_priority_anim(prefix, duration):
	is_locked = true
	var anim_name = prefix + "_" + facing_dir
	if not sprite.sprite_frames.has_animation(anim_name): anim_name = prefix
	if sprite.sprite_frames.has_animation(anim_name): sprite.play(anim_name)
	else: is_locked = false 
	await get_tree().create_timer(duration).timeout
	is_locked = false

func flash_damage():
	modulate = Color(10, 5, 5)
	var t = create_tween()
	t.tween_property(self, "modulate", Color(1,1,1), 0.2)

func destroy():
	is_locked = true
	var death_anim = "death_" + facing_dir
	if not sprite.sprite_frames.has_animation(death_anim): death_anim = "death"
	if sprite.sprite_frames.has_animation(death_anim): sprite.play(death_anim)
	var t = create_tween()
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	t.parallel().tween_property(self, "scale", Vector2.ZERO, 0.8)
	await t.finished
	queue_free()
