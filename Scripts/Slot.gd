extends PanelContainer

@onready var icon = $Icon
@onready var count_lbl = $Count
var name_lbl: Label
var selection_border: ReferenceRect 

var data = null
var is_selected = false # Track state
signal slot_selected(slot_ref) 

func _ready():
	name_lbl = Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.modulate = Color(1, 1, 1, 0.9)
	
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.add_child(name_lbl)
	
	selection_border = ReferenceRect.new()
	selection_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	selection_border.border_color = Color(1.0, 0.798, 0.201, 1.0) 
	selection_border.border_width = 2.0
	selection_border.editor_only = false
	selection_border.visible = false
	selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selection_border)
	
	if icon:
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func set_item(d):
	data = d
	if d:
		var p = "res://Assets/" + d["name"] + ".png"
		if d["name"] == "Crafting Table": p = "res://Assets/Crafting Table.png"
		elif d["name"] == "Rope": p = "res://Assets/icons/Rope.png"
		elif d["name"] == "Pickaxe": p = "res://Assets/pickaxe-iron.png"
		elif d["name"] == "Bonfire": p = "res://Assets/Bonfire_02-Sheet.png"
		elif d["name"] == "Fence": p = "res://Assets/FENCE 1 - DAY.png"
		elif d["name"] == "Wood": p = "res://Assets/icons/Wood.png"
		elif d["name"] == "Stone": p = "res://Assets/icons/Stone.png"
		
		if not ResourceLoader.exists(p):
			p = "res://Assets/icons/" + d["name"] + ".png"
			
		if ResourceLoader.exists(p):
			icon.texture = load(p)
			# Atlas handling for Bonfire
			if d["name"] == "Bonfire":
				var atlas = AtlasTexture.new()
				atlas.atlas = icon.texture
				atlas.region = Rect2(0, 0, 32, 32)
				icon.texture = atlas
		else:
			icon.texture = null
		
		if d["count"] > 1:
			count_lbl.text = ""
			name_lbl.text = d["name"] + " x" + str(d["count"])
		else:
			count_lbl.text = ""
			name_lbl.text = d["name"]
			
		name_lbl.visible = true
	else:
		icon.texture = null
		count_lbl.text = ""
		if name_lbl: name_lbl.visible = false

	if name_lbl:
		name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		name_lbl.position = Vector2(size.x - name_lbl.size.x - 5, size.y - name_lbl.size.y - 5)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Toggle Logic
		if is_selected:
			deselect()
			emit_signal("slot_selected", null) # Signal deselection
		else:
			select()

func select():
	is_selected = true
	selection_border.visible = true
	emit_signal("slot_selected", self)

func deselect():
	is_selected = false
	selection_border.visible = false

func _get_drag_data(at_position):
	if !data: return null
	var preview = TextureRect.new()
	preview.texture = icon.texture
	preview.expand_mode = 1
	preview.size = Vector2(50, 50)
	set_drag_preview(preview)
	return self 

func _can_drop_data(at_position, source_slot):
	return source_slot.has_method("set_item")

func _drop_data(at_position, source_slot):
	var my_data = self.data
	var source_data = source_slot.data
	self.set_item(source_data)
	source_slot.set_item(my_data)
	
	# Deselect both on drop to avoid confusion
	source_slot.deselect()
	self.deselect()
