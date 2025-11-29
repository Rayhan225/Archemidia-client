extends Node2D

@export var target_sprite_path: NodePath
var target_sprite: Node2D
var shadow_sprite: Node2D
var is_animated: bool = false

func _ready():
	if target_sprite_path: target_sprite = get_node(target_sprite_path)
	else:
		var parent = get_parent()
		if parent.has_node("AnimatedSprite2D"): target_sprite = parent.get_node("AnimatedSprite2D")
		elif parent.has_node("Sprite2D"): target_sprite = parent.get_node("Sprite2D")
	
	if target_sprite:
		is_animated = (target_sprite is AnimatedSprite2D)
		create_shadow_duplicate()
	else:
		set_process(false)

func create_shadow_duplicate():
	if is_animated:
		shadow_sprite = AnimatedSprite2D.new()
		shadow_sprite.sprite_frames = target_sprite.sprite_frames
	else:
		shadow_sprite = Sprite2D.new()
		shadow_sprite.texture = target_sprite.texture
		# Region Support
		shadow_sprite.region_enabled = target_sprite.region_enabled
		if target_sprite.region_enabled:
			shadow_sprite.region_rect = target_sprite.region_rect

	shadow_sprite.offset = target_sprite.offset
	shadow_sprite.modulate = Color(1,1,1,1)
	
	var layer = get_tree().root.find_child("ShadowLayer", true, false)
	if layer: layer.add_child(shadow_sprite)
	else: add_child(shadow_sprite)
	
	get_parent().tree_exiting.connect(_on_parent_exiting)

func _on_parent_exiting():
	if shadow_sprite: shadow_sprite.queue_free()

func _process(delta):
	if not is_instance_valid(target_sprite) or not is_instance_valid(get_parent()):
		if shadow_sprite: shadow_sprite.queue_free()
		queue_free()
		return

	if is_instance_valid(shadow_sprite):
		shadow_sprite.global_position = get_parent().global_position
		sync_visuals()
		update_transform()

func sync_visuals():
	shadow_sprite.flip_h = target_sprite.flip_h
	if is_animated:
		shadow_sprite.animation = target_sprite.animation
		shadow_sprite.frame = target_sprite.frame
	if not target_sprite.visible: shadow_sprite.visible = false; return
	shadow_sprite.modulate.a = target_sprite.modulate.a

func update_transform():
	var time = NetworkManager.game_time
	# Shadow visible only during day (0.2 to 0.8)
	if time < 0.20 or time > 0.80: 
		shadow_sprite.visible = false
		return
	else: 
		shadow_sprite.visible = true

	# --- SHADOW DIRECTION FIX ---
	# 0.2 (Sunrise) -> Skew Left (-1.0)
	# 0.5 (Noon)    -> Skew 0
	# 0.8 (Sunset)  -> Skew Right (1.0)
	
	# Remap time 0.2->0.8 to -1.5->1.5
	var skew_val = (time - 0.5) * 5.0 
	
	shadow_sprite.skew = skew_val
	
	# Scale Y based on how low the sun is (Noon = shortest shadow)
	var dist_from_noon = abs(time - 0.7) # 0 at noon, 0.3 at sunset
	var h = 0.3 + (dist_from_noon * 4.0)
	
	shadow_sprite.scale = Vector2(target_sprite.scale.x, target_sprite.scale.y * h)
