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
var default_modulate: Color = Color.WHITE
var is_highlighted: bool = false

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
		default_modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE
		disabled = false
		default_modulate = Color.WHITE
	
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

# Drag/drop functionality
func get_drag_data(_position: Vector2) -> Variant:
	"""Prepare for drag operation from inventory slot"""
	if item_texture == null or is_locked:
		return null
	
	var drag_data = {
		"slot_index": slot_index,
		"item_texture": item_texture,
		"source": "inventory",  # Standardized source identifier
		"source_node": self  # Reference to source slot for swapping
	}
	
	# Create drag preview
	var drag_preview = TextureRect.new()
	drag_preview.texture = item_texture
	drag_preview.custom_minimum_size = Vector2(64, 64)
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
	set_drag_preview(drag_preview)
	
	emit_signal("slot_drag_started", slot_index, item_texture)
	return drag_data

func can_drop_data(_position: Vector2, data: Variant) -> bool:
	"""Check if data can be dropped here - with visual feedback"""
	print("DEBUG: can_drop_data() called on inventory slot ", slot_index, " with data: ", data)
	
	var can_drop: bool = false
	
	# Cannot drop on locked slots
	if is_locked:
		print("DEBUG: Inventory slot ", slot_index, " is locked - cannot drop")
		_reset_highlight()
		return false
	
	# Validate data structure
	if not data is Dictionary:
		print("DEBUG: Drop data is not a Dictionary")
		_reset_highlight()
		return false
	
	if not data.has("item_texture"):
		print("DEBUG: Drop data missing item_texture")
		_reset_highlight()
		return false
	
	# Accept drops from toolkit (Phase 1) or inventory (Phase 3)
	if data.has("source"):
		var source: String = data["source"]
		if source == "toolkit" or source == "inventory":
			can_drop = true
			print("DEBUG: Can drop ", source, " item in inventory slot ", slot_index)
	
	# Visual feedback: highlight valid drop targets
	if can_drop:
		_highlight_valid_drop()
	else:
		_reset_highlight()
	
	print("DEBUG: can_drop_data() returning ", can_drop, " for inventory slot ", slot_index)
	return can_drop

func drop_data(_position: Vector2, data: Variant) -> void:
	"""Handle drop operation - swap items if slot is occupied"""
	print("DEBUG: drop_data() called on inventory slot ", slot_index, " with data: ", data)
	
	# Reset highlight after drop
	_reset_highlight()
	
	if not data is Dictionary or not data.has("item_texture"):
		print("DEBUG: Invalid drop data in inventory slot ", slot_index)
		_show_invalid_drop_feedback()
		return
	
	if is_locked:
		print("DEBUG: Cannot drop on locked inventory slot ", slot_index)
		_show_invalid_drop_feedback()
		return  # Cannot drop on locked slots
	
	# Edge case: Dragging to same slot (no-op)
	var source_slot_index = data.get("slot_index", -1)
	if data.has("source") and data["source"] == "inventory" and source_slot_index == slot_index:
		print("DEBUG: Dropping on same inventory slot - no-op")
		return  # Same slot, no-op
	
	var from_item_texture: Texture = data["item_texture"]
	var source_node = data.get("source_node", null)
	
	print("DEBUG: Dropping item in inventory slot ", slot_index, " from ", data.get("source", "unknown"))
	print("DEBUG: Source node: ", source_node)
	print("DEBUG: Current item in slot: ", item_texture)
	print("DEBUG: Dropping item: ", from_item_texture)
	
	# Swap items if slot is occupied
	var temp_texture: Texture = item_texture
	set_item(from_item_texture)
	print("DEBUG: Set item in inventory slot ", slot_index, " to: ", from_item_texture)
	
	# Update source slot if it's a node reference
	if source_node and source_node.has_method("set_item"):
		print("DEBUG: Updating source slot with swapped item: ", temp_texture)
		source_node.set_item(temp_texture)
	else:
		print("DEBUG: Source node is null or doesn't have set_item method")
	
	# Emit signal to notify InventoryManager
	emit_signal("slot_drop_received", slot_index, data)
	print("DEBUG: drop_data() completed for inventory slot ", slot_index)

func _highlight_valid_drop() -> void:
	"""Highlight slot as valid drop target"""
	if not is_highlighted:
		is_highlighted = true
		modulate = Color(1.2, 1.2, 1.0, 1.0)  # Slight yellow tint

func _reset_highlight() -> void:
	"""Reset slot highlight to default"""
	if is_highlighted:
		is_highlighted = false
		modulate = default_modulate

func _show_invalid_drop_feedback() -> void:
	"""Show visual feedback for invalid drop (red flash)"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_callback(_reset_highlight).set_delay(0.2)

func _receive_drop_from_toolkit(dropped_texture: Texture, source_slot_index: int, source_node: Node) -> bool:
	"""Receive a drop from toolkit slot - returns true if successful"""
	print("DEBUG: Receiving toolkit drop in inventory slot ", slot_index, " from toolkit slot ", source_slot_index)
	
	if is_locked:
		print("DEBUG: Cannot drop on locked inventory slot")
		return false
	
	# Get current item in this slot
	var current_texture: Texture = item_texture
	
	# Swap items
	set_item(dropped_texture)
	if source_node and source_node.has_method("set_item"):
		source_node.set_item(current_texture)
	
	# Notify InventoryManager
	if InventoryManager:
		InventoryManager.update_inventory_slots(slot_index, dropped_texture)
		if current_texture:
			InventoryManager.add_item_to_toolkit(source_slot_index, current_texture)
		else:
			InventoryManager.remove_item_from_toolkit(source_slot_index)
	
	# Emit signal
	var drag_data = {
		"slot_index": source_slot_index,
		"item_texture": dropped_texture,
		"source": "toolkit",
		"source_node": source_node
	}
	emit_signal("slot_drop_received", slot_index, drag_data)
	
	return true
