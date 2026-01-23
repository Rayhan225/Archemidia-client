extends AudioStreamPlayer

var sample_hz = 44100.0
var playback: AudioStreamGeneratorPlayback

var current_sfx = ""
var timer = 0.0
var phase = 0.0

func _ready():
	stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_hz
	stream.buffer_length = 0.1
	play()
	playback = get_stream_playback()

func play_sound(name):
	current_sfx = name
	timer = 0.2 # Default duration
	phase = 0.0
	if name == "PARTY_HIT": timer = 0.3
	if name == "PARTY_MISS": timer = 0.2
	if name == "DAMAGE": timer = 0.15

func _process(delta):
	var frames = playback.get_frames_available()
	if frames < 1: return
	var dt = 1.0 / sample_hz
	
	for i in range(frames):
		var out = 0.0
		
		if timer > 0:
			timer -= dt
			
			if current_sfx == "PARTY_HIT":
				# Musical Chime (High Sine + Harmonics)
				phase += 880.0 * dt
				out = sin(phase * TAU) * 0.5
				out += sin(phase * 2.0 * TAU) * 0.2 # Harmonic
				out *= (timer / 0.3) # Fade
				
			elif current_sfx == "PARTY_MISS":
				# Low Buzz (Sawtooth)
				phase += 100.0 * dt
				out = (fmod(phase, 1.0) * 2.0 - 1.0) * 0.3
				out *= (timer / 0.2)
				
			elif current_sfx == "DAMAGE":
				# Crunch (White Noise with Low Pass feel)
				out = randf_range(-1.0, 1.0) * 0.8
				out *= (timer / 0.15)
				
		playback.push_frame(Vector2(out, out))
