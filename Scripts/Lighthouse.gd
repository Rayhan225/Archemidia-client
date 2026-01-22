extends StaticBody2D

@onready var sprite = $AnimatedSprite2D
@onready var occlusion_area = $OcclusionArea
@onready var beam_light = $BeamLight

# Config
var total_frames = 14
var rotation_offset = 0.0 # Adjust this if light points wrong way at frame 0

func _ready():
	sprite.play("default")
	
	# Initial setup
	if occlusion_area:
		occlusion_area.body_entered.connect(_on_body_entered)
		occlusion_area.body_exited.connect(_on_body_exited)

func _process(delta):
	if is_instance_valid(beam_light) and is_instance_valid(sprite):
		update_light_rotation()

func update_light_rotation():
	# 1. Get current frame (0 to 13)
	var current_frame = sprite.frame
	
	# 2. Calculate fraction (0.0 to 1.0)
	var fraction = float(current_frame) / float(total_frames)
	
	# 3. Convert to Angle (Radians)
	# We multiply by TAU (2 * PI) which is a full circle (360 degrees)
	var target_angle = fraction * TAU
	
	# 4. Apply rotation
	beam_light.rotation = target_angle + rotation_offset

func _on_body_entered(body):
	if body.name == "Player":
		var t = create_tween()
		t.tween_property(sprite, "modulate:a", 0.5, 0.2)

func _on_body_exited(body):
	if body.name == "Player":
		var t = create_tween()
		t.tween_property(sprite, "modulate:a", 1.0, 0.2)
