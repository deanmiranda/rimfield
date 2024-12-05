extends TextureButton

@export var slot_index: int = -1
@export var empty_texture: Texture
var item_texture: Texture = null

const BUTTON_LEFT = 1

func _ready() -> void:
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
	
	print("get_drag_data() called for slot", slot_index)
	
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
		set_drag_preview(drag_preview)  # Attach the preview to the mouse

		return drag_data
	else:
		return null  # No item to drag


func can_drop_data(_mouse_position, data):
	print("can_drop_data() called for slot", slot_index, "with data:", data)
	return data.has("item_texture")

func drop_data(_mouse_position, data):
	var from_slot = data["source"]
	var from_item_texture = data["item_texture"]

	print("drop_data() called for slot", slot_index, "with data:", data)
	# Swap item textures
	var temp_texture = item_texture
	set_item(from_item_texture)

	if from_slot and from_slot.has_method("set_item"):
		from_slot.set_item(temp_texture)
	else:
		print("Error: Invalid source slot.")


func create_drag_preview() -> Control:
	var drag_preview = TextureRect.new()
	drag_preview.texture = item_texture
	drag_preview.set_size(Vector2(64, 64))
	return drag_preview

# Optional: Handle click events if needed
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		print("HUD Slot", slot_index, "clicked.")
		# Handle click interaction here (e.g., emit signals or change tool)
