extends TextureButton

# Add the signals for drag-and-drop functionality
signal can_drop_data(position, data)
signal drop_data(position, data)

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
func _on_gui_input(event: InputEvent) -> void:
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

# Utility function to set an item to this button
func set_item(new_texture: Texture) -> void:
	item_texture = new_texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture
