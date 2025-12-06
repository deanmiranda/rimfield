# slot_base.gd
# Minimal inventory slot component using custom mouse event handling
# NO Godot drag/drop - we use DragManager instead for full control

extends TextureButton

class_name SlotBase

# Signals
signal tool_selected(slot_index: int, item_texture: Texture)

# Slot configuration
@export var slot_index: int = 0
@export var empty_texture: Texture = null

# Item data
var item_texture: Texture = null
var stack_count: int = 0

# Container reference (parent container that owns this slot)
var container_ref: Node = null

# Drop target state (can be disabled when UI panel is hidden)
var drop_target_enabled: bool = true

# Visual elements
var stack_label: Label = null

# Mouse state tracking
var mouse_is_down: bool = false
var click_start_time: float = 0.0
var drag_start_position: Vector2 = Vector2.ZERO
const CLICK_THRESHOLD: float = 0.2 # Seconds to distinguish click from drag
const DRAG_THRESHOLD: float = 5.0 # Pixels to move before allowing drop (prevents same-slot cancel)

# Store original slot data before drag (for restoration on cancel)
var original_slot_data: Dictionary = {}


func _ready() -> void:
	# Configure button behavior
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	
	# Add to group for hover detection
	add_to_group("inventory_slots")
	
	# Set empty texture if provided
	if empty_texture:
		texture_normal = empty_texture
	
	# Create stack count label
	_create_stack_label()
	
	# Ensure child nodes don't block mouse events
	call_deferred("_fix_children_mouse_filter")
	
	# Update visual to reflect initial item state
	update_visual()


func is_drop_target_active() -> bool:
	"""Check if this slot is a valid drop target (enabled and visible)"""
	return drop_target_enabled and is_visible_in_tree()


func _fix_children_mouse_filter() -> void:
	"""Ensure all child nodes ignore mouse events"""
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			child.focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	"""Handle mouse events for custom drag system"""
	if event is InputEventMouseButton:
		if event.pressed:
			# Mouse button pressed down
			mouse_is_down = true
			click_start_time = Time.get_ticks_msec() / 1000.0
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_left_click_down(event)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_on_right_click_down(event)
		else:
			# Mouse button released
			mouse_is_down = false
			var click_duration = (Time.get_ticks_msec() / 1000.0) - click_start_time
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				_on_left_click_up(event, click_duration)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_on_right_click_up(event, click_duration)


func _on_left_click_down(event: InputEventMouseButton) -> void:
	"""Handle left mouse button press"""
	if event.shift_pressed and item_texture:
		# Shift+click - quick transfer
		_handle_shift_click()
		return
	
	# Check if DragManager is already dragging (means we're receiving a drop)
	if DragManager and DragManager.is_dragging:
		# Drop will be handled in _on_left_click_up
		pass
	else:
		# Start drag immediately on mouse down if slot has item
		if item_texture and stack_count > 0:
			# Store mouse position to track movement
			var viewport = get_viewport()
			if viewport:
				drag_start_position = viewport.get_mouse_position()
			_start_drag(false)


func _on_left_click_up(_event: InputEventMouseButton, _duration: float) -> void:
	"""Handle left mouse button release"""
	if DragManager and DragManager.is_dragging:
		# Check if we're the source and mouse hasn't moved - cancel instead of drop
		if DragManager.drag_source_container == container_ref and DragManager.drag_source_slot_index == slot_index:
			var viewport = get_viewport()
			if viewport:
				var current_pos = viewport.get_mouse_position()
				var distance = drag_start_position.distance_to(current_pos)
				if distance < DRAG_THRESHOLD:
					# Mouse hasn't moved enough - cancel drag (user just clicked, didn't drag)
					print("[SlotBase] Mouse hasn't moved enough (%f < %f) - canceling drag" % [distance, DRAG_THRESHOLD])
					DragManager.cancel_drag()
					_restore_after_cancel()
					
					# This was a click, not a drag - emit tool_selected for ToolSwitcher
					if container_ref and "container_type" in container_ref:
						if container_ref.container_type == "toolkit":
							emit_signal("tool_selected", slot_index, item_texture)
							print("[SlotBase] Emitted tool_selected: slot %d" % slot_index)
					
					accept_event()
					get_viewport().set_input_as_handled()
					return
		
		# CRITICAL: Find the actual hovered slot (target), not self (source)
		var target_slot_node = DragManager.get_hovered_slot()
		
		if target_slot_node and target_slot_node.container_ref:
			# Route drop to the hovered slot's container
			var target_container_id = target_slot_node.container_ref.container_id if "container_id" in target_slot_node.container_ref else "unknown"
			print("[SlotBase] Resolved drop: source_slot=%d target_slot=%d target_container=%s" % [
				DragManager.drag_source_slot_index,
				target_slot_node.slot_index,
				target_container_id
			])
			target_slot_node.container_ref.handle_drop_on_slot(target_slot_node.slot_index)
			
			# Sync our visual in case we were the source
			if container_ref.has_method("get_slot_data"):
				var updated_data = container_ref.get_slot_data(slot_index)
				item_texture = updated_data["texture"]
				stack_count = updated_data["count"]
				update_visual()
			
			# Clear stored original data (drop committed)
			original_slot_data.clear()
		else:
			# No valid target found - check if item is world-placeable
			if _is_world_placeable_drag():
				print("[SlotBase] No hovered slot found, but item is world-placeable - emitting world drop")
				DragManager.emit_world_drop()
				# Clear stored original data (world drop committed)
				original_slot_data.clear()
			else:
				# No valid target and not world-placeable - cancel drag
				print("[SlotBase] No hovered slot found - canceling drag")
				DragManager.cancel_drag()
				_restore_after_cancel()
		
		accept_event() # Consume the event to prevent further processing
		get_viewport().set_input_as_handled()
		return # CRITICAL: Don't start a new drag!


func _on_right_click_down(_event: InputEventMouseButton) -> void:
	"""Handle right mouse button press"""
	# Check if DragManager is already dragging (means we're receiving a drop)
	if DragManager and DragManager.is_dragging:
		# Drop will be handled in _on_right_click_up
		pass
	else:
		# Start drag with single item (Stardew-style peel)
		if item_texture and stack_count > 0:
			# Store mouse position to track movement
			var viewport = get_viewport()
			if viewport:
				drag_start_position = viewport.get_mouse_position()
			_start_drag(true)


func _on_right_click_up(_event: InputEventMouseButton, _duration: float) -> void:
	"""Handle right mouse button release"""
	if DragManager and DragManager.is_dragging:
		# Check if we're the source and mouse hasn't moved - cancel instead of drop
		if DragManager.drag_source_container == container_ref and DragManager.drag_source_slot_index == slot_index:
			var viewport = get_viewport()
			if viewport:
				var current_pos = viewport.get_mouse_position()
				var distance = drag_start_position.distance_to(current_pos)
				if distance < DRAG_THRESHOLD:
					# Mouse hasn't moved enough - cancel drag (user just clicked, didn't drag)
					print("[SlotBase] Right-click: Mouse hasn't moved enough (%f < %f) - canceling drag" % [distance, DRAG_THRESHOLD])
					DragManager.cancel_drag()
					_restore_after_cancel()
					accept_event()
					get_viewport().set_input_as_handled()
					return
		
		# CRITICAL: Find the actual hovered slot (target), not self (source)
		var target_slot_node = DragManager.get_hovered_slot()
		
		if target_slot_node and target_slot_node.container_ref:
			# Route drop to the hovered slot's container
			var target_container_id = target_slot_node.container_ref.container_id if "container_id" in target_slot_node.container_ref else "unknown"
			print("[SlotBase] Resolved drop: source_slot=%d target_slot=%d target_container=%s" % [
				DragManager.drag_source_slot_index,
				target_slot_node.slot_index,
				target_container_id
			])
			target_slot_node.container_ref.handle_drop_on_slot(target_slot_node.slot_index)
			
			# Sync our visual in case we were the source
			if container_ref.has_method("get_slot_data"):
				var updated_data = container_ref.get_slot_data(slot_index)
				item_texture = updated_data["texture"]
				stack_count = updated_data["count"]
				update_visual()
			
			# Clear stored original data (drop committed)
			original_slot_data.clear()
		else:
			# No valid target found - check if item is world-placeable
			if _is_world_placeable_drag():
				print("[SlotBase] No hovered slot found, but item is world-placeable - emitting world drop")
				DragManager.emit_world_drop()
				# Clear stored original data (world drop committed)
				original_slot_data.clear()
			else:
				# No valid target and not world-placeable - cancel drag
				print("[SlotBase] No hovered slot found - canceling drag")
				DragManager.cancel_drag()
				_restore_after_cancel()
		
		accept_event() # Consume the event
		get_viewport().set_input_as_handled()
		return # CRITICAL: Don't start a new drag!


func _is_world_placeable_drag() -> bool:
	"""Check if the current drag should be placeable in the world"""
	if not DragManager or not DragManager.is_dragging:
		return false
	
	if DragManager.drag_source_container == null:
		return false
	
	# Only toolkit items can be placed into world right now
	var source_id = ""
	if "container_id" in DragManager.drag_source_container:
		source_id = DragManager.drag_source_container.container_id
	
	if source_id != "player_toolkit":
		return false
	
	if DragManager.drag_item_texture == null:
		return false
	
	var tex_path = DragManager.drag_item_texture.resource_path
	if tex_path == "res://assets/icons/chest_icon.png":
		return true
	
	return false


func _start_drag(is_right_click: bool) -> void:
	"""Start drag operation via DragManager"""
	if not DragManager:
		print("[SlotBase] ERROR: DragManager not available!")
		return
	
	if not container_ref:
		print("[SlotBase] ERROR: No container_ref set for slot %d" % slot_index)
		return
	
	if not item_texture or stack_count <= 0:
		return
	
	# CRITICAL: Store original slot data BEFORE any changes
	# This allows us to restore on cancel
	if container_ref.has_method("get_slot_data"):
		original_slot_data = container_ref.get_slot_data(slot_index).duplicate(true)
	else:
		original_slot_data = {"texture": item_texture, "count": stack_count, "weight": 0.0}
	
	print("[SlotBase] Drag START (read-only): slot=%d texture=%s count=%d right_click=%s" % [
		slot_index,
		item_texture.resource_path if item_texture else "null",
		stack_count,
		is_right_click
	])
	
	# Start drag in DragManager
	if DragManager:
		DragManager.start_drag(container_ref, slot_index, item_texture, stack_count, is_right_click)
		
		# TRANSACTIONAL: Only update VISUAL, NOT container data!
		# Container data will be updated on successful drop only
		modulate = Color(1, 1, 1, 0.3)
		
		# Update visual preview only (local to this slot, not container data)
		if is_right_click:
			# Show reduced count visually
			var remaining = stack_count - 1
			if remaining > 0:
				# Update LOCAL visual only (SlotBase state, NOT container data)
				item_texture = item_texture # Keep same
				stack_count = remaining
				update_visual()
			else:
				# Show empty
				item_texture = null
				stack_count = 0
				update_visual()
		else:
			# Show empty (full stack being dragged)
			item_texture = null
			stack_count = 0
			update_visual()
		
		print("[SlotBase] Visual updated (data NOT modified yet)")


func _handle_drop() -> void:
	"""Handle drop from DragManager"""
	if not DragManager or not DragManager.is_dragging:
		return
	
	# CRITICAL: If dragging from chest, check if mouse is over a HUD slot first
	# If so, don't handle the drop here - let the HUD slot handle it
	if container_ref and "container_type" in container_ref:
		var container_type = container_ref.container_type
		if container_type == "chest" or container_type == "fridge" or container_type == "container":
			var viewport = get_viewport()
			if viewport:
				var mouse_pos = viewport.get_mouse_position()
				if _is_mouse_over_hud_slot(mouse_pos):
					print("[SlotBase] Mouse is over HUD slot - letting HUD handle drop")
					return
	
	# Check if dropping on the same slot that's being dragged
	# (This check is now redundant since we handle it in _on_left_click_up, but keep for safety)
	if DragManager.drag_source_container == container_ref and DragManager.drag_source_slot_index == slot_index:
		# Double-check mouse has moved
		var viewport = get_viewport()
		if viewport:
			var current_pos = viewport.get_mouse_position()
			var distance = drag_start_position.distance_to(current_pos)
			if distance < DRAG_THRESHOLD:
				print("[SlotBase] Dropping on source slot without movement - canceling drag instead")
				DragManager.cancel_drag()
				_restore_after_cancel()
				return
	
	var container_id_str = container_ref.container_id if container_ref and "container_id" in container_ref else "unknown"
	var source_container_id = DragManager.drag_source_container.container_id if DragManager.drag_source_container and "container_id" in DragManager.drag_source_container else "unknown"
	
	print("[SlotBase] Handling drop: container_id=%s source_slot=%d target_slot=%d" % [
		container_id_str,
		DragManager.drag_source_slot_index,
		slot_index
	])
	
	if not container_ref:
		print("[SlotBase] ERROR: No container_ref for drop on slot %d" % slot_index)
		return
	
	# Restore modulate before handling drop
	modulate = Color.WHITE
	
	print("[SlotBase] Drag DROP: letting container commit changes")
	
	# TRANSACTIONAL: Let container handle the drop logic and commit changes
	# Container will update both source and destination data
	if container_ref.has_method("handle_drop_on_slot"):
		container_ref.handle_drop_on_slot(slot_index)
		
		# After drop, sync our visual from container (in case we were the source)
		if container_ref.has_method("get_slot_data"):
			var updated_data = container_ref.get_slot_data(slot_index)
			item_texture = updated_data["texture"]
			stack_count = updated_data["count"]
			update_visual()
			print("[SlotBase] Drop SUCCESS: synced visual from container")
		
		# Clear stored original data (drop committed)
		original_slot_data.clear()
	else:
		print("[SlotBase] ERROR: Container %s doesn't have handle_drop_on_slot method" % container_ref.name)
		# Restore on error
		_restore_after_cancel()


func _is_mouse_over_hud_slot(mouse_pos: Vector2) -> bool:
	"""Check if mouse is over any HUD slot"""
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		hud = get_tree().current_scene.get_node_or_null("Hud")
	if not hud:
		return false
	
	var hud_canvas = hud.get_node_or_null("HUD")
	if not hud_canvas:
		return false
	
	var slots_container = hud_canvas.get_node_or_null("MarginContainer/HBoxContainer")
	if not slots_container:
		return false
	
	# Check each HUD slot
	for slot in slots_container.get_children():
		if slot and slot is TextureButton:
			var slot_rect = slot.get_global_rect()
			if slot_rect.has_point(mouse_pos):
				return true
	
	return false


func _restore_after_cancel() -> void:
	"""Restore slot visual after drag is canceled (TRANSACTIONAL)"""
	modulate = Color.WHITE
	
	# TRANSACTIONAL: Container data was NEVER modified during drag
	# Just restore visual from original_slot_data
	if original_slot_data.size() > 0:
		# Restore LOCAL visual state (item_texture, stack_count)
		item_texture = original_slot_data["texture"]
		stack_count = original_slot_data["count"]
		update_visual()
		
		print("[SlotBase] Drag CANCELED: restored visual from original data")
		
		# Clear stored data
		original_slot_data.clear()
	else:
		# Fallback: sync from container (which should still have original data)
		if container_ref and container_ref.has_method("get_slot_data"):
			var slot_data = container_ref.get_slot_data(slot_index)
			item_texture = slot_data["texture"]
			stack_count = slot_data["count"]
			update_visual()
			print("[SlotBase] Drag CANCELED: restored visual from container data")


func _on_slot_clicked() -> void:
	"""Handle simple click (not drag) - currently unused for chest slots"""
	# For chest slots, all interactions are drags, not clicks
	pass


func _handle_shift_click() -> void:
	"""Handle Shift+click quick transfer"""
	if not container_ref or not item_texture:
		return
	
	print("[SlotBase] Shift+click on slot %d" % slot_index)
	
	# Let container handle shift-click logic
	if container_ref.has_method("handle_shift_click"):
		container_ref.handle_shift_click(slot_index)


func set_item(texture: Texture, count: int) -> void:
	"""Set slot's item and count"""
	item_texture = texture
	stack_count = max(0, count)
	update_visual()


func clear_item() -> void:
	"""Clear the slot"""
	item_texture = null
	stack_count = 0
	update_visual()


func get_item_data() -> Dictionary:
	"""Return slot's current item data"""
	return {
		"texture": item_texture,
		"count": stack_count
	}


func update_visual() -> void:
	"""Update visual appearance based on current item"""
	if item_texture:
		texture_normal = item_texture
		modulate = Color.WHITE
	else:
		texture_normal = empty_texture if empty_texture else null
		modulate = Color.WHITE
	
	# Update stack label
	_update_stack_label()


func _create_stack_label() -> void:
	"""Create label for stack count display"""
	stack_label = Label.new()
	stack_label.name = "StackLabel"
	stack_label.text = ""
	stack_label.add_theme_font_size_override("font_size", 14)
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	stack_label.add_theme_color_override("font_outline_color", Color.BLACK)
	stack_label.add_theme_constant_override("outline_size", 2)
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_label.anchors_preset = Control.PRESET_FULL_RECT
	stack_label.offset_right = -4
	stack_label.offset_bottom = -4
	add_child(stack_label)


func _update_stack_label() -> void:
	"""Update stack count label text"""
	if stack_label:
		if stack_count > 1:
			stack_label.text = str(stack_count)
			stack_label.visible = true
		else:
			stack_label.text = ""
			stack_label.visible = false


func set_highlight(enabled: bool, _color: Color = Color(0.5, 1.0, 0.5, 0.3)) -> void:
	"""Highlight slot (for valid drop targets)"""
	if enabled:
		modulate = Color(1.2, 1.2, 1.2, 1.0) # Slightly brighter
	else:
		modulate = Color.WHITE
