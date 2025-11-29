extends Node2D

@onready var sun_light = $DirectionalLight2D
@onready var ambient_light = $CanvasModulate

var rain_particles: CPUParticles2D 

var time_of_day = 0.0
var days_passed = 0
var last_time = 0.0

# --- NEUTRAL COLORS (Grayscale = No Color Shift) ---
# We only change the brightness (Value), keeping RGB equal.
var color_midnight = Color(0.4, 0.4, 0.4, 1.0) # Dark Grey (Night)
var color_sunrise = Color(0.7, 0.7, 0.7, 1.0)  # Light Grey (Transition)
var color_noon = Color(1.0, 1.0, 1.0, 1.0)     # Pure White (Day)
var color_sunset = Color(0.7, 0.7, 0.7, 1.0)   # Light Grey (Transition)
var color_rain = Color(0.6, 0.6, 0.6, 1.0)     # Grey (Rain)

var is_raining = false
var rain_chance = 0.0 

func _ready():
	if not has_node("RainParticles"):
		create_rain_particles()

func _process(delta):
	time_of_day = NetworkManager.game_time
	
	if time_of_day < last_time:
		days_passed += 1
	last_time = time_of_day

	# 1. ROTATE THE SUN (Keeps 3D Shadows)
	if sun_light:
		var sun_rotation = (time_of_day * 360.0) - 90.0
		sun_light.rotation_degrees = sun_rotation
		sun_light.height = 0.5 

	# 2. BRIGHTNESS LOGIC
	var target_color = get_time_color(time_of_day)

	if days_passed >= 1:
		if not is_raining:
			if randf() < rain_chance: start_rain()
		else:
			if randf() < 0.001: stop_rain()
	
	if is_raining:
		target_color = target_color.lerp(color_rain, 0.7)
		if sun_light: sun_light.energy = lerp(sun_light.energy, 0.5, 0.05)
	else:
		var target_energy = 0.0
		# Day = Bright Sun, Night = No Sun
		if time_of_day > 0.2 and time_of_day < 0.8: target_energy = 1.0 
		if sun_light: sun_light.energy = lerp(sun_light.energy, target_energy, 0.05)
	
	# Apply the grayscale color to CanvasModulate (Affects whole screen brightness)
	if ambient_light: ambient_light.color = ambient_light.color.lerp(target_color, 0.02)

func get_time_color(t):
	if t < 0.2: 
		return color_midnight
	elif t < 0.35: 
		return color_midnight.lerp(color_sunrise, (t - 0.2) * 6.66)
	elif t < 0.65: 
		if t < 0.5: return color_sunrise.lerp(color_noon, (t - 0.35) * 6.66)
		else: return color_noon.lerp(color_sunset, (t - 0.5) * 6.66)
	elif t < 0.8: 
		return color_sunset.lerp(color_midnight, (t - 0.65) * 6.66)
	else: 
		return color_midnight

func start_rain():
	is_raining = true
	if rain_particles: rain_particles.emitting = true

func stop_rain():
	is_raining = false
	if rain_particles: rain_particles.emitting = false

func create_rain_particles():
	# (Same as before)
	rain_particles = CPUParticles2D.new()
	rain_particles.name = "RainParticles"
	rain_particles.amount = 2000 
	rain_particles.lifetime = 0.7
	rain_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain_particles.emission_rect_extents = Vector2(1000, 600)
	rain_particles.direction = Vector2(-0.2, 1).normalized()
	rain_particles.gravity = Vector2(0, 0)
	rain_particles.initial_velocity_min = 1000
	rain_particles.initial_velocity_max = 1500
	rain_particles.scale_amount_min = 1.5
	rain_particles.scale_amount_max = 2.5
	rain_particles.color = Color(0.8, 0.85, 1.0, 0.5) 
	rain_particles.emitting = false
	
	var layer = CanvasLayer.new()
	layer.layer = 1 
	add_child(layer)
	layer.add_child(rain_particles)
	
	rain_particles.position = Vector2(576, 0) 
	
	var splash_gen = Node.new()
	if ResourceLoader.exists("res://Scripts/RainSplash.gd"):
		splash_gen.set_script(load("res://Scripts/RainSplash.gd"))
		add_child(splash_gen)
