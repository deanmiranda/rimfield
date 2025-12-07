# drag_manager.gd
# Global singleton for managing all inventory drag operations
# Provides single source of truth for drag state across all containers

extends Node

# Signals
signal dropped_on_world(source_container: Node, source_slot: int, texture: Texture, count: int, mouse_pos: Vector2)
signal cursor_hold_dropped_on_world(texture: Texture, count: int, mouse_pos: Vector2)

# Drag state
var is_dragging: bool = false
var drag_source_container: Node = null # Which container did drag start from
var drag_source_slot_index: int = -1
var drag_item_texture: Texture = null
var drag_item_count: int = 0
var is_right_click_drag: bool = false

# Cursor-hold state (separate from dragging - for right-click pickup/accumulate/place)
var cursor_hold_active: bool = false
var cursor_hold_texture: Texture = null
var cursor_hold_count: int = 0

# Visual elements
var drag_preview: Control = null
var drag_preview_layer: CanvasLayer = null
var drag_preview_label: Label = null

# Cursor state for chest placement feedback
var blocked_cursor_texture: Texture = null
var is_chest_drag: bool = false


func _ready() -> void:
	# CRITICAL: Process even when tree is paused (e.g., when inventory/pause menu is open)
	# This ensures drag preview follows mouse correctly in both HUD-only and inventory-open states
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false) # Enable when dragging


func _process(_delta: float) -> void:
	"""Update drag preview position to follow mouse"""
	if (is_dragging or cursor_hold_active) and drag_preview:
		_update_drag_preview_position()


func start_drag(container: Node, slot_index: int, texture: Texture, count: int, right_click: bool = false) -> void:
	"""Start a drag operation"""
	if is_dragging:
		cancel_drag()
	
	is_dragging = true
	drag_source_container = container
	drag_source_slot_index = slot_index
	drag_item_texture = texture
	is_right_click_drag = right_click
	
	# Check if this is a chest drag for cursor feedback
	var tex_path = texture.resource_path if texture else ""
	is_chest_drag = (tex_path == "res://assets/icons/chest_icon.png")
	
	# Load blocked cursor texture if chest drag
	if is_chest_drag and not blocked_cursor_texture:
		blocked_cursor_texture = load("res://assets/ui/Close_Icon.png")
	
	# For right-click, only drag 1 item; for left-click, drag full stack
	if right_click:
		drag_item_count = 1
	else:
		drag_item_count = count
	
	_create_preview(texture, drag_item_count)
	set_process(true) # Enable _process to update preview position
	
	# CRITICAL: Force immediate position update using root viewport
	var root_viewport = get_tree().root.get_viewport()
	if root_viewport:
		var mouse_pos = root_viewport.get_mouse_position()
		update_drag_preview_position(mouse_pos)
	else:
		# Fallback
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			update_drag_preview_position(mouse_pos)


func emit_world_drop() -> void:
	"""Emit world drop signal with current drag data - does not mutate inventory"""
	if not is_dragging:
		return
	
	var viewport = get_viewport()
	if viewport == null:
		return
	
	var mouse_pos = viewport.get_mouse_position()
	
	dropped_on_world.emit(
		drag_source_container,
		drag_source_slot_index,
		drag_item_texture,
		drag_item_count,
		mouse_pos
	)


func end_drag() -> Dictionary:
	"""End drag operation and return drag data"""
	var drag_data = {
		"source_container": drag_source_container,
		"slot_index": drag_source_slot_index,
		"texture": drag_item_texture,
		"count": drag_item_count,
		"is_right_click": is_right_click_drag
	}
	
	cleanup_preview()
	_reset_state()
	_reset_cursor()
	
	return drag_data


func cancel_drag() -> void:
	"""Cancel current drag operation - item returns to source"""
	if is_dragging:
		cleanup_preview()
		_reset_state()
		_reset_cursor()


func clear_drag_state() -> void:
	"""Clear drag state and preview without restoring source (for successful world drops)"""
	"""Does NOT mutate inventory or restore source visuals - just cleans up drag state"""
	if is_dragging:
		cleanup_preview()
		_reset_state()
		_reset_cursor()


func cleanup_preview() -> void:
	"""Remove drag preview from scene"""
	if drag_preview_layer:
		# Immediately hide and remove preview
		if drag_preview:
			drag_preview.visible = false
		if drag_preview_label:
			drag_preview_label.visible = false
		drag_preview_layer.visible = false
		# Use free() for immediate removal instead of queue_free()
		if is_instance_valid(drag_preview_layer):
			drag_preview_layer.queue_free()
		drag_preview_layer = null
		drag_preview = null
		drag_preview_label = null
	set_process(false)


func update_drag_preview_position(mouse_pos: Vector2) -> void:
	"""Update preview position (can be called externally or via _process)"""
	if drag_preview and drag_preview_layer:
		# Offset slightly so cursor isn't covering the item
		# Use global_position since we're in a CanvasLayer
		drag_preview.global_position = mouse_pos - Vector2(24, 24)
		# Ensure it's visible
		drag_preview.visible = true
		drag_preview_layer.visible = true
		
		# Debug: Verify preview is actually visible and positioned
		# (Removed frequent logging - uncomment if needed for debugging)
		# if Engine.get_process_frames() % 60 == 0:
		# 	print("[DragManager] Preview at: %s (mouse: %s)" % [drag_preview.global_position, mouse_pos])


func _create_preview(texture: Texture, count: int) -> void:
	"""Create visual drag preview"""
	if not texture:
		return
	
	# Create canvas layer at high z-index so it's above everything
	drag_preview_layer = CanvasLayer.new()
	drag_preview_layer.name = "DragPreviewLayer"
	drag_preview_layer.layer = 100 # Very high layer to ensure visibility
	drag_preview_layer.process_mode = Node.PROCESS_MODE_ALWAYS # CRITICAL: Process even when paused!
	drag_preview_layer.visible = true # CRITICAL: Make sure layer is visible
	get_tree().root.add_child(drag_preview_layer)
	
	# Create texture display
	drag_preview = TextureRect.new()
	drag_preview.texture = texture
	drag_preview.modulate = Color(1, 1, 1, 0.7) # Semi-transparent
	drag_preview.custom_minimum_size = Vector2(48, 48)
	drag_preview.size = Vector2(48, 48) # Set explicit size
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.ignore_texture_size = true
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE # Don't block mouse events
	drag_preview.visible = true # Ensure it's visible
	drag_preview.z_index = 1000 # High z-index
	drag_preview.z_as_relative = false
	drag_preview.show() # Explicitly show
	drag_preview_layer.add_child(drag_preview)
	
	# Force update to ensure visibility
	drag_preview_layer.show()
	drag_preview.show()
	
	# Add count label if more than 1 item (or if cursor-hold, always show count)
	if count > 1 or cursor_hold_active:
		_create_preview_label(count)


func _create_preview_label(count: int) -> void:
	"""Create or update the preview label"""
	if not drag_preview:
		return
	
	if not drag_preview_label:
		drag_preview_label = Label.new()
		drag_preview_label.add_theme_font_size_override("font_size", 14)
		drag_preview_label.add_theme_color_override("font_color", Color.WHITE)
		drag_preview_label.add_theme_color_override("font_outline_color", Color.BLACK)
		drag_preview_label.add_theme_constant_override("outline_size", 2)
		drag_preview_label.position = Vector2(32, 32) # Bottom-right corner
		drag_preview.add_child(drag_preview_label)
	
	drag_preview_label.text = str(count)
	drag_preview_label.visible = true


func _ensure_cursor_hold_label() -> void:
	"""Ensure cursor-hold label exists and is visible (always show count for cursor-hold)"""
	if cursor_hold_active and drag_preview:
		if not drag_preview_label:
			_create_preview_label(cursor_hold_count)
		else:
			drag_preview_label.text = str(cursor_hold_count)
			drag_preview_label.visible = true


func _update_drag_preview_position() -> void:
	"""Internal method to update preview position in _process"""
	if not drag_preview or not drag_preview_layer:
		return
		
	# Use root viewport to ensure it works even when game is paused
	var root_viewport = get_tree().root.get_viewport()
	if root_viewport:
		var mouse_pos = root_viewport.get_mouse_position()
		update_drag_preview_position(mouse_pos)
		
		# Update cursor for chest drags based on placement validity
		if is_chest_drag and is_dragging:
			_update_chest_drag_cursor(mouse_pos)
	else:
		# Fallback
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			update_drag_preview_position(mouse_pos)
			# Update cursor for chest drags
			if is_chest_drag and is_dragging:
				_update_chest_drag_cursor(mouse_pos)


func _reset_state() -> void:
	"""Reset all drag state variables"""
	is_dragging = false
	drag_source_container = null
	drag_source_slot_index = -1
	drag_item_texture = null
	drag_item_count = 0
	is_right_click_drag = false
	is_chest_drag = false
	# Reset cursor to default
	_reset_cursor()


# ============================================================================
# CURSOR-HOLD STATE (for right-click pickup/accumulate/place)
# ============================================================================

func start_cursor_hold(texture: Texture, count: int) -> void:
	"""Start cursor-hold mode (pickup items into cursor)"""
	# Clear any existing drag state first
	if is_dragging:
		clear_drag_state()
	
	cursor_hold_active = true
	cursor_hold_texture = texture
	cursor_hold_count = count
	
	# Reuse existing preview UI for cursor-hold
	_create_preview(texture, count)
	# Ensure label exists and shows count (always show count for cursor-hold)
	_ensure_cursor_hold_label()
	set_process(true)
	
	# Update preview position immediately
	var viewport = get_viewport()
	if viewport:
		var mouse_pos = viewport.get_mouse_position()
		update_drag_preview_position(mouse_pos)


func add_one_to_cursor_from(source_container: Node, source_slot: int) -> bool:
	"""Add 1 item from source slot to cursor (accumulate) - returns true if successful"""
	if not cursor_hold_active:
		return false
	
	if not source_container or not source_container.has_method("get_slot_data"):
		return false
	
	var source_data = source_container.get_slot_data(source_slot)
	if not source_data["texture"] or source_data["count"] <= 0:
		return false
	
	# Must be same texture
	if source_data["texture"] != cursor_hold_texture:
		return false
	
	# Check max stack (global max = 10)
	if cursor_hold_count >= 10:
		return false
	
	# Remove 1 from source using ContainerBase API
	var remaining = source_data["count"] - 1
	if remaining > 0:
		if source_container.has_method("set_slot_data"):
			source_container.set_slot_data(source_slot, source_data["texture"], remaining)
		else:
			source_container.remove_item_from_slot(source_slot)
			source_container.add_item_to_slot(source_slot, source_data["texture"], remaining)
	else:
		source_container.remove_item_from_slot(source_slot)
	
	# Increment cursor count
	cursor_hold_count += 1
	
	# Update preview label (ensure it exists)
	_ensure_cursor_hold_label()
	if drag_preview_label:
		drag_preview_label.text = str(cursor_hold_count)
	
	return true


func place_one_from_cursor_to(target_container: Node, target_slot: int) -> bool:
	"""Place 1 item from cursor to target slot - returns true if successful"""
	if not cursor_hold_active:
		return false
	
	if not target_container or not target_container.has_method("get_slot_data"):
		return false
	
	var target_data = target_container.get_slot_data(target_slot)
	
	# Check if target is empty or same texture
	if target_data["texture"] and target_data["texture"] != cursor_hold_texture:
		# Different texture - no swap on right-click
		return false
	
	# Check max stack
	if target_data["texture"]:
		# Same texture - check if can stack
		if target_data["count"] >= 10:
			return false
	
	# Place 1 into target using ContainerBase API
	target_container.add_item_to_slot(target_slot, cursor_hold_texture, 1)
	
	# Decrement cursor count
	cursor_hold_count -= 1
	
	# Update preview or clear if empty
	if cursor_hold_count <= 0:
		clear_cursor_hold()
	else:
		if drag_preview_label:
			drag_preview_label.text = str(cursor_hold_count)
	return true


func add_five_to_cursor_from(source_container: Node, source_slot: int) -> bool:
	"""Add 5 items from source slot to cursor (Ctrl+Right-click) - returns true if successful"""
	if not cursor_hold_active:
		return false
	
	if not source_container or not source_container.has_method("get_slot_data"):
		return false
	
	var source_data = source_container.get_slot_data(source_slot)
	if not source_data["texture"] or source_data["count"] <= 0:
		return false
	
	# Must be same texture
	if source_data["texture"] != cursor_hold_texture:
		return false
	
	# Calculate how many can be added (max 10 total, or 5 at a time)
	var available_space = 10 - cursor_hold_count
	if available_space <= 0:
		return false
	
	var to_add = min(5, source_data["count"], available_space)
	if to_add <= 0:
		return false
	
	# Remove items from source
	var remaining = source_data["count"] - to_add
	if remaining > 0:
		if source_container.has_method("set_slot_data"):
			source_container.set_slot_data(source_slot, source_data["texture"], remaining)
		else:
			source_container.remove_item_from_slot(source_slot)
			source_container.add_item_to_slot(source_slot, source_data["texture"], remaining)
	else:
		source_container.remove_item_from_slot(source_slot)
	
	# Increment cursor count
	cursor_hold_count += to_add
	
	# Update preview label
	_ensure_cursor_hold_label()
	
	return true


func place_five_from_cursor_to(target_container: Node, target_slot: int) -> bool:
	"""Place 5 items from cursor to target slot (Ctrl+Right-click) - returns true if successful"""
	if not cursor_hold_active:
		return false
	
	if not target_container or not target_container.has_method("get_slot_data"):
		return false
	
	var target_data = target_container.get_slot_data(target_slot)
	
	# Check if target is empty or same texture
	if target_data["texture"] and target_data["texture"] != cursor_hold_texture:
		# Different texture - no swap on right-click
		return false
	
	# Calculate how many can be placed
	var available_space = 10
	if target_data["texture"]:
		# Same texture - check available space
		available_space = 10 - target_data["count"]
	
	if available_space <= 0:
		return false
	
	var to_place = min(5, cursor_hold_count, available_space)
	if to_place <= 0:
		return false
	
	# Place items into target using ContainerBase API
	target_container.add_item_to_slot(target_slot, cursor_hold_texture, to_place)
	
	# Decrement cursor count
	cursor_hold_count -= to_place
	
	# Update preview or clear if empty
	if cursor_hold_count <= 0:
		clear_cursor_hold()
	else:
		_ensure_cursor_hold_label()
	
	return true


func place_all_from_cursor_to(target_container: Node, target_slot: int) -> bool:
	"""Place all items from cursor to target slot (left-click) - returns true if successful"""
	if not cursor_hold_active:
		return false
	
	if not target_container or not target_container.has_method("get_slot_data"):
		return false
	
	var target_data = target_container.get_slot_data(target_slot)
	
	# Check if target is empty or same texture
	if target_data["texture"] and target_data["texture"] != cursor_hold_texture:
		# Different texture - use existing swap logic (left-click allows swap)
		# For now, don't swap from cursor-hold - just return false
		return false
	
	# Compute how many can fit
	var space = 10 - target_data["count"]
	var to_place = min(space, cursor_hold_count)
	
	if to_place <= 0:
		return false
	
	# Place items using ContainerBase API
	target_container.add_item_to_slot(target_slot, cursor_hold_texture, to_place)
	
	# Update cursor count
	cursor_hold_count -= to_place
	
	# Update preview or clear if empty
	if cursor_hold_count <= 0:
		clear_cursor_hold()
	else:
		if drag_preview_label:
			drag_preview_label.text = str(cursor_hold_count)
	
	return true


func pickup_full_stack_to_cursor_from(source_container: Node, source_slot: int) -> void:
	"""Pickup full stack from source slot into cursor-hold"""
	if not source_container or not source_container.has_method("get_slot_data"):
		return
	
	# Get slot data
	var slot_data = source_container.get_slot_data(source_slot)
	if not slot_data:
		return
	
	var texture = slot_data.get("texture")
	var count = int(slot_data.get("count", 0))
	
	if not texture or count <= 0:
		return
	
	# Remove entire stack from source
	if source_container.has_method("remove_item_from_slot"):
		source_container.remove_item_from_slot(source_slot)
	elif source_container.has_method("set_slot_data"):
		source_container.set_slot_data(source_slot, null, 0)
	else:
		return
	
	# Start cursor-hold with full stack
	start_cursor_hold(texture, count)


func clear_cursor_hold() -> void:
	"""Clear cursor-hold state"""
	if cursor_hold_active:
		cursor_hold_active = false
		cursor_hold_texture = null
		cursor_hold_count = 0
		cleanup_preview()


func emit_cursor_hold_world_drop(drop_count: int, mouse_pos: Vector2) -> void:
	"""Emit cursor-hold world drop signal and update cursor state"""
	if not cursor_hold_active:
		return
	
	if not cursor_hold_texture:
		return
	
	if drop_count <= 0:
		return
	
	# Clamp drop_count to available
	var actual_drop_count = min(drop_count, cursor_hold_count)
	if actual_drop_count <= 0:
		return
	
	# Emit signal (consumption happens in farm_scene after successful spawn)
	cursor_hold_dropped_on_world.emit(cursor_hold_texture, actual_drop_count, mouse_pos)


func consume_from_cursor_hold(amount: int) -> int:
	"""Consume amount from cursor-hold - returns actual amount consumed"""
	if not cursor_hold_active:
		return 0
	
	if amount <= 0:
		return 0
	
	# Clamp to available
	var actual_amount = min(amount, cursor_hold_count)
	if actual_amount <= 0:
		return 0
	
	# Decrement cursor count
	cursor_hold_count -= actual_amount
	
	# Update preview or clear if empty
	if cursor_hold_count <= 0:
		clear_cursor_hold()
	else:
		_ensure_cursor_hold_label()
	
	return actual_amount


func try_world_click_drop(is_right_click: bool) -> bool:
	"""Try to drop cursor-hold items to world - returns true if drop occurred"""
	if not cursor_hold_active:
		return false
	
	# Determine drop count
	var drop_count = cursor_hold_count
	if is_right_click:
		drop_count = 1
	
	# Get mouse position
	var viewport = get_viewport()
	if not viewport:
		return false
	
	var click_pos = viewport.get_mouse_position()
	
	# Emit world drop
	emit_cursor_hold_world_drop(drop_count, click_pos)
	return true


func get_hovered_slot() -> Node:
	"""Get the SlotBase node currently under the mouse cursor"""
	# Try gui_get_hovered_control() first (works for Control nodes)
	var viewport = get_tree().root.get_viewport()
	if not viewport:
		return null
	
	var hovered = viewport.gui_get_hovered_control()
	if not hovered:
		# Fallback: use mouse position + hit test
		var fallback_mouse_pos = viewport.get_mouse_position()
		return _find_slot_at_position(fallback_mouse_pos)
	
	# Walk up the parent tree to find SlotBase
	while hovered:
		if hovered is SlotBase:
			var slot = hovered as SlotBase
			# Only return if slot is a valid drop target
			if slot.is_drop_target_active():
				return slot
		hovered = hovered.get_parent()
	
	# Fallback: use mouse position + hit test
	var mouse_pos = viewport.get_mouse_position()
	return _find_slot_at_position(mouse_pos)


func _find_slot_at_position(mouse_pos: Vector2) -> Node:
	"""Fallback: find SlotBase at mouse position using hit test"""
	# Search all SlotBase nodes in the scene
	var all_slots = get_tree().get_nodes_in_group("inventory_slots")
	if all_slots.size() == 0:
		# If no group, search manually
		var hud = get_tree().root.get_node_or_null("Hud")
		if hud:
			var slots_container = hud.get_node_or_null("HUD/MarginContainer/HBoxContainer")
			if slots_container:
				for child in slots_container.get_children():
					if child is SlotBase:
						var slot = child as SlotBase
						# Check visibility, mouse filter, and drop target enabled
						if is_instance_valid(slot) and slot.is_visible_in_tree() and slot.is_drop_target_active():
							if slot.mouse_filter != Control.MOUSE_FILTER_IGNORE:
								var slot_rect = slot.get_global_rect()
								if slot_rect.has_point(mouse_pos):
									return slot
	
	# Check registered containers' slots
	if InventoryManager:
		for container_id in InventoryManager.containers:
			var container = InventoryManager.containers[container_id]
			if container and container.has_method("get") and "slots" in container:
				for slot in container.slots:
					if slot and is_instance_valid(slot):
						# Check visibility, mouse filter, and drop target enabled
						if slot.is_visible_in_tree() and slot.is_drop_target_active():
							if slot.mouse_filter != Control.MOUSE_FILTER_IGNORE:
								var slot_rect = slot.get_global_rect()
								if slot_rect.has_point(mouse_pos):
									return slot
	
	return null


func _update_chest_drag_cursor(_mouse_pos: Vector2) -> void:
	"""Update cursor when dragging chest over blocked tiles"""
	if not is_chest_drag or not is_dragging:
		return
	
	# Get world position from screen position
	var current_scene = get_tree().current_scene
	if not current_scene or current_scene.name != "Farm":
		_reset_cursor()
		return
	
	# Convert screen mouse position to world position using MouseUtil
	var world_pos: Vector2
	if MouseUtil:
		world_pos = MouseUtil.get_world_mouse_pos_2d(current_scene)
	else:
		# Fallback: use viewport camera
		var viewport = get_viewport()
		if not viewport:
			_reset_cursor()
			return
		var camera = viewport.get_camera_2d()
		if not camera:
			_reset_cursor()
			return
		world_pos = camera.get_global_mouse_position()
	
	# Check if placement is blocked using ChestManager
	var chest_manager = get_node_or_null("/root/ChestManager")
	if not chest_manager:
		_reset_cursor()
		return
	
	# Check placement validity (includes TileMapLayer checks)
	var can_place = chest_manager.can_place_chest("Farm", world_pos)
	
	if can_place:
		_reset_cursor()
	else:
		_set_blocked_cursor()


func _set_blocked_cursor() -> void:
	"""Set cursor to blocked icon"""
	if blocked_cursor_texture:
		Input.set_custom_mouse_cursor(blocked_cursor_texture, Input.CURSOR_ARROW, Vector2(0, 0))


func _reset_cursor() -> void:
	"""Reset cursor to default"""
	Input.set_custom_mouse_cursor(null)


func _input(event: InputEvent) -> void:
	"""Handle global input for drag cancellation"""
	if is_dragging and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			cancel_drag()
			get_viewport().set_input_as_handled()
