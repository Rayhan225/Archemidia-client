extends CharacterBody2D

@onready var sprite = $AnimatedSprite2D
@onready var name_label = $NameLabel # Ensure you add a Label named "NameLabel" to the scene

# Interpolation Variables
var target_pos = Vector2.ZERO
var facing_dir = 0 # 0=Down, 1=Up, 2=Left, 3=Right

func _ready():
	# Default Color
	modulate = Color.WHITE
	
	# --- ENABLE COLLISION ---
	# Layer 2 = Player, Mask 1 = World, Mask 2 = Other Players
	collision_layer = 2 
	collision_mask = 3 
	
	# Ensure shape exists
	if not has_node("CollisionShape2D"):
		var shape = CollisionShape2D.new()
		var cap = CapsuleShape2D.new()
		cap.radius = 6; cap.height = 12
		shape.shape = cap
		add_child(shape)

func update_state(pos_x, pos_y, dir):
	target_pos = Vector2(pos_x, pos_y)
	facing_dir = dir

# --- NEW: VISUALS ---
func set_avatar_id(id):
	# Simple Tint Logic for Avatars
	var color = Color.WHITE
	match id:
		1: color = Color(1, 0.4, 0.4) # Red
		2: color = Color(0.4, 1, 0.4) # Green
		3: color = Color(0.4, 0.6, 1) # Blue
		_: color = Color.WHITE        # Default
	
	if sprite:
		sprite.modulate = color

func set_name_label(text_str):
	if name_label:
		name_label.text = text_str

func _physics_process(delta):
	# Smooth movement interpolation
	position = position.lerp(target_pos, 15 * delta)
	update_animation()

func update_animation():
	if not sprite: return
	
	var anim = "idle_down"
	var flip = false
	
	if facing_dir == 0:
		anim = "walk_down" if position.distance_to(target_pos) > 2 else "idle_down"
	elif facing_dir == 1:
		anim = "walk_up" if position.distance_to(target_pos) > 2 else "idle_up"
	elif facing_dir == 2:
		anim = "walk_side" if position.distance_to(target_pos) > 2 else "idle_side"
		flip = false # Left
	elif facing_dir == 3:
		anim = "walk_side" if position.distance_to(target_pos) > 2 else "idle_side"
		flip = true # Right (Flip Side)

	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		sprite.flip_h = flip
