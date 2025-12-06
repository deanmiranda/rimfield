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
	
	# Set empty texture if provided
	if empty_texture:
		texture_normal = empty_texture
	
	# Create stack count label
	_create_stack_label()
	
	# Ensure child nodes don't block mouse events
	call_deferred("_fix_children_mouse_filter")
	
	# Update visual to reflect initial item state
	update_visual()


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
		
		# We're receiving a drop - but first check if mouse is over HUD slot
		# If so, don't handle it here - let HUD slot handle it
		var viewport = get_viewport()
		if viewport and container_ref:
			var container_type = ""
			if "container_type" in container_ref:
				container_type = container_ref.container_type
			if container_type == "chest" or container_type == "fridge" or container_type == "container":
				var mouse_pos = viewport.get_mouse_position()
				if _is_mouse_over_hud_slot(mouse_pos):
					print("[SlotBase] Mouse over HUD slot - not handling drop here")
					# Don't consume event - let HUD slot handle it
					return
		
		# We're receiving a drop - handle it and STOP processing
		_handle_drop()
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
		
		# Drop single item - handle it and STOP processing
		print("[SlotBase] Right-click drop on slot %d" % slot_index)
		_handle_drop()
		accept_event() # Consume the event
		get_viewport().set_input_as_handled()
		return # CRITICAL: Don't start a new drag!


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
	
	# CRITICAL: Store original slot data BEFORE modifying anything
	# This allows us to restore on cancel
	if container_ref.has_method("get_slot_data"):
		original_slot_data = container_ref.get_slot_data(slot_index).duplicate(true)
	else:
		original_slot_data = {"texture": item_texture, "count": stack_count, "weight": 0.0}
	
	print("[SlotBase] Starting drag from slot %d: %s x%d right_click=%s" % [
		slot_index,
		item_texture.resource_path if item_texture else "null",
		stack_count,
		is_right_click
	])
	
	# Final safety check (should never trigger due to check above)
	if DragManager:
		DragManager.start_drag(container_ref, slot_index, item_texture, stack_count, is_right_click)
		
		# Update visual: make slot semi-transparent to show item is being dragged
		modulate = Color(1, 1, 1, 0.3)
		
		# CRITICAL: Only update VISUAL, NOT data!
		# The container will update data when drop is successful
		# This prevents data loss if drag is canceled
		if is_right_click:
			# Right-click: show reduced count visually only
			var remaining = stack_count - 1
			if remaining > 0:
				# Update visual only (not data)
				set_item(item_texture, remaining)
		else:
			# Left-click: show empty visually (full stack being dragged)
			set_item(null, 0)


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
	
	print("[SlotBase] Handling drop on slot %d" % slot_index)
	
	if not container_ref:
		print("[SlotBase] ERROR: No container_ref for drop on slot %d" % slot_index)
		return
	
	# Restore modulate before handling drop (container will update slot data)
	modulate = Color.WHITE
	
	# Clear stored original data (drop is successful, no need to restore)
	original_slot_data.clear()
	
	# Let container handle the drop logic
	if container_ref.has_method("handle_drop_on_slot"):
		container_ref.handle_drop_on_slot(slot_index)
	else:
		print("[SlotBase] ERROR: Container %s doesn't have handle_drop_on_slot method" % container_ref.name)


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
	"""Restore slot visual and data after drag is canceled"""
	modulate = Color.WHITE
	
	# CRITICAL: Restore from original_slot_data (stored before drag started)
	# NOT from current container data (which may have been modified)
	if original_slot_data.size() > 0:
		# Restore container data
		if container_ref:
			container_ref.inventory_data[slot_index] = original_slot_data.duplicate(true)
			# Sync UI to ensure visual matches data
			if container_ref.has_method("sync_slot_ui"):
				container_ref.sync_slot_ui(slot_index)
			else:
				# Fallback: restore visual directly
				set_item(original_slot_data["texture"], original_slot_data["count"])
		
		# Clear stored data
		original_slot_data.clear()
	else:
		# Fallback: try to restore from container
		if container_ref and container_ref.has_method("get_slot_data"):
			var slot_data = container_ref.get_slot_data(slot_index)
			set_item(slot_data["texture"], slot_data["count"])


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
