# drag_manager.gd
# Global singleton for managing all inventory drag operations
# Provides single source of truth for drag state across all containers

extends Node

# Signals
signal dropped_on_world(source_container: Node, source_slot: int, texture: Texture, count: int, mouse_pos: Vector2)

# Drag state
var is_dragging: bool = false
var drag_source_container: Node = null # Which container did drag start from
var drag_source_slot_index: int = -1
var drag_item_texture: Texture = null
var drag_item_count: int = 0
var is_right_click_drag: bool = false

# Visual elements
var drag_preview: Control = null
var drag_preview_layer: CanvasLayer = null
var drag_preview_label: Label = null


func _ready() -> void:
	print("[DragManager] Initialized")
	set_process(false) # Enable when dragging


func _process(_delta: float) -> void:
	"""Update drag preview position to follow mouse"""
	if is_dragging and drag_preview:
		_update_drag_preview_position()


func start_drag(container: Node, slot_index: int, texture: Texture, count: int, right_click: bool = false) -> void:
	"""Start a drag operation"""
	if is_dragging:
		print("[DragManager] WARNING: Starting new drag while already dragging - canceling previous")
		cancel_drag()
	
	is_dragging = true
	drag_source_container = container
	drag_source_slot_index = slot_index
	drag_item_texture = texture
	is_right_click_drag = right_click
	
	# For right-click, only drag 1 item; for left-click, drag full stack
	if right_click:
		drag_item_count = 1
	else:
		drag_item_count = count
	
	print("[DragManager] Started drag: container=%s slot=%d texture=%s count=%d right_click=%s" % [
		str(container.name) if container else "null",
		slot_index,
		str(texture.resource_path) if texture else "null",
		drag_item_count,
		right_click
	])
	
	_create_preview(texture, drag_item_count)
	set_process(true) # Enable _process to update preview position
	
	# CRITICAL: Force immediate position update using root viewport
	var root_viewport = get_tree().root.get_viewport()
	if root_viewport:
		var mouse_pos = root_viewport.get_mouse_position()
		update_drag_preview_position(mouse_pos)
		print("[DragManager] Initial preview position set: %s" % mouse_pos)
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
	print("[DragManager] Emitted dropped_on_world: texture=%s count=%d pos=%s" % [
		drag_item_texture.resource_path if drag_item_texture else "null",
		drag_item_count,
		mouse_pos
	])


func end_drag() -> Dictionary:
	"""End drag operation and return drag data"""
	var drag_data = {
		"source_container": drag_source_container,
		"slot_index": drag_source_slot_index,
		"texture": drag_item_texture,
		"count": drag_item_count,
		"is_right_click": is_right_click_drag
	}
	
	print("[DragManager] Ended drag: source_slot=%d count=%d" % [drag_source_slot_index, drag_item_count])
	
	cleanup_preview()
	_reset_state()
	
	return drag_data


func cancel_drag() -> void:
	"""Cancel current drag operation - item returns to source"""
	if is_dragging:
		print("[DragManager] Drag canceled - item returns to source")
		cleanup_preview()
		_reset_state()


func clear_drag_state() -> void:
	"""Clear drag state and preview without restoring source (for successful world drops)"""
	"""Does NOT mutate inventory or restore source visuals - just cleans up drag state"""
	if is_dragging:
		print("[DragManager] Clearing drag state (world drop completed)")
		cleanup_preview()
		_reset_state()


func cleanup_preview() -> void:
	"""Remove drag preview from scene"""
	if drag_preview_layer:
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
		print("[DragManager] ERROR: No texture for preview!")
		return
	
	print("[DragManager] Creating drag preview for: %s" % texture.resource_path)
	
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
	
	print("[DragManager] Preview layer visible: %s, preview visible: %s, position: %s" % [
		drag_preview_layer.visible,
		drag_preview.visible,
		drag_preview.global_position
	])
	
	print("[DragManager] Drag preview created successfully")
	
	# Add count label if more than 1 item
	if count > 1:
		drag_preview_label = Label.new()
		drag_preview_label.text = str(count)
		drag_preview_label.add_theme_font_size_override("font_size", 14)
		drag_preview_label.add_theme_color_override("font_color", Color.WHITE)
		drag_preview_label.add_theme_color_override("font_outline_color", Color.BLACK)
		drag_preview_label.add_theme_constant_override("outline_size", 2)
		drag_preview_label.position = Vector2(32, 32) # Bottom-right corner
		drag_preview.add_child(drag_preview_label)
	
	# Position at mouse - use root viewport to ensure it works even when paused
	var root_viewport = get_tree().root.get_viewport()
	if root_viewport:
		var mouse_pos = root_viewport.get_mouse_position()
		update_drag_preview_position(mouse_pos)
		print("[DragManager] Initial mouse position: %s" % mouse_pos)
	else:
		# Fallback
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			update_drag_preview_position(mouse_pos)


func _update_drag_preview_position() -> void:
	"""Internal method to update preview position in _process"""
	if not drag_preview or not drag_preview_layer:
		return
		
	# Use root viewport to ensure it works even when game is paused
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


func _reset_state() -> void:
	"""Reset all drag state variables"""
	is_dragging = false
	drag_source_container = null
	drag_source_slot_index = -1
	drag_item_texture = null
	drag_item_count = 0
	is_right_click_drag = false


func get_hovered_slot() -> Node:
	"""Get the SlotBase node currently under the mouse cursor"""
	# Try gui_get_hovered_control() first (works for Control nodes)
	var viewport = get_tree().root.get_viewport()
	if not viewport:
		return null
	
	var hovered = viewport.gui_get_hovered_control()
	if not hovered:
		# Fallback: use mouse position + hit test
		var mouse_pos = viewport.get_mouse_position()
		return _find_slot_at_position(mouse_pos)
	
	# Walk up the parent tree to find SlotBase
	while hovered:
		if hovered is SlotBase:
			var slot = hovered as SlotBase
			# Only return if slot is a valid drop target
			if slot.is_drop_target_active():
				var container_id_str = slot.container_ref.container_id if slot.container_ref and "container_id" in slot.container_ref else "unknown"
				print("[DragManager] Hovered slot: slot_index=%d container_id=%s" % [slot.slot_index, container_id_str])
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
									var container_id_str = slot.container_ref.container_id if slot.container_ref and "container_id" in slot.container_ref else "unknown"
									print("[DragManager] Fallback found slot: slot_index=%d container_id=%s is_visible=%s drop_enabled=%s" % [
										slot.slot_index,
										container_id_str,
										slot.is_visible_in_tree(),
										slot.drop_target_enabled
									])
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
									print("[DragManager] Fallback found slot: slot_index=%d container_id=%s is_visible=%s drop_enabled=%s" % [
										slot.slot_index,
										container_id,
										slot.is_visible_in_tree(),
										slot.drop_target_enabled
									])
									return slot
	
	return null


func _input(event: InputEvent) -> void:
	"""Handle global input for drag cancellation"""
	if is_dragging and event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			print("[DragManager] ESC pressed - canceling drag")
			cancel_drag()
			get_viewport().set_input_as_handled()
