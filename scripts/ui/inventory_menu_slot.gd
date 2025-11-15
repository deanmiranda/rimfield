# inventory_menu_slot.gd
# Slot for the inventory menu grid (3x10)
# Extensible for future drag/drop functionality

extends TextureButton

@export var slot_index: int = 0
@export var empty_texture: Texture
@export var is_locked: bool = false  # For grayed-out upgrade slots

signal slot_clicked(slot_index: int)
signal slot_drag_started(slot_index: int, item_texture: Texture)
signal slot_drop_received(slot_index: int, data: Dictionary)

var item_texture: Texture = null

func _ready() -> void:
	# Initialize the slot - ensure texture is set
	if empty_texture:
		texture_normal = empty_texture
		ignore_texture_size = true
		stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	if item_texture != null:
		texture_normal = item_texture
	
	# Apply locked state (grayed out for future upgrades)
	if is_locked:
		modulate = Color(0.5, 0.5, 0.5, 0.7)  # Grayed out
		disabled = true
	else:
		modulate = Color.WHITE
		disabled = false
	
	# Ensure the node receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Force visibility
	visible = true

func set_item(new_texture: Texture) -> void:
	"""Set the item texture for this slot"""
	item_texture = new_texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

func get_item() -> Texture:
	"""Get the item texture from this slot"""
	return item_texture

func _gui_input(event: InputEvent) -> void:
	"""Handle input events - prepare for future drag/drop"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("slot_clicked", slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click for future context menu
			pass

# Future drag/drop functionality (prepared but not implemented)
func get_drag_data(_position: Vector2) -> Variant:
	"""Prepare for drag operation - to be implemented in future"""
	if item_texture != null and not is_locked:
		var drag_data = {
			"slot_index": slot_index,
			"item_texture": item_texture,
			"source": self
		}
		emit_signal("slot_drag_started", slot_index, item_texture)
		return drag_data
	return null

func can_drop_data(_position: Vector2, data: Variant) -> bool:
	"""Check if data can be dropped here - to be implemented in future"""
	if is_locked:
		return false
	if data is Dictionary and data.has("item_texture"):
		return true
	return false

func drop_data(_position: Vector2, data: Variant) -> void:
	"""Handle drop operation - to be implemented in future"""
	if data is Dictionary:
		emit_signal("slot_drop_received", slot_index, data)
