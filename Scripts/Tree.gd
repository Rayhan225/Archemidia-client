extends StaticBody2D

@onready var sprite = $AnimatedSprite2D
@onready var area = $OcclusionArea
var tween: Tween
var bodies_behind = []

func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	# Also track Areas (drops)
	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)

func _on_body_entered(body):
	if body.name == "Player":
		bodies_behind.append(body)
		update_fade()

func _on_body_exited(body):
	if body in bodies_behind:
		bodies_behind.erase(body)
		update_fade()

func _on_area_entered(area_obj):
	# Assuming drops are areas
	if area_obj.has_method("collect"): 
		bodies_behind.append(area_obj)
		update_fade()

func _on_area_exited(area_obj):
	if area_obj in bodies_behind:
		bodies_behind.erase(area_obj)
		update_fade()

func update_fade():
	if tween: tween.kill()
	tween = create_tween()
	
	if bodies_behind.size() > 0:
		tween.tween_property(sprite, "modulate:a", 0.4, 0.2)
	else:
		tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
