extends PointLight2D

@export var min_energy = 0.8
@export var max_energy = 1.2
@export var flicker_speed = 5.0

var noise = FastNoiseLite.new()
var time_passed = 0.0

func _ready():
	noise.seed = randi()
	noise.frequency = 2.0
	color = Color(1.0, 0.6, 0.2) # Orange Fire Color
	texture_scale = 3.0 # Size of the glow

func _process(delta):
	time_passed += delta * flicker_speed
	
	# Generate noise between -1 and 1
	var n = noise.get_noise_1d(time_passed)
	
	# Remap to energy range
	var energy_variance = (n + 1.0) / 2.0 # 0 to 1
	energy = lerp(min_energy, max_energy, energy_variance)
	
	# Optional: Slight position wobble for "dancing" fire
	position = Vector2(noise.get_noise_1d(time_passed + 100) * 2, noise.get_noise_1d(time_passed + 200) * 2)
