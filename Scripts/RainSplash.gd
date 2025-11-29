extends Node

var splash_scene: CPUParticles2D
var timer: Timer
var is_raining = false
var world_objects_node: Node2D

func _ready():
	create_splash_template()
	
	timer = Timer.new()
	timer.wait_time = 0.02 # Faster splashes for heavy rain feel
	timer.timeout.connect(_on_spawn_splash)
	add_child(timer)

func create_splash_template():
	splash_scene = CPUParticles2D.new()
	splash_scene.amount = 4 # Fewer particles per splash, but more impactful
	splash_scene.lifetime = 0.4
	splash_scene.explosiveness = 0.95 # All burst at once
	splash_scene.direction = Vector2(0, -1) # Upwards bounce
	splash_scene.spread = 60
	splash_scene.initial_velocity_min = 60
	splash_scene.initial_velocity_max = 100
	splash_scene.gravity = Vector2(0, 400) # Fall back down fast
	
	# --- VISUALS ---
	# 1. Scale Curve (Pop effect: Small -> Big -> Gone)
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.2, 1.2)) # Pop!
	curve.add_point(Vector2(1, 0.0))   # Fade
	splash_scene.scale_amount_curve = curve
	splash_scene.scale_amount_min = 2.0 # Make them visible pixels
	splash_scene.scale_amount_max = 3.0
	
	# 2. Color Gradient (White -> Transparent Blueish)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1)) # Pure White Start
	gradient.add_point(0.7, Color(0.8, 0.9, 1.0, 0.8)) # Light Blue tint
	gradient.add_point(1.0, Color(0.5, 0.5, 1.0, 0.0)) # Transparent End
	splash_scene.color_ramp = gradient
	
	splash_scene.emitting = false
	splash_scene.one_shot = true

func _process(delta):
	var parent = get_parent()
	if "is_raining" in parent:
		if parent.is_raining and not is_raining:
			is_raining = true
			var root = get_tree().root.get_node_or_null("World") 
			if root:
				world_objects_node = root.get_node_or_null("Objects")
			timer.start()
		elif not parent.is_raining and is_raining:
			is_raining = false
			timer.stop()

func _on_spawn_splash():
	if not is_raining: return
	
	var vp = get_viewport().get_visible_rect()
	var cam = get_tree().root.find_child("Camera2D", true, false)
	if not cam: return
	
	var center = cam.global_position
	var half_size = vp.size / 2 / cam.zoom 
	var view_rect = Rect2(center - half_size, vp.size / cam.zoom)

	# 1. Splash on Objects (The "Wet" look)
	if world_objects_node:
		for child in world_objects_node.get_children():
			if child is Node2D and view_rect.has_point(child.global_position):
				# 15% chance per frame to splash on a visible object
				if randf() < 0.15: 
					# Offset slightly to simulate hitting the top/side of sprite
					var random_offset = Vector2(randf_range(-10, 10), randf_range(-25, -5))
					spawn_single_splash(child.global_position + random_offset)

	# 2. Splash on Ground
	# Spawn 3-5 random ground splashes per tick
	for i in range(randi_range(3, 5)):
		var rand_pos = center + Vector2(randf_range(-half_size.x, half_size.x), randf_range(-half_size.y, half_size.y))
		spawn_single_splash(rand_pos)

func spawn_single_splash(pos):
	var splash = splash_scene.duplicate()
	splash.global_position = pos
	
	# Add to World node so it stays still relative to map
	var world = get_tree().root.get_node_or_null("World")
	if world:
		world.add_child(splash)
	else:
		get_parent().add_child(splash)
		
	splash.emitting = true
	
	# Cleanup
	var t = get_tree().create_timer(splash.lifetime + 0.1)
	t.timeout.connect(splash.queue_free)
