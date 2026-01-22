extends Node2D

@onready var poly = $Polygon2D
@onready var crop_sprite = $CropSprite

var current_crop_type = null
var current_stage = 0

func _ready():
	# Center visuals
	poly.position = Vector2(32, 32)
	crop_sprite.position = Vector2(32, 16) # Slightly higher to sit on top

func update_data(data):
	# Parse crop data from the object JSON sent by server
	var s_crop = data.get("cropType", null)
	var s_stage = int(data.get("cropStage", 0))
	
	current_crop_type = s_crop
	current_stage = s_stage
	
	if current_crop_type == "Turnip":
		crop_sprite.visible = true
		crop_sprite.frame = current_stage # 0, 1, 2, or 3
		
		# Optional: Shake effect if hit
		if data.get("hit_anim", false):
			var t = create_tween()
			crop_sprite.rotation_degrees = 10
			t.tween_property(crop_sprite, "rotation_degrees", 0, 0.1).set_trans(Tween.TRANS_BOUNCE)
	else:
		crop_sprite.visible = false

# Called by WorldBuilder when syncing objects
func set_state(data):
	update_data(data)
