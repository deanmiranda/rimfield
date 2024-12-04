extends TextureButton

@export var slot_index: int = -1  # Unique index of this slot in the GridContainer
@export var empty_texture: Texture  # Texture to display when the slot is empty

var item_texture: Texture = null  # Current item texture in this slot
var is_dragging: bool = false  # Tracks whether this slot is being dragged
var drag_preview: TextureRect = null  # Reference to the drag preview node

const MOUSE_BUTTON_LEFT = 1

func _ready() -> void:
	# Ensure unique slot index
	if slot_index == -1:
		var parent = get_parent()
		if parent:
			slot_index = parent.get_children().find(self) + 1  # Adjust for index starting at 1
			if slot_index == 0:
				print("Error: Failed to find this slot in its parent's children.")
		else:
			print("Error: This slot has no parent node.")

	# Set initial texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

	# Set mouse filter to stop events
	mouse_filter = Control.MOUSE_FILTER_STOP

	print("Slot", slot_index, "initialized. Empty texture:", empty_texture)

func set_item(new_texture: Texture) -> void:
	item_texture = new_texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture
	print("Slot", slot_index, "item set to:", item_texture)

# Handles drag-and-drop events for the slot
func _on_gui_input(event: InputEvent) -> void:
	print("Slot", slot_index, "received input event:", event)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		print("Slot", slot_index, "Mouse Button Event detected. Pressed:", event.pressed)
		if event.pressed:
			if item_texture:
				# Start dragging
				is_dragging = true
				create_drag_preview(event.global_position)
				print("Dragging started on slot", slot_index)
			else:
				print("Slot", slot_index, "Mouse pressed but no item to drag.")
		elif not event.pressed:
			if is_dragging:
				# Handle drop
				is_dragging = false
				handle_drop(event.global_position)
				print("Dragging stopped on slot", slot_index)
			else:
				print("Slot", slot_index, "Mouse released but not currently dragging.")

	elif event is InputEventMouseMotion:
		print("Slot", slot_index, "Mouse Motion Event detected. Is Dragging:", is_dragging)
		if is_dragging:
			# Update drag preview position
			update_drag_preview_position(event.global_position)
			print("Dragging: Slot", slot_index, "Preview Position Updated:", event.global_position)
		else:
			print("Slot", slot_index, "Mouse motion detected but not dragging.")

func create_drag_preview(global_position: Vector2):
	if drag_preview:
		return  # Avoid duplicate previews

	drag_preview = TextureRect.new()
	drag_preview.texture = item_texture
	drag_preview.custom_minimum_size = Vector2(64, 64)  # Define size explicitly
	drag_preview.position = global_position - drag_preview.custom_minimum_size / 2
	drag_preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent for dragging feedback
	get_tree().root.add_child(drag_preview)  # Add to the root of the scene tree
	print("Drag preview created for slot", slot_index)

func update_drag_preview_position(global_position: Vector2):
	if drag_preview:
		# Adjust to ensure the preview is centered under the mouse cursor
		drag_preview.global_position = global_position - (drag_preview.texture.get_size() / 2)
		print("Drag preview position updated to:", drag_preview.global_position)

func handle_drop(global_position: Vector2):
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

	var mouse_pos = get_viewport().get_mouse_position()
	
	# Dynamically fetch the GridContainer (parent in this case)
	var parent_container = get_parent()
	if parent_container == null or not (parent_container is GridContainer):
		print("Error: Parent is not a GridContainer or is null.")
		return

	var drop_target = null

	# Iterate over children to find the slot under the mouse
	for child in parent_container.get_children():
		if child is TextureButton and child.get_global_rect().has_point(mouse_pos):
			drop_target = child
			break

	if drop_target and drop_target is TextureButton and drop_target.has_method("set_item"):
		# Swap item textures between slots
		var temp_texture = drop_target.item_texture
		drop_target.set_item(item_texture)
		set_item(temp_texture)
		print("Item dropped from slot", slot_index, "to slot", drop_target.slot_index)
	else:
		print("Invalid drop target for slot", slot_index)
