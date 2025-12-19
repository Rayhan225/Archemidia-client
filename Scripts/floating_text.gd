extends Label

func _ready():
	# Ensure it starts red and visible
	modulate = Color(1, 0, 0, 1)
	z_index = 100 # Draw on top of everything
	
	# Animate: Float up and Fade out
	var t = create_tween()
	t.set_parallel(true)
	# Float up by 60 pixels
	t.tween_property(self, "position:y", position.y - 60, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Fade opacity to 0
	t.tween_property(self, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# Delete after animation
	t.chain().tween_callback(queue_free)
