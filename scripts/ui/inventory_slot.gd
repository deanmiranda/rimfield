extends TextureButton

@export var slot_index: int = -1  # Index of this button in the GridContainer (or inventory slot)

# Reference to the texture used when the button is empty
@export var empty_texture: Texture

# The current item texture representing an inventory item
var item_texture: Texture = null

func _ready() -> void:
	# Assign the index of this button within the GridContainer
	var parent = get_parent()
	if parent:
		slot_index = parent.get_children().find(self)
		if slot_index == -1:
			print("Error: Failed to find this button in its parent's children.")
	else:
		print("Error: This button has no parent node.")

	# Set the initial texture as empty if there's no item
	if item_texture == null:
		texture_normal = empty_texture

# Handle item dragging
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1: 
		if event.is_pressed():
			# Start drag action if we have an item in this slot
			if item_texture != null:
				print("Starting drag for item in slot", slot_index)
				var drag_preview = TextureRect.new()
				drag_preview.texture = item_texture
				set_drag_preview(drag_preview)
				set_meta("dragged_item", item_texture)
				set_meta("slot_index", slot_index)
			else:
				print("No item in slot to drag.")

# Handle dropping items into this slot
func can_drop_data(position: Vector2, data) -> bool:
	# Check if the data being dropped is an inventory item texture
	return data.has("dragged_item") and data.has("slot_index")

func drop_data(position: Vector2, data) -> void:
	if data.has("dragged_item") and data.has("slot_index"):
		var dragged_item = data["dragged_item"]
		var dragged_slot_index = data["slot_index"]

		# Swap items between the dragged slot and the current slot
		var previous_texture = item_texture
		item_texture = dragged_item
		texture_normal = item_texture

		if dragged_slot_index != slot_index:
			var parent = get_parent()
			if parent:
				var dragged_button = parent.get_child(dragged_slot_index) as TextureButton
				dragged_button.item_texture = previous_texture
				if previous_texture == null:
					dragged_button.texture_normal = dragged_button.empty_texture
				else:
					dragged_button.texture_normal = previous_texture

func get_drag_data(position: Vector2) -> Dictionary:
	if item_texture != null:
		return {
			"dragged_item": item_texture,
			"slot_index": slot_index
		}
	return {}

# Utility function to set an item to this button
func set_item(new_texture: Texture) -> void:
	item_texture = new_texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture
