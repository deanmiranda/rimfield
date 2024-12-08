extends TextureButton

@export var slot_index: int = 0
@export var empty_texture: Texture
var item_quantity: int = 0

signal tool_selected(slot_index: int, item_texture: Texture) # Signal emitted when the tool is selected

var item_texture: Texture = null

const BUTTON_LEFT = 1

func _ready() -> void:
	# Initialize the slot with empty or item texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

	# Ensure the node receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_item(new_texture: Texture, quantity: int = 1) -> void:
	item_texture = new_texture
	item_quantity = quantity

	# Update the slot appearance
	if item_texture == null:
		texture_normal = empty_texture
		item_quantity = 0
	else:
		texture_normal = item_texture

	_update_quantity_label()

func _update_quantity_label() -> void:
	var label = $Label  # Replace with the actual path to your Label node
	if item_quantity > 1:
		label.text = str(item_quantity)
		label.visible = true
	else:
		label.text = ""
		label.visible = false

func stack_items(item_type: Texture, quantity: int, source_slot: TextureButton = null) -> bool:
	if item_texture == item_type:
		# Stack items if they match
		item_quantity += quantity
		if source_slot:
			source_slot.set_item(null, 0)  # Clear the source slot
		_update_quantity_label()
		return true
	elif item_texture == null:
		# If the slot is empty, add the item here
		set_item(item_type, quantity)
		if source_slot:
			source_slot.set_item(null, 0)  # Clear the source slot
		return true
	else:
		# Cannot stack, item mismatch
		return false


func get_drag_data(_position):
	if item_texture != null:
		print("Dragging item from slot", slot_index)

		var drag_data = {
			"slot_index": slot_index,
			"item_texture": item_texture,
			"item_quantity": item_quantity,
			"source": self  # Reference to the source slot
		}

		# Create a drag preview
		var drag_preview = TextureRect.new()
		drag_preview.texture = item_texture
		drag_preview.rect_size = Vector2(64, 64)  # Adjust size as needed
		drag_preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
		set_drag_preview(drag_preview)

		return drag_data
	else:
		return null  # No item to drag

func can_drop_data(_mouse_position, data):
	return data.has("item_texture")

func drop_data(_mouse_position, data):
	var from_slot = data["source"]
	var from_item_texture = data["item_texture"]
	var from_quantity = data["item_quantity"]

	if stack_items(from_item_texture, from_quantity, from_slot):
		print("Items stacked successfully.")
	else:
		# Swap items if stacking is not possible
		var temp_texture = item_texture
		var temp_quantity = item_quantity

		set_item(from_item_texture, from_quantity)
		if from_slot and from_slot.has_method("set_item"):
			from_slot.set_item(temp_texture, temp_quantity)

	_update_quantity_label()


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		emit_signal("tool_selected", slot_index) # Emit signal when a slot is clicked
