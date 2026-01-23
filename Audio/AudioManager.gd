extends Node

var music_gen: Node
var sfx_gen: Node

func _ready():
	var MusicScript = load("res://Audio/MusicGenerator.gd")
	var SFXScript = load("res://Audio/SFXGenerator.gd")
	
	if MusicScript:
		music_gen = MusicScript.new()
		add_child(music_gen)
		# Start with Cozy Medieval World Music
		play_world_music()
		
	if SFXScript:
		sfx_gen = SFXScript.new()
		add_child(sfx_gen)

# --- MUSIC CONTROLS ---

func play_world_music():
	if music_gen:
		# Slower, relaxing BPM for world exploration
		music_gen.setup_style("MEDIEVAL", 80.0)

func play_party_music(start_bpm: float):
	if music_gen:
		music_gen.setup_style("PARTY", start_bpm)

func set_music_bpm(bpm: float):
	if music_gen:
		music_gen.set_bpm(bpm)

# --- SFX CONTROLS ---

func play_party_hit():
	if sfx_gen: sfx_gen.play_sound("PARTY_HIT")

func play_party_miss():
	if sfx_gen: sfx_gen.play_sound("PARTY_MISS")

func play_damage():
	if sfx_gen: sfx_gen.play_sound("DAMAGE")
