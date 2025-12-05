extends Area2D

var item_name = "Wood"
var collected = false
var can_collect = false 
var is_player_dropped = false 
var activation_distance = 192.0 

@onready var sprite = $Sprite2D

func _ready():
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 32
	shape.shape = circle
	add_child(shape)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	if sprite and sprite.texture:
		var outline = sprite.duplicate()
		outline.modulate = Color(0, 0, 0, 1)
		outline.show_behind_parent = true
		outline.scale = Vector2(1.2, 1.2)
		outline.position = Vector2.ZERO
		sprite.add_child(outline)
	
	if sprite:
		var t = create_tween().set_loops()
		t.tween_property(sprite, "position:y", -5, 1.0).set_trans(Tween.TRANS_SINE)
		t.tween_property(sprite, "position:y", 0, 1.0).set_trans(Tween.TRANS_SINE)

func setup(type, dropped_by_player = false):
	item_name = type
	is_player_dropped = dropped_by_player
	
	# Wait for ready safely
	if not is_inside_tree():
		await ready
	
	if sprite:
		var path = "res://Assets/icons/" + item_name + ".png"
		if item_name == "Rope": path = "res://Assets/icons/Rope.png" 
		elif item_name == "Pickaxe": path = "res://Assets/pickaxe-iron.png"
		elif item_name == "Crafting Table": path = "res://Assets/Crafting Table.png"
		elif item_name == "Bonfire": path = "res://Assets/Bonfire_02-Sheet.png"
		elif item_name == "Fence": path = "res://Assets/FENCE 1 - DAY.png"
		elif item_name == "Wood": path = "res://Assets/icons/Wood.png"
		elif item_name == "Stone": path = "res://Assets/icons/Stone.png"

		if ResourceLoader.exists(path): sprite.texture = load(path)
		else:
			path = "res://Assets/" + item_name + ".png"
			if ResourceLoader.exists(path): sprite.texture = load(path)

	if not is_player_dropped:
		# Double check tree validity
		if get_tree():
			await get_tree().create_timer(0.5).timeout
			can_collect = true
			_check_overlap()
		else:
			can_collect = true # Fallback if no tree found
	else:
		can_collect = false

func _physics_process(delta):
	if is_player_dropped and not can_collect:
		var player = get_tree().root.find_child("Player", true, false)
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist > activation_distance:
				can_collect = true

func _check_overlap():
	for body in get_overlapping_bodies():
		if body.name == "Player":
			_on_body_entered(body)

func _on_body_entered(body):
	if collected or not can_collect: return
	if body.name == "Player":
		collected = true
		collect()

func collect():
	NetworkManager.send_collect_item(item_name)
	
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		var t = create_tween()
		t.tween_property(self, "global_position", player.global_position, 0.3).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(self, "scale", Vector2(0,0), 0.3)
		t.chain().tween_callback(queue_free)
	else:
		queue_free()
