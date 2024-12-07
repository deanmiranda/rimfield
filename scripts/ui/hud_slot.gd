extends TextureButton

@export var slot_index: int = -1
@export var empty_texture: Texture

@export var tool_name: String = ""  # Logical name for the tool
@export var can_farm: bool = false  # Can this tool be used for farming?


var item_texture: Texture = null

const BUTTON_LEFT = 1

# Signal to inform HUD or ToolSwitcher about tool changes
signal tool_selected(slot_index: int)

func _ready() -> void:
	# Initialize the slot with empty or item texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

	# Ensure the node receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_item(new_texture: Texture) -> void:
	item_texture = new_texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

func get_drag_data(_position):
	if item_texture != null:
		print("Dragging item from slot", slot_index)

		var drag_data = {
			"slot_index": slot_index,
			"item_texture": item_texture,
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

	print("drop_data() called for slot", slot_index)
	# Swap item textures
	var temp_texture = item_texture
	set_item(from_item_texture)

	if from_slot and from_slot.has_method("set_item"):
		from_slot.set_item(temp_texture)

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		print("HUD Slot", slot_index, "clicked.")
		emit_signal("tool_selected", slot_index)  # Emit signal when a slot is clicked
