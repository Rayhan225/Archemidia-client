extends AudioStreamPlayer

var sample_hz = 44100.0
var playback: AudioStreamGeneratorPlayback

# Global Settings
var bpm = 120.0
var current_style = "PARTY" # "PARTY" or "MEDIEVAL"

# Sequencer
var beat_timer = 0.0
var current_step = 0 # 0-15 (16th notes)
var measure = 0

# --- SYNTH VOICES (Envelopes) ---
# Party Voices
var kick_vol = 0.0
var hat_vol = 0.0
var bass_vol = 0.0
# Medieval Voices
var harp_vol = 0.0
var flute_vol = 0.0
var flute_freq_target = 440.0
var harp_freq = 440.0

# --- SCALES ---
# Dorian Mode (Medieval feel): D, E, F, G, A, B, C
var scale_medieval = [293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25, 587.33]

func _ready():
	stream = AudioStreamGenerator.new()
	stream.mix_rate = sample_hz
	stream.buffer_length = 0.1
	play()
	playback = get_stream_playback()

func setup_style(style_name: String, new_bpm: float):
	current_style = style_name
	bpm = new_bpm
	current_step = 0
	measure = 0

func set_bpm(new_bpm):
	bpm = new_bpm

func _process(delta):
	_fill_buffer()

func _fill_buffer():
	var frames = playback.get_frames_available()
	if frames < 1: return
	
	var seconds_per_frame = 1.0 / sample_hz
	# 16th note duration = (60 / BPM) / 4
	var step_duration = (60.0 / bpm) / 4.0 
	
	for i in range(frames):
		# --- SEQUENCER ---
		beat_timer += seconds_per_frame
		if beat_timer >= step_duration:
			beat_timer -= step_duration
			current_step = (current_step + 1) % 16
			if current_step == 0: measure += 1
			_trigger_step()

		# --- AUDIO SYNTHESIS ---
		var output = 0.0
		
		if current_style == "PARTY":
			output = _synth_party(seconds_per_frame)
		elif current_style == "MEDIEVAL":
			output = _synth_medieval(seconds_per_frame)
			
		# Master Limiter
		output = clamp(output, -0.8, 0.8)
		playback.push_frame(Vector2(output, output))

# --- PATTERN LOGIC ---
func _trigger_step():
	if current_style == "PARTY":
		# Techno Pattern (4/4 Kick)
		if current_step % 4 == 0: kick_vol = 1.0 # Kick on every beat
		if current_step % 4 == 2: hat_vol = 0.4  # Hat off-beat
		if current_step % 2 == 0: bass_vol = 0.6 # Bass pulse
		
	elif current_style == "MEDIEVAL":
		# Harp Arpeggio (Fast flowing notes)
		if current_step % 2 == 0: # Every 8th note
			# Pick a random note from Dorian scale, biased by measure to create chord progression
			var offset = (measure % 4) * 2
			var idx = (current_step / 2 + offset) % scale_medieval.size()
			harp_freq = scale_medieval[idx]
			harp_vol = 0.5
			
		# Flute Melody (Slower, every measure)
		if current_step == 0:
			if measure % 2 == 0:
				flute_freq_target = scale_medieval[randi() % 5 + 2] # Higher melody notes
				flute_vol = 0.3

# --- SOUND GENERATION ---
var phase_kick = 0.0
var phase_bass = 0.0
var phase_harp = 0.0
var phase_flute = 0.0

func _synth_party(dt):
	# Kick (Sine Drop)
	var out = 0.0
	if kick_vol > 0.001:
		var freq = lerp(50.0, 150.0, kick_vol)
		phase_kick += freq * dt
		out += sin(phase_kick * TAU) * kick_vol
		kick_vol *= 0.999 # Decay
		
	# Hat (Noise)
	if hat_vol > 0.001:
		out += randf_range(-1.0, 1.0) * hat_vol
		hat_vol *= 0.99 # Fast Decay
		
	# Bass (Sawtooth-ish)
	if bass_vol > 0.001:
		phase_bass += 55.0 * dt # Low A
		var s = fmod(phase_bass, 1.0) * 2.0 - 1.0
		out += s * bass_vol * 0.5
		bass_vol *= 0.995
		
	return out

func _synth_medieval(dt):
	var out = 0.0
	
	# Harp (Plucked Sine)
	if harp_vol > 0.001:
		phase_harp += harp_freq * dt
		out += sin(phase_harp * TAU) * harp_vol
		harp_vol *= 0.9992 # Long ring decay
		
	# Flute (Sine with Vibrato)
	if flute_vol > 0.001:
		# Add Vibrato
		var vibrato = sin(Time.get_ticks_msec() / 100.0) * 2.0
		phase_flute += (flute_freq_target + vibrato) * dt
		out += sin(phase_flute * TAU) * flute_vol * 0.5
		
		# Breath envelope (sustain then fade)
		if current_step > 12: flute_vol *= 0.99 # Fade out at end of measure
		
	return out
