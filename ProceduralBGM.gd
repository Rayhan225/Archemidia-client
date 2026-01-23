extends AudioStreamPlayer

# Audio settings
var sample_rate = 44100.0
# C Major Pentatonic scale frequencies (C4, D4, E4, G4, A4)
var scale_notes = [261.63, 293.66, 329.63, 392.00, 440.00] 
var current_note_freq = 261.63
var next_note_time = 0.0
var note_duration = 2.0 # Slow tempo
var phase = 0.0
var playback: AudioStreamGeneratorPlayback # The actual buffer we fill

func _ready():
	# The stream must be set to AudioStreamGenerator in the inspector beforehand
	play()
	playback = get_stream_playback()
	_pick_next_note()

func _process(_delta):
	_fill_buffer()

func _pick_next_note():
	# Pick a random note from the pentatonic scale
	current_note_freq = scale_notes.pick_random()
	# Sometimes jump up an octave for variation
	if randf() > 0.8:
		current_note_freq *= 2.0
		
	next_note_time = Time.get_ticks_msec() / 1000.0 + note_duration + randf_range(-0.5, 0.5)
	# Reset phase to avoid popping artifacts on note change (simple approach)
	# For smoother transitions, you'd implement an ADSR envelope here.
	phase = 0.0 

func _fill_buffer():
	var increment = current_note_freq / sample_rate
	var to_fill = playback.get_frames_available()
	
	# Check if it's time to switch notes
	if Time.get_ticks_msec() / 1000.0 >= next_note_time:
		_pick_next_note()

	# Fill the audio buffer with generated sine waves
	for i in range(to_fill):
		# Generate a Sine wave
		var signal_val = sin(phase * TAU)
		
		# Add a subtle second harmonic (octave up) for a richer, "bell-like" tone
		signal_val += sin(phase * TAU * 2.0) * 0.3
		
		# Normalize volume (keep it soft)
		signal_val *= 0.3
		
		# Write stereo frame (same audio left and right)
		playback.push_frame(Vector2(signal_val, signal_val))
		
		# Advance phase
		phase = fmod(phase + increment, 1.0)
