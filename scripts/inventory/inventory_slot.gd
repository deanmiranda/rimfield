extends TextureButton

@export var slot_index: int = -1  # Unique index for this slot
@export var empty_texture: Texture  # Texture for empty slot

var item_texture: Texture = null  # Current item texture
var is_dragging: bool = false  # Tracks if dragging is active
var drag_preview: TextureRect = null  # Drag preview node reference
var is_dragging_global: bool = false  # Track dragging globally
var drag_preview_instance: TextureRect = null  # Global drag preview
var is_empty: bool = false
const MOUSE_BUTTON_LEFT = 1

func _ready() -> void:
	var parent = get_parent()
	if slot_index == -1 and parent:
		slot_index = parent.get_children().find(self) + 1
		if slot_index == 0:
			print("Error: Failed to find this slot in parent's children.")
	set_item(item_texture)
	mouse_filter = Control.MOUSE_FILTER_STOP

# Sets the texture for this slot
func set_item(new_texture: Texture) -> void:
	item_texture = new_texture if new_texture != null else empty_texture
	texture_normal = item_texture
	
# Handle input events
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_dragging_global:
				return
			if is_empty:
				return
			if item_texture:
				is_dragging = true
				is_dragging_global = true
				drag_preview = create_drag_preview(item_texture)

		elif not event.pressed and is_dragging:
			is_dragging = false
			is_dragging_global = false
			handle_drop(get_global_mouse_position())
			if drag_preview:
				drag_preview.queue_free()
				drag_preview = null
				is_dragging_global = false
	elif event is InputEventMouseMotion:
		if is_dragging:
			is_dragging = true
			is_dragging_global = true
			update_drag_preview_position()

# Creates a drag preview for the current slot
func create_drag_preview(item_texture: Texture) -> TextureRect:
	if drag_preview_instance != null:
		drag_preview_instance.queue_free()
		drag_preview_instance = null

	var preview = TextureRect.new()
	preview.texture = item_texture
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	preview.set_custom_minimum_size(Vector2(64, 64))
	preview.z_index = 1000
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Add to the root of the scene tree
	get_tree().root.add_child(preview)

	# Set initial position at the mouse
	preview.global_position = get_global_mouse_position()
	drag_preview_instance = preview
	return preview


# Updates drag preview position
func update_drag_preview_position() -> void:
	if drag_preview:
		drag_preview.global_position = get_global_mouse_position()

# Handle drop logic
func handle_drop(global_position: Vector2) -> void:
	reset_drag_state()

	var parent_container = get_parent()
	if parent_container and parent_container is GridContainer:
		for child in parent_container.get_children():
			if child is TextureButton and child.get_global_rect().has_point(global_position):
				if swap_items_with(child):
					return

	#debug_inventory_state()

# Swap items between slots
func swap_items_with(target_slot: TextureButton) -> bool:
	if target_slot.has_method("set_item"):
		var temp_texture = target_slot.item_texture
		target_slot.set_item(item_texture)
		set_item(temp_texture)
		return true
	return false

func reset_drag_state() -> void:
	if drag_preview_instance:
		drag_preview_instance.queue_free()
		drag_preview_instance = null
	else:
		print("DEBUG: No drag preview instance to clear in reset_drag_state.")
	
	is_dragging = false
	is_dragging_global = false

# Debug z-index information
func debug_z_indexes() -> void:
	var inventory_scene = get_parent().get_parent()
	if inventory_scene and inventory_scene.has_method("append_debug_message"):
		inventory_scene.debug_z_indexes_on_screen()
	else:
		print("Debugging unavailable. Ensure the parent inventory scene implements debug methods.")

func debug_inventory_state():
	var parent_container = get_parent()
	if parent_container and parent_container is GridContainer:
		for child in parent_container.get_children():
			if child is TextureButton:
				print("Slot:", child.slot_index, "| Item:", child.item_texture)
