extends Control

func _draw():
	var w = size.x
	var h = size.y
	var pad = 15.0
	var col_grid = Color(1, 1, 1, 0.5)
	var col_x = Color(0.2, 0.8, 1.0, 1.0)
	var col_o = Color(1.0, 0.4, 0.4, 1.0)
	var line_width = 3.0

	draw_line(Vector2(w * 0.33, pad), Vector2(w * 0.33, h - pad), col_grid, line_width)
	draw_line(Vector2(w * 0.66, pad), Vector2(w * 0.66, h - pad), col_grid, line_width)
	draw_line(Vector2(pad, h * 0.33), Vector2(w - pad, h * 0.33), col_grid, line_width)
	draw_line(Vector2(pad, h * 0.66), Vector2(w - pad, h * 0.66), col_grid, line_width)
	
	var center = Vector2(w * 0.5, h * 0.5)
	draw_arc(center, w * 0.12, 0, TAU, 32, col_o, line_width)
	
	var cw = w / 3.0
	var ch = h / 3.0
	var xc = Vector2(cw * 0.5, ch * 0.5)
	var xs = w * 0.08
	draw_line(xc - Vector2(xs, xs), xc + Vector2(xs, xs), col_x, line_width)
	draw_line(xc + Vector2(-xs, xs), xc + Vector2(xs, -xs), col_x, line_width)

func _process(_delta):
	queue_redraw()
