extends CanvasLayer

# --- NODES ---
@onready var visualizer = $CenterContainer/Panel/Visualizer
@onready var score_lbl = $CenterContainer/Panel/ScoreLabel
@onready var status_lbl = $CenterContainer/Panel/StatusLabel
# Ensure this matches the name in your Scene Tree (CloseButton vs CloseBtn)
@onready var close_btn = $CenterContainer/Panel/CloseButton 

# --- RHYTHM VARIABLES ---
var base_bpm = 120.0
var current_bpm = 120.0
var beat_interval = 60.0 / 120.0
var time_tracker = 0.0
var is_beat_window = false
var beat_window_duration = 0.15 

# --- VISUAL VARIABLES ---
var head_offset = 0.0
var scale_pulse = 1.0
var bg_color = Color(0.1, 0.05, 0.2)
var hype_level = 0
var score = 0

func _ready():
	# 1. Connect UI (Fail-safe check)
	if close_btn:
		close_btn.pressed.connect(_on_close)
	else:
		# Fallback search if name is different
		var found = find_child("CloseBtn", true, false)
		if found: found.pressed.connect(_on_close)

	# 2. Connect Network
	if not NetworkManager.server_message_received.is_connected(_on_server):
		NetworkManager.server_message_received.connect(_on_server)
		
	# 3. Initialize Game State on Server
	NetworkManager.send_data({"action": "start_party"})
	
	# 4. Setup Drawing Loop
	visualizer.draw.connect(_on_draw_party)
	
	# 5. Start Party Music (Procedural)
	# Check for AudioManager to prevent crashes if not set up
	if get_tree().root.has_node("AudioManager"):
		AudioManager.play_party_music(base_bpm)

func _on_close():
	# Switch back to cozy world music
	if get_tree().root.has_node("AudioManager"):
		AudioManager.play_world_music()
	queue_free()

func _process(delta):
	time_tracker += delta
	
	# --- BEAT LOGIC ---
	if time_tracker >= beat_interval:
		time_tracker -= beat_interval
		_on_beat_hit()
	
	# Hit Window Calculation (Player can hit slightly before or after beat)
	if time_tracker < beat_window_duration or time_tracker > (beat_interval - beat_window_duration):
		is_beat_window = true
	else:
		is_beat_window = false
	
	# --- VISUAL SMOOTHING ---
	head_offset = move_toward(head_offset, 0, delta * 50.0)
	scale_pulse = move_toward(scale_pulse, 1.0, delta * 2.0)
	
	visualizer.queue_redraw()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		
	# The Core Gameplay Action: Press 'A'
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		if is_beat_window:
			_success_hit()
		else:
			_fail_hit()

func _on_beat_hit():
	# Visual "Kick" on the beat
	head_offset = 15.0 
	scale_pulse = 1.1 + (hype_level * 0.005) 
	
	# Disco Lights logic (only when hyped)
	if hype_level > 50:
		bg_color = Color(randf(), randf(), randf()).darkened(0.7)

func _success_hit():
	NetworkManager.send_data({"action": "party_hit"})
	
	# Visual Feedback
	status_lbl.text = "PERFECT!"
	status_lbl.modulate = Color.GREEN
	visualizer.modulate = Color(1.5, 1.5, 1.5) # Flash bright
	
	# Audio Feedback (Chime)
	if get_tree().root.has_node("AudioManager"):
		AudioManager.play_party_hit()
	
	# Reset flash shortly after
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(visualizer):
		visualizer.modulate = Color.WHITE

func _fail_hit():
	NetworkManager.send_data({"action": "party_miss"})
	
	# Visual Feedback
	status_lbl.text = "MISS!"
	status_lbl.modulate = Color.RED
	head_offset = -10.0 # Awkward jerk
	
	# Audio Feedback (Buzz)
	if get_tree().root.has_node("AudioManager"):
		AudioManager.play_party_miss()

func _on_server(data):
	if data.get("event") == "party_update":
		var g = data["data"]
		score = g["score"]
		hype_level = g["hypeLevel"]
		
		score_lbl.text = "Score: " + str(score) + " (Hype: " + str(hype_level) + "%)"
		
		# --- DYNAMIC DIFFICULTY ---
		# As hype increases, speed up the game!
		current_bpm = base_bpm + (hype_level * 0.5) 
		beat_interval = 60.0 / current_bpm
		
		# Update the music generator to match new speed
		if get_tree().root.has_node("AudioManager"):
			AudioManager.set_music_bpm(current_bpm)

func _on_draw_party():
	var c = visualizer
	var center = c.size / 2
	
	# 1. Background (Disco Floor)
	c.draw_rect(Rect2(0, 0, c.size.x, c.size.y), bg_color)
	
	# Apply Pulse Scale (The whole scene bumps to the beat)
	var matrix = Transform2D()
	matrix = matrix.scaled(Vector2(scale_pulse, scale_pulse))
	matrix.origin = center - (center * scale_pulse) 
	c.draw_set_transform_matrix(matrix)
	
	# 2. Draw "The Dude" (Pixel Art Style)
	var dude_color = Color.CYAN
	if hype_level > 80: dude_color = Color.GOLD # Go Super Saiyan at max hype
	
	# Body
	c.draw_rect(Rect2(center.x - 20, center.y, 40, 60), dude_color)
	
	# Head (Bobbing up and down via head_offset)
	var head_y = center.y - 40 + head_offset
	c.draw_circle(Vector2(center.x, head_y), 25, dude_color)
	
	# Sunglasses
	c.draw_rect(Rect2(center.x - 20, head_y - 5, 40, 10), Color.BLACK)
	
	# Arms (Raise higher as hype increases)
	var arm_up_factor = min(hype_level, 50) 
	var arm_width = 8.0
	# Left Arm
	c.draw_line(Vector2(center.x - 20, center.y + 10), Vector2(center.x - 50, center.y + 30 - arm_up_factor), dude_color, arm_width)
	# Right Arm
	c.draw_line(Vector2(center.x + 20, center.y + 10), Vector2(center.x + 50, center.y + 30 - arm_up_factor), dude_color, arm_width)
	
	# 3. Confetti Particles
	if hype_level > 30:
		for i in range(5):
			# Draw random colored squares
			var r_pos = Vector2(randf_range(0, c.size.x), randf_range(0, c.size.y))
			c.draw_rect(Rect2(r_pos, Vector2(4,4)), Color(randf(), randf(), randf()))
