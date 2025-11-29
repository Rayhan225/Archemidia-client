extends ParallaxBackground

func _ready():
	# Ensure it is behind everything else
	layer = -100 
	
	# Find the shader node
	var color_rect = $ParallaxLayer/ColorRect
	
	# Set the size to be MASSIVE so it covers any screen resolution
	# 4000x4000 pixels is plenty for a buffer
	color_rect.size = Vector2(4000, 4000)
	
	# Center the rect relative to the parent
	color_rect.position = -color_rect.size / 2

func _process(delta):
	# We don't need manual movement logic because we are using 
	# a ParallaxBackground node which handles camera following automatically!
	pass
