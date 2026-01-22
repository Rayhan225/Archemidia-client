extends Area2D

var item_name = "Wood"
var collected = false
var can_collect = false 
var is_player_dropped = false 
var activation_distance = 64.0 # Reduced for snappier feel

@onready var sprite = $Sprite2D

func _ready():
	collision_layer = 0 # No physics collision
	collision_mask = 1  # Only detect Player (Layer 1)
	monitoring = true
	monitorable = false # Don't let others detect me
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 24
	shape.shape = circle
	add_child(shape)
	
	body_entered.connect(_on_body_entered)
	
	# Setup Visuals (Floating animation)
	if sprite:
		var t = create_tween().set_loops()
		t.tween_property(sprite, "position:y", -5, 1.0).set_trans(Tween.TRANS_SINE)
		t.tween_property(sprite, "position:y", 0, 1.0).set_trans(Tween.TRANS_SINE)

func setup(type, dropped_by_player = false):
	item_name = type
	is_player_dropped = dropped_by_player
	
	# Icon Loader
	if sprite:
		var path = "res://Assets/" + item_name + ".png"
		# Handle specific overrides if filenames differ
		if item_name == "Wood": path = "res://Assets/icons/Wood.png"
		elif item_name == "Stone": path = "res://Assets/icons/Stone.png"
		elif item_name == "Rope": path = "res://Assets/icons/Rope.png"
		elif item_name == "Turnip": path = "res://Assets/icons/Turnip.png" # Example
		
		if ResourceLoader.exists(path):
			sprite.texture = load(path)
		else:
			# Fallback to name
			path = "res://Assets/" + item_name + ".png"
			if ResourceLoader.exists(path): sprite.texture = load(path)

	# Pickup Delay Logic
	if not is_player_dropped:
		# Natural drop: small delay so it spawns before pickup
		can_collect = false
		await get_tree().create_timer(0.4).timeout
		can_collect = true
		_check_overlap()
	else:
		# Player drop: must walk away first
		can_collect = false

func _physics_process(_delta):
	if is_player_dropped and not can_collect:
		var player = get_tree().root.find_child("Player", true, false)
		if player:
			var dist = global_position.distance_to(player.global_position)
			# Re-enable pickup if player walked far enough away
			if dist > activation_distance:
				can_collect = true

func _check_overlap():
	for body in get_overlapping_bodies():
		if body.name == "Player":
			_on_body_entered(body)

func _on_body_entered(body):
	if collected or not can_collect: return
	if body.name == "Player":
		collected = true
		collect()

func collect():
	# 1. Notify Server
	NetworkManager.send_collect_item(item_name)
	
	# 2. Visual Feedback (Shrink and Delete)
	set_physics_process(false)
	monitoring = false # Stop detecting
	
	var t = create_tween()
	t.tween_property(self, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)
