extends Node

var wood_post_texture: ImageTexture
var wood_rail_texture: ImageTexture
var stone_texture: ImageTexture
var stone_wall_texture: ImageTexture
var sand_texture: ImageTexture
var flower_texture: ImageTexture

# Palette
const COL_TRANSPARENT = Color(0, 0, 0, 0)
const COL_WOOD_DARK = Color(0.25, 0.15, 0.05)
const COL_WOOD_MID = Color(0.55, 0.35, 0.15)
const COL_WOOD_LIGHT = Color(0.65, 0.45, 0.25)

# --- 1. WOOD POST (Vertical Pillar) ---
func get_wood_post_texture() -> ImageTexture:
	if wood_post_texture: return wood_post_texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(COL_TRANSPARENT)
	
	# Draw Centered Post
	_draw_pixel_rect(img, 24, 10, 16, 54, COL_WOOD_DARK) # Outline
	_draw_pixel_rect(img, 26, 12, 12, 50, COL_WOOD_MID)  # Fill
	_draw_pixel_rect(img, 28, 12, 4, 50, COL_WOOD_LIGHT) # Highlight
	
	wood_post_texture = ImageTexture.create_from_image(img)
	return wood_post_texture

# --- 2. WOOD RAIL (Horizontal Connector) ---
func get_wood_rail_texture() -> ImageTexture:
	if wood_rail_texture: return wood_rail_texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(COL_TRANSPARENT)
	
	# Draw Top Rail
	_draw_pixel_rect(img, 0, 24, 64, 8, COL_WOOD_DARK)
	_draw_pixel_rect(img, 0, 26, 64, 4, COL_WOOD_MID)
	
	# Draw Bottom Rail
	_draw_pixel_rect(img, 0, 48, 64, 8, COL_WOOD_DARK)
	_draw_pixel_rect(img, 0, 50, 64, 4, COL_WOOD_MID)
	
	wood_rail_texture = ImageTexture.create_from_image(img)
	return wood_rail_texture

# --- 3. STONE WALL (Bricks) ---
func get_stone_wall_texture() -> ImageTexture:
	if stone_wall_texture: return stone_wall_texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(COL_TRANSPARENT)
	var brick_col = Color(0.5, 0.5, 0.55); var mortar_col = Color(0.3, 0.3, 0.35)
	_draw_pixel_rect(img, 4, 16, 56, 48, mortar_col) # Base
	for y in range(16, 60, 14):
		var off = 0; if (y/14)%2==1: off = 14
		for x in range(4, 56, 28):
			var dx = x + off - 10; if dx < 4: dx = 4
			_draw_pixel_rect(img, dx, y+2, 24, 10, brick_col)
			_draw_pixel_rect(img, dx+2, y+2, 20, 2, Color(0.6,0.6,0.65))
	stone_wall_texture = ImageTexture.create_from_image(img)
	return stone_wall_texture

# --- 4. STONE FLOOR (Diamond) ---
func get_stone_floor_texture() -> ImageTexture:
	if stone_texture: return stone_texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(COL_TRANSPARENT)
	var st = Color(0.55, 0.55, 0.6); var sh = Color(0.35, 0.35, 0.4)
	for y in range(64):
		for x in range(64):
			if abs(x-32) + abs(y-32)*2 <= 28:
				img.set_pixel(x, y, st)
				if x > 32 and y > 32: img.set_pixel(x, y, sh)
	stone_texture = ImageTexture.create_from_image(img)
	return stone_texture

# --- 5. SAND PATH (Blob) ---
func get_sand_path_texture() -> ImageTexture:
	if sand_texture: return sand_texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(COL_TRANSPARENT)
	var sand = Color(0.85, 0.75, 0.5)
	for y in range(64): for x in range(64):
		if Vector2(x-32, y-32).length() + (randf()*4) < 28: img.set_pixel(x, y, sand)
	sand_texture = ImageTexture.create_from_image(img)
	return sand_texture

# --- 6. FLOWER ---
func get_flower_texture() -> ImageTexture:
	if flower_texture: return flower_texture
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(COL_TRANSPARENT)
	var stem = Color(0.2, 0.7, 0.3); var petal = Color(1.0, 0.4, 0.5)
	_draw_pixel_rect(img, 30, 40, 4, 16, stem)
	_draw_pixel_rect(img, 26, 26, 12, 12, petal)
	_draw_pixel_rect(img, 29, 29, 6, 6, Color(1, 0.9, 0.2))
	flower_texture = ImageTexture.create_from_image(img)
	return flower_texture

func _draw_pixel_rect(img, x, y, w, h, col):
	for i in range(x, x+w): for j in range(y, y+h):
		if i>=0 and i<64 and j>=0 and j<64: img.set_pixel(i, j, col)
