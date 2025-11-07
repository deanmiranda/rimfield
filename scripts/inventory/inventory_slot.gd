extends TextureButton

@export var slot_index: int = -1  # Unique index for this slot
@export var empty_texture: Texture  # Texture for empty slot

var item_texture: Texture = null  # Current item texture
var is_dragging: bool = false  # Tracks if dragging is active
var drag_preview: TextureRect = null  # Drag preview node reference
var is_dragging_global: bool = false  # Global tracking for drag state
var drag_preview_instance: TextureRect = null  # Global drag preview
var is_empty: bool = false
const MOUSE_BUTTON_LEFT = 1

func _ready() -> void:
	# Dynamically determine slot index if not pre-assigned
	var parent = get_parent()
	if slot_index == -1 and parent:
		slot_index = parent.get_children().find(self) + 1
		if slot_index == 0:
			print("Error: Failed to find this slot in parent's children.")
	_update_item_texture(item_texture)
	mouse_filter = Control.MOUSE_FILTER_STOP

# Sets the item texture and updates its state
func set_item(new_texture: Texture) -> void:
	item_texture = new_texture if new_texture != null else empty_texture
	_update_item_texture(item_texture)

func _update_item_texture(texture: Texture) -> void:
	texture_normal = texture
	is_empty = texture == empty_texture

# GUI input handler for drag-and-drop
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and is_dragging:
		_update_drag_preview_position()

# Handles mouse button actions
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		if is_dragging_global or is_empty:
			return
		if item_texture:
			_start_drag()
	elif not event.pressed and is_dragging:
		_stop_drag()

# Starts the drag operation
func _start_drag() -> void:
	is_dragging = true
	is_dragging_global = true
	drag_preview = _create_drag_preview(item_texture)
	print("DEBUG: Drag started on slot", slot_index, "with texture:", item_texture)

func _stop_drag() -> void:
	is_dragging = false
	is_dragging_global = false
	if drag_preview:
		print("DEBUG: Drag stopped on slot", slot_index)
		_handle_drop(MouseUtil.get_viewport_mouse_pos(self))
		drag_preview.queue_free()
		drag_preview = null

# Creates the drag preview for the dragged item
func _create_drag_preview(texture: Texture) -> TextureRect:
	if drag_preview_instance != null:
		drag_preview_instance.queue_free()
		drag_preview_instance = null

	var preview = TextureRect.new()
	preview.texture = texture
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	preview.set_custom_minimum_size(Vector2(64, 64))
	preview.z_index = 1000
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	get_tree().root.add_child(preview)  # Add to scene tree root
	preview.global_position = MouseUtil.get_viewport_mouse_pos(self)
	drag_preview_instance = preview
	return preview

# Updates the drag preview's position to follow the mouse
func _update_drag_preview_position() -> void:
	if drag_preview:
		drag_preview.global_position = MouseUtil.get_viewport_mouse_pos(self)

# Handles dropping logic when drag ends
func _handle_drop(drop_position: Vector2) -> void:
	reset_drag_state()
	print("DEBUG: Handling drop for slot", slot_index, "at position:", drop_position)

	var parent_container = get_parent()
	if parent_container and parent_container is GridContainer:
		for child in parent_container.get_children():
			if child is TextureButton and child.get_global_rect().has_point(drop_position):
				print("DEBUG: Drop detected on slot", child.slot_index)
				if _swap_items_with(child):
					print("DEBUG: Swap successful between slots", slot_index, "and", child.slot_index)
					return
				else:
					print("DEBUG: Swap failed between slots", slot_index, "and", child.slot_index)

	print("DEBUG: No valid slot found for drop.")

func _swap_items_with(target_slot: TextureButton) -> bool:
	print("DEBUG: Attempting swap between slot", slot_index, "and slot", target_slot.slot_index)
	if target_slot.has_method("set_item"):
		var temp_texture = target_slot.item_texture
		print("DEBUG: Swapping textures. This slot:", item_texture, "Target slot:", temp_texture)
		target_slot.set_item(item_texture)
		set_item(temp_texture)
		return true
	print("DEBUG: Target slot does not support swapping.")
	return false

# Resets the drag state
func reset_drag_state() -> void:
	if drag_preview_instance:
		drag_preview_instance.queue_free()
		drag_preview_instance = null
	else:
		print("DEBUG: No drag preview instance to clear in reset_drag_state.")

	is_dragging = false
	is_dragging_global = false

# Debugging utility for inventory state
func debug_inventory_state() -> void:
	var parent_container = get_parent()
	if parent_container and parent_container is GridContainer:
		for child in parent_container.get_children():
			if child is TextureButton:
				print("Slot:", child.slot_index, "| Item:", child.item_texture)

# Debugging utility for z-index information
func debug_z_indexes() -> void:
	var inventory_scene = get_parent().get_parent()
	if inventory_scene and inventory_scene.has_method("append_debug_message"):
		inventory_scene.debug_z_indexes_on_screen()
	else:
		print("Debugging unavailable. Ensure the parent inventory scene implements debug methods.")
