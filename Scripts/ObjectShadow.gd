extends Node2D

@export var target_sprite_path: NodePath
var target_sprite: Node2D
var shadow_sprite: Node2D 
var is_animated: bool = false
var notifier: VisibleOnScreenNotifier2D

# Config
const SHADOW_NUDGE = Vector2(0, -3.0) 
const NIGHT_ALPHA = 0.35 
const DAY_ALPHA = 0.55   

var flatten_y = 0.5          
var stretch_power = 4.5     
var width_multiplier = 1.0   
var skew_strength = 3.0   

func _ready():
	# [OPTIMIZATION] Create Notifier to cull off-screen logic
	notifier = VisibleOnScreenNotifier2D.new()
	# Set a reasonable bounding box (e.g., 64x64)
	notifier.rect = Rect2(-32, -32, 64, 64)
	add_child(notifier)
	
	# Connect signals
	notifier.screen_entered.connect(_on_screen_entered)
	notifier.screen_exited.connect(_on_screen_exited)
	
	if target_sprite_path: 
		target_sprite = get_node(target_sprite_path)
	else:
		var parent = get_parent()
		if parent.has_node("AnimatedSprite2D"): target_sprite = parent.get_node("AnimatedSprite2D")
		elif parent.has_node("Sprite2D"): target_sprite = parent.get_node("Sprite2D")
		elif parent.has_node("CraftingTable"): target_sprite = parent.get_node("CraftingTable") 
	
	if target_sprite:
		is_animated = (target_sprite is AnimatedSprite2D)
		create_shadow_duplicate()
	else:
		set_process(false)
	
	# Start disabled until entered screen
	set_process(false) 
	if shadow_sprite: shadow_sprite.visible = false

func _on_screen_entered():
	set_process(true)
	if shadow_sprite: shadow_sprite.visible = true

func _on_screen_exited():
	set_process(false)
	if shadow_sprite: shadow_sprite.visible = false

func create_shadow_duplicate():
	if is_animated:
		shadow_sprite = AnimatedSprite2D.new()
		shadow_sprite.sprite_frames = target_sprite.sprite_frames
	else:
		shadow_sprite = Sprite2D.new()
		shadow_sprite.texture = target_sprite.texture
		if target_sprite is Sprite2D:
			shadow_sprite.region_enabled = target_sprite.region_enabled
			if target_sprite.region_enabled:
				shadow_sprite.region_rect = target_sprite.region_rect
	
	if "centered" in target_sprite and "centered" in shadow_sprite:
		shadow_sprite.centered = target_sprite.centered
	shadow_sprite.offset = target_sprite.offset
	
	shadow_sprite.modulate = Color(0, 0, 0, DAY_ALPHA) 
	
	# Attempt to add to ShadowLayer, else local
	var layer = get_tree().root.find_child("ShadowLayer", true, false)
	if layer: layer.add_child(shadow_sprite)
	else: add_child(shadow_sprite)
	
	get_parent().tree_exiting.connect(_on_parent_exiting)

func _on_parent_exiting():
	if shadow_sprite: shadow_sprite.queue_free()

func _process(delta):
	# Validation check
	if not is_instance_valid(target_sprite) or not is_instance_valid(get_parent()):
		if shadow_sprite: shadow_sprite.queue_free()
		queue_free()
		return

	if is_instance_valid(shadow_sprite):
		shadow_sprite.global_position = target_sprite.global_position + SHADOW_NUDGE
		sync_visuals()
		update_shadow_transform()

func sync_visuals():
	if target_sprite is Node2D and "flip_h" in target_sprite:
		shadow_sprite.flip_h = target_sprite.flip_h

	if is_animated:
		shadow_sprite.animation = target_sprite.animation
		shadow_sprite.frame = target_sprite.frame

func update_shadow_transform():
	var time = NetworkManager.game_time
	
	shadow_sprite.rotation = 0
	var skew_val = -(0.5 - time) * skew_strength
	shadow_sprite.skew = skew_val
	
	var dist_from_noon = abs(time - 0.5)
	var length_factor = stretch_power
	if time > 0.85:
		var fade_in = (time - 0.85) * 5.0 
		length_factor = lerp(stretch_power, 2.0, fade_in)
		length_factor = max(length_factor, 1.0) 
	
	var dynamic_length = flatten_y + (dist_from_noon * length_factor)
	
	shadow_sprite.scale = Vector2(
		target_sprite.scale.x * width_multiplier,
		target_sprite.scale.y * dynamic_length * -1.0
	)

	var alpha = DAY_ALPHA
	if time < 0.2 || time > 0.8:
		alpha = NIGHT_ALPHA
	
	var current_color = shadow_sprite.modulate
	current_color.a = alpha
	shadow_sprite.modulate = current_color
