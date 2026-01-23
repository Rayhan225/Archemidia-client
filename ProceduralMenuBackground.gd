extends Control

# --- CONFIG: COZY COLORS ---
var sky_top_color = Color(0.2, 0.6, 1.0) # Bright Blue
var sky_horizon_color = Color(0.6, 0.9, 1.0) # Cyan-ish
var sun_color = Color(1.0, 0.9, 0.4)
var hill_back_color = Color(0.2, 0.5, 0.3)
var hill_front_color = Color(0.3, 0.7, 0.4) # Bright Green

# Scroll Animation
var scroll_offset = 0.0
var time_passed = 0.0

# Cloud Data: [x, y, scale, speed]
var clouds = []

func _ready():
	# Initialize random clouds
	for i in range(5):
		_spawn_cloud(randf() * size.x)

func _process(delta):
	scroll_offset += delta * 60.0 # Speed of hills
	time_passed += delta * 0.5 # Speed of sky animation
	
	# Update Clouds
	for c in clouds:
		c[0] -= delta * c[3] # Move left
		if c[0] < -100: # Wrap around
			c[0] = size.x + 100
			c[1] = randf_range(20, size.y * 0.4)
	
	queue_redraw()

func _spawn_cloud(x_start):
	clouds.append([
		x_start,                  # X
		randf_range(20, 200),     # Y
		randf_range(0.8, 1.5),    # Scale
		randf_range(10, 30)       # Speed
	])

func _draw():
	var w = size.x
	var h = size.y
	
	# 1. Dynamic Sky Gradient
	# Gentle pulse of the horizon color
	var current_horizon = sky_horizon_color.lerp(Color(0.9, 0.7, 0.6), sin(time_passed) * 0.3 + 0.3)
	draw_rect_filled_gradient(Rect2(0, 0, w, h), sky_top_color, current_horizon)
	
	# 2. Draw Sun (Bobbing slightly)
	var sun_y = h * 0.15 + sin(time_passed * 0.5) * 10.0
	var sun_pos = Vector2(w * 0.85, sun_y)
	draw_circle(sun_pos, 45, Color(1, 0.9, 0.6, 0.4)) # Glow halo
	draw_circle(sun_pos, 35, sun_color) # Sun core

	# 3. Draw Clouds (Behind hills)
	for c in clouds:
		draw_cloud(Vector2(c[0], c[1]), c[2])

	# 4. Procedural Hills (Back Layer - Slower parallax)
	draw_hills(h * 0.65, 120.0, 0.5, hill_back_color)

	# 5. Procedural Hills (Front Layer - Faster)
	draw_hills(h * 0.8, 80.0, 1.0, hill_front_color)

func draw_hills(base_y, amplitude, scroll_mult, color):
	var w = size.x
	var h = size.y
	var points = PackedVector2Array()
	
	# Start bottom-left
	points.append(Vector2(0, h))
	points.append(Vector2(0, base_y))
	
	var resolution = 20.0
	var segments = ceil(w / resolution)
	
	for i in range(segments + 2):
		var x = i * resolution
		# Create rolling wave using sine + noise-like math
		var real_x = x + (scroll_offset * scroll_mult)
		var y_offset = sin(real_x * 0.005) * amplitude + sin(real_x * 0.02) * (amplitude * 0.3)
		points.append(Vector2(x, base_y + y_offset))
	
	# End bottom-right
	points.append(Vector2(w, h))
	
	draw_colored_polygon(points, color)

func draw_cloud(pos, scale):
	# Simple puff cloud using circles
	var color = Color(1, 1, 1, 0.8)
	draw_circle(pos, 20 * scale, color)
	draw_circle(pos + Vector2(-15, 5) * scale, 15 * scale, color)
	draw_circle(pos + Vector2(15, 5) * scale, 15 * scale, color)

# Helper for gradient background
func draw_rect_filled_gradient(rect, c_top, c_btm):
	var verts = PackedVector2Array([
		rect.position, 
		Vector2(rect.end.x, rect.position.y), 
		rect.end, 
		Vector2(rect.position.x, rect.end.y)
	])
	var colors = PackedColorArray([c_top, c_top, c_btm, c_btm])
	draw_polygon(verts, colors)
