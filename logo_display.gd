extends Control

# Dropdown in Inspector to choose the icon type
@export_enum("TicTacToe", "Party") var icon_type: String = "TicTacToe"

func _draw():
	var w = size.x
	var h = size.y
	
	match icon_type:
		"TicTacToe":
			_draw_ttt(w, h)
		"Party":
			_draw_party(w, h)

# --- TIC TAC TOE DRAWING (Existing Logic) ---
func _draw_ttt(w, h):
	var pad = 15.0
	var col_grid = Color(1, 1, 1, 0.5)
	var col_o = Color(1.0, 0.4, 0.4, 1.0)
	var line_width = 3.0

	# Grid Lines
	draw_line(Vector2(w * 0.33, pad), Vector2(w * 0.33, h - pad), col_grid, line_width)
	draw_line(Vector2(w * 0.66, pad), Vector2(w * 0.66, h - pad), col_grid, line_width)
	draw_line(Vector2(pad, h * 0.33), Vector2(w - pad, h * 0.33), col_grid, line_width)
	draw_line(Vector2(pad, h * 0.66), Vector2(w - pad, h * 0.66), col_grid, line_width)
	
	# 'O' Symbol
	var center = Vector2(w * 0.5, h * 0.5)
	draw_arc(center, w * 0.12, 0, TAU, 32, col_o, line_width)
	
	# 'X' Symbol (Small decorative one)
	# (Keeping your original logic or simplifying for icon clarity)
	var col_x = Color(0.2, 0.8, 1.0, 1.0)
	var cw = w / 3.0
	var ch = h / 3.0
	var xc = Vector2(cw * 0.5, ch * 0.5) # Top-left cell center
	var x_size = cw * 0.25
	draw_line(xc - Vector2(x_size, x_size), xc + Vector2(x_size, x_size), col_x, line_width)
	draw_line(xc - Vector2(-x_size, x_size), xc + Vector2(-x_size, x_size), col_x, line_width)

# --- PARTY MODE DRAWING (New Logic) ---
func _draw_party(w, h):
	var center = Vector2(w * 0.5, h * 0.5)
	var line_width = 3.0
	var col_dude = Color(0.2, 0.8, 1.0, 1.0) # Cyan
	var col_glasses = Color(0.1, 0.1, 0.1, 1.0) # Black
	var col_note = Color(1.0, 0.4, 0.4, 1.0) # Red/Pink
	
	# 1. The Dude (Head)
	draw_circle(center + Vector2(0, h * 0.05), w * 0.25, col_dude)
	
	# 2. Sunglasses
	var glass_w = w * 0.35
	var glass_h = h * 0.12
	var glass_rect = Rect2(center.x - glass_w/2, center.y, glass_w, glass_h)
	draw_rect(glass_rect, col_glasses)
	
	# 3. Music Notes
	_draw_note(Vector2(w * 0.2, h * 0.3), col_note, line_width)
	_draw_note(Vector2(w * 0.8, h * 0.25), col_note, line_width)

	# 4. Equalizer Bars (Bottom)
	var base_y = h - 10.0
	draw_line(Vector2(w * 0.2, base_y), Vector2(w * 0.2, base_y - h*0.3), col_note, line_width)
	draw_line(Vector2(w * 0.8, base_y), Vector2(w * 0.8, base_y - h*0.4), col_note, line_width)

func _draw_note(pos, color, width):
	draw_circle(pos, 4.0, color)
	draw_line(pos + Vector2(2, 0), pos + Vector2(2, -15), color, width)
	draw_line(pos + Vector2(2, -15), pos + Vector2(10, -10), color, width)
