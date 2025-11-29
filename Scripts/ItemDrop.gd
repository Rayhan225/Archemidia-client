extends Area2D

var item_name = "Wood"
var collected = false
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
	
	if sprite.texture:
		var outline = sprite.duplicate()
		outline.modulate = Color(0, 0, 0, 1)
		outline.show_behind_parent = true
		outline.scale = Vector2(1.2, 1.2)
		outline.position = Vector2.ZERO
		sprite.add_child(outline)
	
	var t = create_tween().set_loops()
	t.tween_property(sprite, "position:y", -5, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(sprite, "position:y", 0, 1.0).set_trans(Tween.TRANS_SINE)

func setup(type):
	item_name = type
	var path = "res://assets/icons/" + item_name + ".png"
	
	# FIX: Ensure filename matches exactly including spaces
	if item_name == "Rope": 
		path = "res://Assets/icons/Rope.png" 
		if not ResourceLoader.exists(path): path = "res://Assets/87.png"
	elif item_name == "Pickaxe": 
		path = "res://Assets/pickaxe-iron.png"
	elif item_name == "Crafting Table": 
		# Attempt "Crafting Table.png" (with space) first
		path = "res://Assets/Crafting Table.png"
		if not ResourceLoader.exists(path): 
			path = "res://Assets/CraftingTable.png"
	elif item_name == "Wood":
		path = "res://Assets/icons/Wood.png"
	elif item_name == "Stone":
		path = "res://Assets/icons/Stone.png"

	if ResourceLoader.exists(path): 
		sprite.texture = load(path)
	else:
		path = "res://Assets/" + item_name + ".png"
		if ResourceLoader.exists(path): sprite.texture = load(path)

func _on_body_entered(body):
	if collected: return
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
