extends TextureButton

@export var slot_index: int = 0
@export var empty_texture: Texture

#@export var tool_name: String = ""  # Logical name for the tool
#@export var can_farm: bool = false  # Can this tool be used for farming?

signal tool_selected(slot_index: int, item_texture: Texture) # Signal emitted when the tool is selected
signal slot_drag_started(slot_index: int, item_texture: Texture) # Signal emitted when drag starts

var item_texture: Texture = null
var stack_count: int = 0 # Stack count (0 = empty, max 9 for toolbelt)
var default_modulate: Color = Color.WHITE
var is_highlighted: bool = false

# Manual drag and drop state
var is_dragging: bool = false
var _is_right_click_drag: bool = false # Track if this is a right-click drag (vs left-click drag)
var drag_preview: TextureRect = null
var drag_preview_label: Label = null # Label to show drag count
var original_texture: Texture = null # Store original texture to restore if drop fails
var original_stack_count: int = 0 # Store original stack count to restore if drop fails
var drag_count: int = 0 # Number of items being dragged (accumulates on repeated right-clicks)

const BUTTON_LEFT = 1
const BUTTON_RIGHT = 2
const MAX_TOOLBELT_STACK = 9


func _ready() -> void:
	# Sync item_texture with child TextureRect (Hud_slot_X)
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		if hud_slot_rect.texture:
			item_texture = hud_slot_rect.texture
		else:
			item_texture = null
	
	# Initialize the TextureButton with empty texture only (background)
	# The actual item texture is in the child TextureRect
	texture_normal = empty_texture

	# Ensure the node receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store default modulate
	default_modulate = modulate
	
	# Make sure child TextureRect doesn't block mouse events - CRITICAL for drag and drop
	# MOUSE_FILTER_IGNORE ensures clicks pass through to the parent TextureButton
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_slot_rect.focus_mode = Control.FOCUS_NONE
	
	# Don't connect pressed signal - it interferes with drag operations
	# Tool selection will be handled by clicking empty slots or via keyboard shortcuts

	# Create stack count label
	_create_stack_label()
	
	# Start with process disabled (enable when dragging to keep ghost icon visible globally)
	set_process(false)


func get_item() -> Texture:
	"""Get the item texture from child TextureRect"""
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		return hud_slot_rect.texture
	return item_texture


func set_item(new_texture: Texture, count: int = 1) -> void:
	print("DEBUG set_item: slot_index=", slot_index, " new_texture=", new_texture, " count=", count, " current_stack_count=", stack_count, " is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag)
	
	# CRITICAL: If setting to null while dragging, log the call stack to see who's calling
	if new_texture == null and is_dragging:
		print("DEBUG set_item: WARNING - Setting slot ", slot_index, " to null while dragging!")
		print("DEBUG set_item: Call stack:")
		var stack = get_stack()
		for i in range(mini(stack.size(), 5)): # Show first 5 stack frames
			print("  [", i, "] ", stack[i])
	
	item_texture = new_texture

	# Update stack count
	if new_texture:
		# CRITICAL: Allow count=0 during drag operations (visual only)
		# When count=0, it means we're dragging the entire stack
		stack_count = maxi(count, 0) # Allow 0 for drag operations
	else:
		stack_count = 0 # No item = no stack
	
	print("DEBUG set_item: After update - stack_count=", stack_count)
	
	# TextureButton always shows empty_texture as background
	# Only update child TextureRect (Hud_slot_X) with the item texture
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.texture = item_texture
		print("DEBUG set_item: Updated TextureRect texture to ", item_texture)
		# Ensure child doesn't block mouse events - CRITICAL for drag and drop
		hud_slot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Also ensure it doesn't block input by making it non-interactive
		hud_slot_rect.focus_mode = Control.FOCUS_NONE
	else:
		print("DEBUG set_item: WARNING - hud_slot_rect not found for slot_index ", slot_index)

	_update_stack_label()
	print("DEBUG set_item: Final state - item_texture=", item_texture, " stack_count=", stack_count)


func get_drag_data(_position: Vector2) -> Variant:
	"""Prepare for drag operation using Godot's built-in drag system"""

	# Sync item_texture with child TextureRect
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		if hud_slot_rect.texture:
			item_texture = hud_slot_rect.texture
		else:
			item_texture = null

	if item_texture == null:
		return null # No item to drag

	var drag_data = {
		"slot_index": slot_index,
		"item_texture": item_texture,
		"stack_count": stack_count,
		"source": "toolkit", # Standardized source identifier
		"source_node": self # Reference to source slot for swapping
	}

	# Create drag preview
	var drag_preview = TextureRect.new()
	drag_preview.texture = item_texture
	drag_preview.custom_minimum_size = Vector2(64, 64)
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.modulate = Color(1, 1, 1, 0.7) # Semi-transparent
	set_drag_preview(drag_preview)

	emit_signal("slot_drag_started", slot_index, item_texture)
	return drag_data


func _gui_input(event: InputEvent) -> void:
	"""Handle manual drag and drop for toolkit slots"""
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				# If already dragging from right-click, drop the item
				if is_dragging:
					# Mark input as handled to prevent tool actions
					get_viewport().set_input_as_handled()
					_stop_drag()
					return
				else:
					# FIRST: Check if another slot is dragging (inventory or toolkit)
					# If so, try to receive the drop instead of starting a new drag
					var dragging_slot = _find_dragging_slot()
					if dragging_slot and dragging_slot != self:
						# Another slot is dragging - try to receive the drop
						var viewport = get_viewport()
						if viewport:
							var mouse_pos = viewport.get_mouse_position()
							var slot_rect = get_global_rect()
							if slot_rect.has_point(mouse_pos):
								# Mouse is over this slot - receive the drop
								if dragging_slot.has_method("_get_drag_data_for_drop"):
									var drag_data = dragging_slot._get_drag_data_for_drop()
									if drag_data and can_drop_data(mouse_pos, drag_data):
										drop_data(mouse_pos, drag_data)
										return
					
					# No active drag from another slot - start drag with entire stack
					_start_drag()
			elif not event.pressed:
				# Left-click release: only stop drag if it was a left-click drag (not right-click)
				if is_dragging and not _is_right_click_drag:
					_stop_drag()
				elif not is_dragging:
					# Click without drag - select this slot (even if empty)
					_select_slot()
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				# Right-click: Instantly take one item from stack (no hold needed)
				# The ghost icon will follow cursor, then left-click drops it
				_start_right_click_drag()
	elif event is InputEventMouseMotion and is_dragging:
		# Update drag preview position (will cancel if mouse goes off screen)
		_update_drag_preview_position()
	
	# Enable process when right-click drag starts (to keep ghost visible globally)
	if is_dragging and _is_right_click_drag:
		set_process(true)


func _start_drag() -> void:
	"""Start manual drag operation with entire stack (left-click drag)"""
	# Sync item_texture with child TextureRect
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		if hud_slot_rect.texture:
			item_texture = hud_slot_rect.texture
		else:
			item_texture = null
	
	if item_texture == null:
		return # No item to drag
	
	is_dragging = true
	_is_right_click_drag = false # This is a left-click drag
	original_texture = item_texture
	original_stack_count = stack_count # Store the stack count
	drag_count = stack_count # Drag entire stack
	
	# Create ghost icon that follows cursor
	drag_preview = _create_drag_preview(item_texture, drag_count)
	
	# Hide the item in the slot while dragging
	var hud_slot_rect_node = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect_node and hud_slot_rect_node is TextureRect:
		hud_slot_rect_node.modulate = Color(1, 1, 1, 0.3) # Make slot semi-transparent

	# Update slot to show reduced count (0 while dragging entire stack)
	set_item(item_texture, 0)

	# Enable process to keep ghost icon visible globally
	set_process(true)
	
	emit_signal("slot_drag_started", slot_index, item_texture)


func _start_right_click_drag() -> void:
	"""Start or accumulate right-click drag (instantly takes one item, no hold needed)"""
	# Sync item_texture with child TextureRect
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		if hud_slot_rect.texture:
			item_texture = hud_slot_rect.texture
		else:
			item_texture = null

	if item_texture == null or stack_count <= 0:
		return # No item to drag

	# If already dragging the same item from THIS slot, add one more to the drag count
	if is_dragging and _is_right_click_drag and original_texture == item_texture:
		# CRITICAL: Can't drag more than the original stack count (prevent creating items)
		if drag_count >= original_stack_count:
			print("DEBUG: Cannot accumulate more - already at max (", original_stack_count, ")")
			return # Already dragging the full stack
		
		# Accumulate one more item
		drag_count += 1
		print("DEBUG: Accumulating right-click drag - now dragging ", drag_count, " items")
		
		# Update the displayed count to reflect the new drag
		var new_remaining = original_stack_count - drag_count
		
		# CRITICAL: Update InventoryManager FIRST before UI to prevent sync issues
		if InventoryManager:
			if new_remaining > 0:
				InventoryManager.add_item_to_toolkit(slot_index, item_texture, new_remaining)
			else:
				InventoryManager.remove_item_from_toolkit(slot_index)
		
		# Then update UI
		set_item(item_texture, new_remaining)
		
		# Update or create drag preview count label
		if drag_count > 1:
			if not drag_preview_label:
				# Create label if it doesn't exist
				drag_preview_label = Label.new()
				drag_preview_label.add_theme_font_size_override("font_size", 12)
				drag_preview_label.add_theme_color_override("font_color", Color.WHITE)
				drag_preview_label.add_theme_color_override("font_outline_color", Color.BLACK)
				drag_preview_label.add_theme_constant_override("outline_size", 2)
				drag_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				drag_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				drag_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				drag_preview_label.position = Vector2(0, 20)
				drag_preview_label.size = Vector2(32, 12)
				if drag_preview:
					drag_preview.add_child(drag_preview_label)
			drag_preview_label.text = str(drag_count)
			drag_preview_label.visible = true
		return

	# Start new right-click drag with 1 item (instantly, no hold needed)
	is_dragging = true
	_is_right_click_drag = true # Mark this as a right-click drag
	original_texture = item_texture
	original_stack_count = stack_count # Store the original stack count BEFORE reducing
	drag_count = 1 # Start with 1 item
	
	print("DEBUG: Starting right-click drag - original_stack_count=", original_stack_count, " drag_count=", drag_count)

	# Create ghost icon that follows cursor (no label for single item)
	drag_preview = _create_drag_preview(item_texture, 1)

	# Update slot to show reduced count (stack_count - 1)
	# IMPORTANT: Update the visual display but keep original_stack_count for later restoration
	var remaining = original_stack_count - drag_count
	
	# CRITICAL: Update InventoryManager FIRST before UI to prevent sync issues
	# This ensures InventoryManager knows the slot has (original - 1) items during drag
	print("DEBUG _start_right_click_drag: About to update InventoryManager - remaining=", remaining)
	if InventoryManager:
		if remaining > 0:
			print("DEBUG _start_right_click_drag: Calling InventoryManager.add_item_to_toolkit(", slot_index, ", item_texture, ", remaining, ")")
			InventoryManager.add_item_to_toolkit(slot_index, item_texture, remaining)
		else:
			print("DEBUG _start_right_click_drag: Calling InventoryManager.remove_item_from_toolkit(", slot_index, ")")
			InventoryManager.remove_item_from_toolkit(slot_index)
	else:
		print("DEBUG _start_right_click_drag: WARNING - InventoryManager is null!")
	
	# Then update UI
	print("DEBUG _start_right_click_drag: About to call set_item(", item_texture, ", ", remaining, ")")
	set_item(item_texture, remaining)
	print("DEBUG _start_right_click_drag: After set_item - slot should show ", remaining, " items")
	# CRITICAL: After updating the slot, original_stack_count is still the original value
	# This will be used by _receive_drop() to correctly restore the source slot

	# Make slot semi-transparent while dragging
	var hud_slot_rect_node = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect_node and hud_slot_rect_node is TextureRect:
		hud_slot_rect_node.modulate = Color(1, 1, 1, 0.3)

	# Enable process to keep ghost icon visible globally (even when mouse leaves toolkit area)
	set_process(true)

	emit_signal("slot_drag_started", slot_index, item_texture)


func _stop_drag() -> void:
	"""Stop drag and handle drop"""
	if not is_dragging:
		return
	
	# Get mouse position in viewport coordinates
	var viewport = get_viewport()
	if not viewport:
		# No viewport - cancel drag and restore
		_cancel_drag()
		return

	# Check if mouse is within viewport bounds (prevent off-screen drag issues)
	var mouse_pos = viewport.get_mouse_position()
	var viewport_size = viewport.get_visible_rect().size
	if mouse_pos.x < 0 or mouse_pos.x > viewport_size.x or mouse_pos.y < 0 or mouse_pos.y > viewport_size.y:
		# Mouse is off screen - cancel drag and restore
		_cancel_drag()
		return

	# DEBUG: Log drag state
	print("DEBUG _stop_drag: is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag, " drag_count=", drag_count, " original_stack_count=", original_stack_count)
	
	# FIRST: Check if clicking on UI (toolkit or inventory slots)
	var drop_success = _handle_drop(mouse_pos)
	print("DEBUG _stop_drag: _handle_drop returned ", drop_success)
	
	# If drop didn't succeed on UI, check if clicking on world (throw-to-world)
	if not drop_success:
		# Check if mouse is over any UI Control node
		var is_over_ui = _is_mouse_over_ui(mouse_pos)
		print("DEBUG _stop_drag: is_over_ui=", is_over_ui)
		if not is_over_ui:
			# Not over UI - throw to world
			# Mark input as handled BEFORE throwing to prevent tool actions
			get_viewport().set_input_as_handled()
			print("DEBUG _stop_drag: Throwing to world")
			_throw_to_world(mouse_pos)
			drop_success = true # Mark as successful to prevent cancel
		else:
			print("DEBUG _stop_drag: Mouse is over UI, not throwing to world")

	# CRITICAL: Clean up drag preview FIRST, before any state changes
	# This ensures the ghost icon is always removed, even if there's an error
	_cleanup_drag_preview()

	# Restore slot visibility
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.modulate = Color.WHITE

	# CRITICAL: Only restore if drop failed AND we haven't already been cleaned up
	# If _receive_drop() called _stop_drag_cleanup(), is_dragging will already be false
	# If drop succeeded, _receive_drop() or _throw_to_world() already updated the slot correctly
	if not drop_success and is_dragging:
		# Drop failed - restore everything to original state
		set_item(original_texture, original_stack_count)
	# NOTE: If drop succeeded:
	# - For left-click drags: _receive_drop() swapped items (source gets destination's old item)
	# - For right-click drags: _receive_drop() updated source to show (original - dragged) items
	# - For throw-to-world: _throw_to_world() updated source to show remaining items
	# So we don't need to do anything here - just clean up drag state

	# CRITICAL: Only clear drag state if we haven't already been cleaned up
	# _receive_drop() may have called _stop_drag_cleanup() which already cleared this
	if is_dragging:
		is_dragging = false
		_is_right_click_drag = false
		original_texture = null
		original_stack_count = 0
		drag_count = 0
		set_process(false) # Stop processing when drag ends
	
	# NOTE: ToolSwitcher notifications are handled by _receive_drop() and _throw_to_world()
	# We don't notify here because the visual state of this slot may not reflect the final state
	# (e.g., it was cleared during drag, but _receive_drop() may have updated it correctly)


func _stop_drag_cleanup() -> void:
	"""Clean up drag state without handling drop - called by destination slot after successful drop"""
	print("DEBUG _stop_drag_cleanup: Called on slot ", slot_index, " - cleaning up drag state")
	
	# Clean up drag preview and its parent layer
	_cleanup_drag_preview()
	
	# Restore slot visibility
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.modulate = Color.WHITE
	
	# Clear drag state
	print("DEBUG _stop_drag_cleanup: Clearing drag state - is_dragging was ", is_dragging, " _is_right_click_drag was ", _is_right_click_drag)
	is_dragging = false
	_is_right_click_drag = false
	original_texture = null
	original_stack_count = 0
	drag_count = 0
	set_process(false) # Stop processing when drag ends
	print("DEBUG _stop_drag_cleanup: Drag state cleared - is_dragging=", is_dragging)


func _cancel_drag() -> void:
	"""Cancel drag operation and restore items to original slot"""
	if not is_dragging:
		return
	
	# Clean up drag preview
	_cleanup_drag_preview()
	
	# Restore slot visibility
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.modulate = Color.WHITE
	
	# Restore original texture and count
	set_item(original_texture, original_stack_count)
	
	is_dragging = false
	_is_right_click_drag = false
	original_texture = null
	original_stack_count = 0
	drag_count = 0
	set_process(false) # Stop processing when drag ends


func _cleanup_drag_preview() -> void:
	"""Clean up drag preview and ensure no ghost icons remain"""
	if drag_preview:
		# Find and remove the DragPreviewLayer
		var drag_layer = drag_preview.get_parent()
		if drag_layer and drag_layer.name == "DragPreviewLayer":
			# Remove all children first to prevent orphaned nodes
			for child in drag_layer.get_children():
				child.queue_free()
			drag_layer.queue_free() # This will also free the preview
		else:
			# If preview is directly in scene tree, remove it
			if drag_preview.get_parent():
				drag_preview.get_parent().remove_child(drag_preview)
			drag_preview.queue_free()
		drag_preview = null
		drag_preview_label = null

	# Also check for any orphaned DragPreviewLayer nodes in the scene tree
	var root = get_tree().root
	if root:
		_remove_orphaned_drag_layers(root)


func _remove_orphaned_drag_layers(node: Node) -> void:
	"""Recursively remove any orphaned DragPreviewLayer nodes"""
	if node.name == "DragPreviewLayer":
		# Found an orphaned drag layer - remove it
		for child in node.get_children():
			child.queue_free()
		node.queue_free()
		return

	# Recursively check children
	for child in node.get_children():
		_remove_orphaned_drag_layers(child)


func _create_drag_preview(texture: Texture, count: int = 1) -> TextureRect:
	"""Create ghost icon that follows cursor - 50% smaller than original"""
	var preview = TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(32, 32) # 50% smaller (was 64x64)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.7) # Semi-transparent ghost
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create a dedicated CanvasLayer on top of everything for the drag preview
	# This ensures it's always visible, even over the pause menu
	var drag_layer = CanvasLayer.new()
	drag_layer.name = "DragPreviewLayer"
	drag_layer.layer = 100 # Very high layer to be above everything
	get_tree().root.add_child(drag_layer)

	# Add preview to the dedicated layer
	drag_layer.add_child(preview)
	preview.z_index = 1000
	preview.z_as_relative = false

	# Add count label if dragging more than 1 item
	if count > 1:
		drag_preview_label = Label.new()
		drag_preview_label.text = str(count)
		drag_preview_label.add_theme_font_size_override("font_size", 12)
		drag_preview_label.add_theme_color_override("font_color", Color.WHITE)
		drag_preview_label.add_theme_color_override("font_outline_color", Color.BLACK)
		drag_preview_label.add_theme_constant_override("outline_size", 2)
		drag_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drag_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		drag_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drag_preview_label.position = Vector2(0, 20) # Position at bottom of preview
		drag_preview_label.size = Vector2(32, 12)
		preview.add_child(drag_preview_label)

	var viewport = get_viewport()
	if viewport:
		var mouse_pos = viewport.get_mouse_position()
		preview.global_position = mouse_pos - Vector2(16, 16) # Center on cursor (half of 32)
	
	return preview


func _process(_delta: float) -> void:
	"""Update drag preview position when dragging (especially for right-click drags that need global tracking)"""
	if is_dragging and drag_preview:
		_update_drag_preview_position()
	else:
		# Stop processing when not dragging
		set_process(false)


func _update_drag_preview_position() -> void:
	"""Update ghost icon position to follow cursor"""
	if drag_preview:
		var viewport = get_viewport()
		if viewport:
			# Use viewport mouse position for UI elements (screen space, not world space)
			var mouse_pos = viewport.get_mouse_position()
			var viewport_size = viewport.get_visible_rect().size
			
			# Check if mouse is within viewport bounds
			if mouse_pos.x < 0 or mouse_pos.x > viewport_size.x or mouse_pos.y < 0 or mouse_pos.y > viewport_size.y:
				# Mouse went off screen - cancel drag
				_cancel_drag()
				return
			
			drag_preview.global_position = mouse_pos - Vector2(16, 16) # Center on cursor (half of 32)


func _update_drag_preview_count(new_count: int) -> void:
	"""Update the count label on the drag preview"""
	if drag_preview:
		if new_count > 1:
			if drag_preview_label:
				drag_preview_label.text = str(new_count)
			else:
				# Create label if it doesn't exist
				drag_preview_label = Label.new()
				drag_preview_label.text = str(new_count)
				drag_preview_label.add_theme_font_size_override("font_size", 12)
				drag_preview_label.add_theme_color_override("font_color", Color.WHITE)
				drag_preview_label.add_theme_color_override("font_outline_color", Color.BLACK)
				drag_preview_label.add_theme_constant_override("outline_size", 2)
				drag_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				drag_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				drag_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				drag_preview_label.position = Vector2(0, 20)
				drag_preview_label.size = Vector2(32, 12)
				drag_preview.add_child(drag_preview_label)
		else:
			# Remove label if count is 1 or less
			if drag_preview_label:
				drag_preview_label.queue_free()
				drag_preview_label = null


func _handle_drop(drop_position: Vector2) -> bool:
	"""Handle drop at position - toolkit-to-toolkit or toolkit-to-inventory"""
	print("DEBUG _handle_drop: Called with drop_position=", drop_position, " is_dragging=", is_dragging, " drag_count=", drag_count)
	
	# Get mouse position in viewport/screen coordinates (UI space, not world space)
	# UI elements use viewport coordinates, not world coordinates
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position() if viewport else drop_position
	print("DEBUG _handle_drop: mouse_pos=", mouse_pos)
	
	# PRIORITY 1: Check toolkit slots first (same parent container)
	var parent_container = get_parent()
	if parent_container and parent_container is HBoxContainer:
		# Check each toolkit slot in the same container
		for i in range(parent_container.get_child_count()):
			var texture_button = parent_container.get_child(i)
			if texture_button and texture_button is TextureButton:
				# Get the button's global rect (screen/viewport coordinates for UI elements)
				# get_global_rect() returns screen coordinates for UI elements in CanvasLayer
				var button_rect = texture_button.get_global_rect()
				
				# Check if mouse is over this button
				# Both should be in viewport/screen coordinates
				if button_rect.has_point(mouse_pos):
					print("DEBUG _handle_drop: Mouse over toolkit slot ", i, " (self=", self, " texture_button=", texture_button, ")")
					# Check if dropping on same slot
					if texture_button == self:
						# For both right-click and left-click drags, restore the item when dropping on same slot
						if _is_right_click_drag:
							print("DEBUG _handle_drop: Right-click drag on same slot - restoring item")
							# Restore the item by calling _receive_drop on self
							# CRITICAL: This will restore the original stack count
							if has_method("_receive_drop"):
								var success = _receive_drop(original_texture, drag_count, slot_index, self, "toolkit")
								# CRITICAL: After _receive_drop() updates the slot, we need to ensure
								# the drag state is cleaned up, but NOT by calling _stop_drag_cleanup()
								# because that would clear original_stack_count before _stop_drag() finishes
								# Instead, just return success and let _stop_drag() handle cleanup
								return success
						else:
							# Left-click drag on same slot - restore the full original stack
							print("DEBUG _handle_drop: Left-click drag on same slot - restoring full stack")
							# CRITICAL: Restore the original stack count for left-click drags
							if has_method("_receive_drop"):
								var success = _receive_drop(original_texture, original_stack_count, slot_index, self, "toolkit")
								# Let _stop_drag() handle cleanup
								return success
							else:
								# Fallback: directly restore the stack
								set_item(original_texture, original_stack_count)
								if InventoryManager:
									if original_texture:
										InventoryManager.add_item_to_toolkit(slot_index, original_texture, original_stack_count)
									else:
										InventoryManager.remove_item_from_toolkit(slot_index)
								return true
					
					# Found a different toolkit slot - swap items
					if texture_button.has_method("_receive_drop"):
						var success = texture_button._receive_drop(
							original_texture, drag_count, slot_index, self, "toolkit"
						)
						# ToolSwitcher is notified in _receive_drop
						return success
					else:
						# Fallback: directly swap items
						var target_slot_rect = texture_button.get_node_or_null("Hud_slot_" + str(i))
						var target_texture: Texture = null
						if target_slot_rect and target_slot_rect is TextureRect:
							target_texture = target_slot_rect.texture

						# Swap items
						set_item(target_texture)
						if texture_button.has_method("set_item"):
							texture_button.set_item(original_texture)
	
						# Notify ToolSwitcher about the swap
						var tool_switcher = _find_tool_switcher()
						if tool_switcher:
							tool_switcher.update_toolkit_slot(slot_index, target_texture)
							tool_switcher.update_toolkit_slot(i, original_texture)

						return true

	# PRIORITY 2: Check inventory slots in pause menu
	var pause_menu = _find_pause_menu()
	if pause_menu:
		# Get the inventory grid from the pause menu
		var inventory_grid = (
			pause_menu
			.get_node_or_null(
				"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
			)
		)
		if inventory_grid:
			# Check each inventory slot
			for i in range(inventory_grid.get_child_count()):
				var inventory_slot = inventory_grid.get_child(i)
				if inventory_slot and inventory_slot is TextureButton:
					var slot_rect = inventory_slot.get_global_rect()
					
					# Check if mouse is over this inventory slot
					if slot_rect.has_point(mouse_pos):
						print("DEBUG _handle_drop: Mouse over inventory slot ", i)
						# Create drag data in the format expected by inventory slots
						var drag_data = {
							"slot_index": slot_index,
							"item_texture": original_texture,
							"stack_count": drag_count, # Use drag_count, not stack_count
							"source": "toolkit",
							"source_node": self,
							"is_right_click_drag": _is_right_click_drag, # CRITICAL: Include right-click drag flag
							"original_stack_count": original_stack_count # CRITICAL: Include original stack count for right-click drags
						}
						print("DEBUG _handle_drop: drag_data=", drag_data)

						# Check if the inventory slot can accept this drop
						if inventory_slot.has_method("can_drop_data"):
							var can_drop = inventory_slot.can_drop_data(mouse_pos, drag_data)
							print("DEBUG _handle_drop: inventory slot can_drop=", can_drop)
							if can_drop and inventory_slot.has_method("drop_data"):
								# Perform the drop
								print("DEBUG _handle_drop: Calling inventory_slot.drop_data()")
								inventory_slot.drop_data(mouse_pos, drag_data)
								return true
							else:
								print("DEBUG _handle_drop: Cannot drop - can_drop=", can_drop, " has_method=", inventory_slot.has_method("drop_data"))
						else:
							print("DEBUG _handle_drop: Inventory slot doesn't have can_drop_data method")
	
	return false


func _is_mouse_over_ui(mouse_pos: Vector2) -> bool:
	"""Check if mouse is over any UI Control node (toolkit or inventory)"""
	# Check toolkit slots
	var parent_container = get_parent()
	if parent_container and parent_container is HBoxContainer:
		for i in range(parent_container.get_child_count()):
			var slot = parent_container.get_child(i)
			if slot and slot is TextureButton:
				var slot_rect = slot.get_global_rect()
				if slot_rect.has_point(mouse_pos):
					return true
	
	# Check inventory slots
	var pause_menu = _find_pause_menu()
	if pause_menu and pause_menu.visible:
		var inventory_grid = pause_menu.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
		)
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot and slot is TextureButton:
					var slot_rect = slot.get_global_rect()
					if slot_rect.has_point(mouse_pos):
						return true
	
	return false


func _throw_to_world(mouse_pos: Vector2) -> void:
	"""Throw dragged item(s) to world position with physics/bounce"""
	if not is_dragging or not original_texture:
		return
	
	# Get player position - items should scatter around the player, not at mouse position
	# CRITICAL: Player structure is: Player (Node2D parent) -> Player (CharacterBody2D child that actually moves)
	var player_parent = get_tree().get_first_node_in_group("player")
	if not player_parent:
		player_parent = get_tree().current_scene.get_node_or_null("Player")
	
	if not player_parent:
		_cancel_drag()
		return
	
	# Get the actual CharacterBody2D child that moves (this is where the real position is)
	var player: CharacterBody2D = null
	var player_pos: Vector2
	if player_parent is Node2D:
		# Try to find the CharacterBody2D child
		for child in player_parent.get_children():
			if child is CharacterBody2D:
				player = child
				break
	
	# Get the current position from the CharacterBody2D (this is what actually moves)
	if player:
		# Use the CharacterBody2D's current position (this is what actually moves)
		player_pos = player.global_position
	elif player_parent is Node2D:
		# Fallback: if we couldn't find CharacterBody2D, use the parent's position
		player_pos = player_parent.global_position
	else:
		_cancel_drag()
		return
	
	# Get HUD instance for droppable
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		# Try alternative path
		hud = get_tree().current_scene.get_node_or_null("Hud")
	if not hud:
		_cancel_drag()
		return
	
	# Drop items in front of the player (small scatter, not far away)
	var item_count = drag_count
	var base_distance = 32.0 # Base distance in front of player (2 tiles)
	var scatter_radius = 16.0 # Small scatter radius (1 tile) so items don't stack exactly
	
	# Get player facing direction (use movement direction or default to down)
	# CRITICAL: Use the CharacterBody2D for direction if we found it, otherwise use parent
	var player_for_direction = player if player else player_parent
	var player_direction = Vector2.DOWN
	if player_for_direction and "direction" in player_for_direction and player_for_direction.direction.length() > 0:
		player_direction = player_for_direction.direction.normalized()
	elif player_for_direction and "input_direction" in player_for_direction and player_for_direction.input_direction.length() > 0:
		player_direction = player_for_direction.input_direction.normalized()
	
	# For top-down, "in front" is the direction the player is facing
	var forward_direction = player_direction
	
	for i in range(item_count):
		# Small random scatter around the drop position
		var scatter_angle = randf() * TAU
		var scatter_distance = randf() * scatter_radius
		var scatter_offset = Vector2(cos(scatter_angle), sin(scatter_angle)) * scatter_distance
		
		# Drop position: in front of player with small scatter
		var spawn_pos = player_pos + forward_direction * base_distance + scatter_offset
		
		# Small random velocity for bounce effect
		var random_velocity = scatter_offset.normalized() * (5.0 + randf() * 10.0)
		
		# Spawn droppable
		if DroppableFactory:
			DroppableFactory.spawn_droppable_from_texture(original_texture, spawn_pos, hud, random_velocity)
	
	# Store values before cleanup
	var items_thrown = drag_count
	var was_all_items = (items_thrown >= original_stack_count)
	
	# Remove items from toolkit
	if InventoryManager:
		if was_all_items:
			# All items thrown - clear slot
			InventoryManager.remove_item_from_toolkit(slot_index)
		else:
			# Partial stack thrown - update count
			var remaining = original_stack_count - items_thrown
			InventoryManager.add_item_to_toolkit(slot_index, original_texture, remaining)
	
	# Clean up drag
	is_dragging = false
	_is_right_click_drag = false
	set_process(false)
	_cleanup_drag_preview()
	
	# Restore slot visibility
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.modulate = Color.WHITE
		# Clear slot if all items thrown, otherwise update count
		if was_all_items:
			set_item(null, 0)
		else:
			var remaining = original_stack_count - items_thrown
			set_item(original_texture, remaining)
	
	# Reset drag state
	original_texture = null
	original_stack_count = 0
	drag_count = 0


func _find_pause_menu() -> Node:
	"""Find the pause menu in the scene tree"""
	# Try to find via UiManager singleton first
	if UiManager:
		# Check if UiManager has a pause_menu property using 'get' with a default value
		var pause_menu_ref = UiManager.get("pause_menu") if "pause_menu" in UiManager else null
		if pause_menu_ref:
			return pause_menu_ref
	
	# Search the entire scene tree for pause menu
	# Look for a Control node with _setup_inventory_slots method (unique to pause_menu.gd)
	var root = get_tree().root
	return _search_for_pause_menu(root)


func _search_for_pause_menu(node: Node) -> Node:
	"""Recursively search for pause menu node"""
	# Check if this node is the pause menu (has the characteristic method)
	if node is Control and node.has_method("_setup_inventory_slots"):
		return node

	# Recursively check children
	for child in node.get_children():
		var result = _search_for_pause_menu(child)
		if result:
			return result

	return null


func _find_dragging_slot() -> Node:
	"""Find any slot (toolkit or inventory) that is currently dragging"""
	# Check toolkit slots first
	var parent_container = get_parent()
	if parent_container and parent_container is HBoxContainer:
		for i in range(parent_container.get_child_count()):
			var slot = parent_container.get_child(i)
			if slot and slot is TextureButton and slot != self:
				# Check if slot has is_dragging variable (not method)
				if "is_dragging" in slot and slot.is_dragging:
					return slot
	
	# Check inventory slots
	var pause_menu = _find_pause_menu()
	if pause_menu:
		var inventory_grid = pause_menu.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
		)
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot and slot is TextureButton and "is_dragging" in slot:
					if slot.is_dragging:
						return slot
	
	return null


func _get_drag_data_for_drop() -> Dictionary:
	"""Get drag data for dropping into another slot"""
	if not is_dragging:
		return {}
	
	return {
		"slot_index": slot_index,
		"item_texture": original_texture,
		"stack_count": drag_count,
		"source": "toolkit",
		"source_node": self,
		"is_right_click_drag": _is_right_click_drag, # CRITICAL: Include right-click drag flag
		"original_stack_count": original_stack_count # CRITICAL: Include original stack count for right-click drags
	}


func _find_tool_switcher() -> Node:
	"""Find the ToolSwitcher node in the scene tree"""
	# ToolSwitcher is typically a child of the HUD scene
	# Try to find HUD first, then ToolSwitcher within it
	var hud = get_tree().root.get_node_or_null("HUD")
	if hud:
		var tool_switcher = hud.get_node_or_null("ToolSwitcher")
		if tool_switcher:
			return tool_switcher
		# Also check if HUD has a child scene instance
		for child in hud.get_children():
			if child.has_node("ToolSwitcher"):
				return child.get_node("ToolSwitcher")

	# Try finding in current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		var tool_switcher = current_scene.get_node_or_null("ToolSwitcher")
		if tool_switcher:
			return tool_switcher
		# Check children recursively
		for child in current_scene.get_children():
			if child.has_node("ToolSwitcher"):
				return child.get_node("ToolSwitcher")
	
	return null


func _receive_drop(
	dropped_texture: Texture, dropped_stack_count: int, source_slot_index: int, source_node: Node, source: String = "unknown"
) -> bool:
	"""Receive a drop from another slot - returns true if successful"""
	# DEBUG: Log what we're receiving
	print("DEBUG _receive_drop: slot_index=", slot_index, " dropped_stack_count=", dropped_stack_count, " source_slot_index=", source_slot_index, " source_node=", source_node)
	
	# Get current item and stack count in this slot BEFORE swapping
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	var current_texture: Texture = null
	var current_stack_count: int = stack_count
	if hud_slot_rect and hud_slot_rect is TextureRect:
		current_texture = hud_slot_rect.texture
	
	# Check if source is a right-click drag (partial stack move)
	# IMPORTANT: Check drag state BEFORE _stop_drag() clears it
	var is_right_click_drag = false
	var source_original_stack_count = 0
	print("DEBUG: Checking source_node for right-click drag. source_node=", source_node)
	if source_node:
		# Check drag state variables directly (they're still set when _receive_drop is called)
		print("DEBUG: source_node._is_right_click_drag=", source_node._is_right_click_drag if "_is_right_click_drag" in source_node else "NOT FOUND")
		print("DEBUG: source_node.original_stack_count=", source_node.original_stack_count if "original_stack_count" in source_node else "NOT FOUND")
		print("DEBUG: source_node.drag_count=", source_node.drag_count if "drag_count" in source_node else "NOT FOUND")
		print("DEBUG: source_node.stack_count=", source_node.stack_count if "stack_count" in source_node else "NOT FOUND")
		
		if "_is_right_click_drag" in source_node and source_node._is_right_click_drag:
			is_right_click_drag = true
			print("DEBUG: Detected right-click drag!")
			
			# CRITICAL: Always calculate original_stack_count from current state + drag count
			# This is more reliable than trusting the stored value
			var source_current_count = source_node.stack_count if "stack_count" in source_node else 0
			var source_drag_count = source_node.drag_count if "drag_count" in source_node else dropped_stack_count
			var calculated_original = source_current_count + source_drag_count
			
			# Also read the stored original_stack_count
			var stored_original = 0
			if "original_stack_count" in source_node:
				stored_original = source_node.original_stack_count
			
			# Use the stored value if it's valid, otherwise use calculated
			if stored_original > 0:
				source_original_stack_count = stored_original
				print("DEBUG: Using stored original_stack_count: ", source_original_stack_count)
			else:
				source_original_stack_count = calculated_original
				print("DEBUG: Using calculated original_stack_count: ", source_original_stack_count, " (current=", source_current_count, " + drag=", source_drag_count, ")")
			
			# Defensive check: make sure we got a valid number
			if source_original_stack_count <= 0:
				print("ERROR: source_original_stack_count is invalid (", source_original_stack_count, ") - using dropped_stack_count as fallback")
				source_original_stack_count = dropped_stack_count
		else:
			print("DEBUG: NOT a right-click drag (is_right_click_drag not set or false)")

	# CRITICAL: Handle same-slot drops BEFORE stacking logic to avoid incorrect calculations
	# This must be checked for BOTH left-click and right-click drags
	if source_slot_index == slot_index:
		if is_right_click_drag:
			# Right-click drag: restore original_stack_count (not the reduced current_stack_count)
			# CRITICAL: Ensure source_original_stack_count is set
			if source_original_stack_count <= 0:
				# Emergency fallback calculation
				if source_node:
					var source_current = source_node.stack_count if "stack_count" in source_node else 0
					var source_drag = source_node.drag_count if "drag_count" in source_node else dropped_stack_count
					source_original_stack_count = source_current + source_drag
				# CRITICAL: If calculation still fails, use current_stack_count + dropped_stack_count as last resort
				# This is better than using dropped_stack_count alone (which is just the dragged amount)
				if source_original_stack_count <= 0:
					# Last resort: current_stack_count + dropped_stack_count should give us the original
					# This works because: original = current (reduced) + dragged
					source_original_stack_count = current_stack_count + dropped_stack_count
					print("WARNING: Using fallback calculation for original_stack_count: ", source_original_stack_count, " (current=", current_stack_count, " + dragged=", dropped_stack_count, ")")
			
			print("DEBUG _receive_drop: Same-slot drop for right-click drag - restoring original_stack_count=", source_original_stack_count)
			# CRITICAL: Update InventoryManager FIRST before UI
			if InventoryManager:
				if dropped_texture:
					InventoryManager.add_item_to_toolkit(slot_index, dropped_texture, source_original_stack_count)
				else:
					InventoryManager.remove_item_from_toolkit(slot_index)
			
			# Then update UI with the FULL original stack count
			set_item(dropped_texture, source_original_stack_count)
		else:
			# Left-click drag: restore the full dropped stack
			print("DEBUG _receive_drop: Same-slot drop for left-click drag - restoring full stack")
			# CRITICAL: Update InventoryManager FIRST before UI
			if InventoryManager:
				if dropped_texture:
					InventoryManager.add_item_to_toolkit(slot_index, dropped_texture, dropped_stack_count)
				else:
					InventoryManager.remove_item_from_toolkit(slot_index)
			
			# Then update UI
			set_item(dropped_texture, dropped_stack_count)
		
		# Notify ToolSwitcher
		var tool_switcher = _find_tool_switcher()
		if tool_switcher:
			tool_switcher.update_toolkit_slot(slot_index, dropped_texture)
		
		# Don't call _stop_drag_cleanup() here - let _stop_drag() handle it
		return true

	# Handle stacking if same item
	if current_texture and dropped_texture and current_texture == dropped_texture:
		var space_available = MAX_TOOLBELT_STACK - current_stack_count
		if space_available > 0:
			var amount_to_add = mini(dropped_stack_count, space_available)
			var new_target_count = current_stack_count + amount_to_add
			
			# CRITICAL: Update InventoryManager FIRST before UI
			if InventoryManager:
				InventoryManager.add_item_to_toolkit(slot_index, current_texture, new_target_count)
			
			# Then update this slot UI
			set_item(current_texture, new_target_count)
			
			# Update source slot with remaining items
			var remaining = dropped_stack_count - amount_to_add
			var source_remaining = 0
			if is_right_click_drag:
				# Right-click drag: source should have (original - dragged) items remaining
				# CRITICAL: source_original_stack_count should already be set from the check above
				# but verify it's valid before using it
				if source_original_stack_count <= 0:
					print("ERROR: Stacking branch - source_original_stack_count not set! This should not happen.")
					# Emergency fallback
					if source_node:
						var source_current = source_node.stack_count if "stack_count" in source_node else 0
						var source_drag = source_node.drag_count if "drag_count" in source_node else dropped_stack_count
						source_original_stack_count = source_current + source_drag
						print("DEBUG: Emergency calculation: ", source_original_stack_count)
					if source_original_stack_count <= 0:
						source_original_stack_count = dropped_stack_count
				
				# Calculate remaining
				if source_slot_index == slot_index:
					# Dropping back to same slot - restore original count
					source_remaining = source_original_stack_count
					print("DEBUG: Stacking same slot - restoring full count: ", source_remaining)
				else:
					# Dropping to different slot - source keeps (original - dragged)
					# CRITICAL: Use original_stack_count, not current stack_count (which was already reduced)
					source_remaining = source_original_stack_count - dropped_stack_count
					print("DEBUG: Stacking different slot - remaining: ", source_remaining, " (", source_original_stack_count, " - ", dropped_stack_count, ")")
				
				# CRITICAL: Always update source slot for right-click drags (even if same slot)
				# This MUST happen to preserve the original stack
				# Update InventoryManager FIRST before UI
				if InventoryManager:
					if source == "inventory":
						# Source is inventory - use update_inventory_slots
						if source_remaining > 0:
							InventoryManager.update_inventory_slots(source_slot_index, dropped_texture, source_remaining)
						else:
							InventoryManager.update_inventory_slots(source_slot_index, null, 0)
					else:
						# Source is toolkit - use toolkit methods
						if source_remaining > 0:
							InventoryManager.add_item_to_toolkit(source_slot_index, dropped_texture, source_remaining)
						else:
							InventoryManager.remove_item_from_toolkit(source_slot_index)
				
				# Then update UI
				if source_node and source_node.has_method("set_item"):
					if source_remaining > 0:
						source_node.set_item(dropped_texture, source_remaining)
					else:
						source_node.set_item(null, 0)
			else:
				# Left-click drag: handle remaining items
				# CRITICAL: If there are remaining items, keep them on the cursor instead of putting them back
				# This allows the user to continue dragging the remainder to another slot
				if remaining > 0:
					# Update drag state to continue dragging the remainder
					if "drag_count" in source_node:
						source_node.drag_count = remaining
					if "original_texture" in source_node:
						source_node.original_texture = dropped_texture
					# Update drag preview to show remaining count
					if source_node.has_method("_update_drag_preview_count"):
						source_node._update_drag_preview_count(remaining)
					elif source_node.has_method("_create_drag_preview"):
						# Recreate drag preview with new count
						if "drag_preview" in source_node and source_node.drag_preview:
							source_node._cleanup_drag_preview()
						source_node.drag_preview = source_node._create_drag_preview(dropped_texture, remaining)
					
					# Clear the source slot since all items are being dragged
					if source_node.has_method("set_item"):
						source_node.set_item(null, 0)
					if InventoryManager:
						InventoryManager.remove_item_from_toolkit(source_slot_index)
					
					# Don't call _stop_drag_cleanup() - let the user continue dragging the remainder
					source_remaining = 0 # Source is empty, remainder is on cursor
					print("DEBUG _receive_drop: Partial stack - keeping ", remaining, " items on cursor")
				else:
					# All items fit - handle normally
					source_remaining = remaining
					# Update InventoryManager FIRST before UI
					if InventoryManager:
						if remaining > 0:
							InventoryManager.add_item_to_toolkit(source_slot_index, dropped_texture, remaining)
						else:
							InventoryManager.remove_item_from_toolkit(source_slot_index)
					
					# Then update UI
					if source_node and source_node.has_method("set_item"):
						if remaining > 0:
							source_node.set_item(dropped_texture, remaining)
						else:
							source_node.set_item(null, 0)
			
			# Notify ToolSwitcher
			# CRITICAL: For same-slot drops, DON'T notify ToolSwitcher here
			# because the slot is still in drag state and ToolSwitcher will clear it
			# Instead, let _stop_drag() handle the cleanup after drag state is cleared
			if source_slot_index != slot_index:
				# Different slot - safe to notify ToolSwitcher
				var tool_switcher = _find_tool_switcher()
				if tool_switcher:
					# Destination slot now has the stacked item
					tool_switcher.update_toolkit_slot(slot_index, dropped_texture)
					# Source slot handling
					if is_right_click_drag:
						# Right-click: source keeps its original texture (unless all items were moved)
						# CRITICAL: Skip ToolSwitcher if texture didn't change (it won't update count)
						if source_remaining > 0 and dropped_texture != dropped_texture:
							# This condition is intentionally impossible - same texture always
							# We rely on direct set_item() call above, not ToolSwitcher
							pass
						elif source_remaining <= 0:
							tool_switcher.update_toolkit_slot(source_slot_index, null)
						# else: same texture, already updated via set_item(), skip ToolSwitcher
						print("DEBUG: Right-click stack - skipped ToolSwitcher for source (same texture)")
					else:
						# Left-click: source gets cleared if no items remain
						if source_remaining <= 0:
							tool_switcher.update_toolkit_slot(source_slot_index, null)
						else:
							tool_switcher.update_toolkit_slot(source_slot_index, dropped_texture)
			# For same-slot drops, ToolSwitcher will be notified after _stop_drag() clears drag state
			
			# CRITICAL: For same-slot drops, don't call _stop_drag_cleanup() here
			# because _stop_drag() will handle the cleanup after we return
			# For different-slot drops, we need to clean up the source slot's drag state
			# BUT: If there are remaining items on the cursor (partial stack), don't clean up yet
			if source_slot_index != slot_index and remaining == 0:
				# Different slot and all items were stacked - clean up source slot's drag state
				if source_node and source_node.has_method("_stop_drag_cleanup"):
					source_node._stop_drag_cleanup()
			# For same-slot drops or partial stacks, _stop_drag() will clean up after we return
			
			# CRITICAL: Return true here to exit early - stacking was handled
			return true

	# Full swap (different items or empty slot)
	# CRITICAL: Update InventoryManager for BOTH slots FIRST, before UI updates
	var source_remaining = 0
	
	# Update InventoryManager for destination slot
	if InventoryManager:
		InventoryManager.add_item_to_toolkit(slot_index, dropped_texture, dropped_stack_count)
	
	# Update destination slot UI
	set_item(dropped_texture, dropped_stack_count)
	
	# CRITICAL: Update source slot IMMEDIATELY after destination
	# This must happen before _stop_drag() is called on the source slot
	
	if is_right_click_drag:
		# Right-click drag: source should have (original - dragged) items remaining
		# CRITICAL: Recalculate source_original_stack_count to ensure it's accurate
		# This is needed because the stacking branch might not have set it
		if source_node:
			var source_current = source_node.stack_count if "stack_count" in source_node else 0
			var source_drag = source_node.drag_count if "drag_count" in source_node else dropped_stack_count
			var calculated_original = source_current + source_drag
			
			# Also read stored value if available
			var stored_original = 0
			if "original_stack_count" in source_node:
				stored_original = source_node.original_stack_count
			
			# Use stored if valid, otherwise calculated
			if stored_original > 0 and source_original_stack_count <= 0:
				source_original_stack_count = stored_original
				print("DEBUG: Full swap - using stored original_stack_count: ", source_original_stack_count)
			elif source_original_stack_count <= 0:
				source_original_stack_count = calculated_original
				print("DEBUG: Full swap - using calculated original_stack_count: ", source_original_stack_count)
		
		# Defensive fallback if still invalid
		if source_original_stack_count <= 0:
			print("ERROR: source_original_stack_count still invalid - using dropped_stack_count")
			source_original_stack_count = dropped_stack_count
		
		# Now calculate remaining items
		if source_slot_index == slot_index:
			# Dropping back to same slot - restore original count
			source_remaining = source_original_stack_count
		else:
			# Dropping to different slot - source keeps (original - dragged)
			# CRITICAL: Use original_stack_count, not current stack_count (which was already reduced)
			source_remaining = source_original_stack_count - dropped_stack_count
		
		# CRITICAL: Always update source slot for right-click drags
		# This MUST happen to preserve the original stack - don't skip this!
		# IMPORTANT: We MUST update the source slot here, before _stop_drag() is called on it
		print("DEBUG right-click: source_original_stack_count=", source_original_stack_count, " dropped_stack_count=", dropped_stack_count, " source_remaining=", source_remaining, " source_node=", source_node)
		
		# Update InventoryManager FIRST before UI
		if InventoryManager:
			if source == "inventory":
				# Source is inventory - use update_inventory_slots
				if source_remaining > 0:
					# Source slot has remaining items
					InventoryManager.update_inventory_slots(source_slot_index, dropped_texture, source_remaining)
				else:
					# Source slot is empty or gets swapped item
					if current_texture:
						InventoryManager.update_inventory_slots(source_slot_index, current_texture, current_stack_count)
					else:
						InventoryManager.update_inventory_slots(source_slot_index, null, 0)
			else:
				# Source is toolkit - use toolkit methods
				if source_remaining > 0:
					# Source slot has remaining items
					InventoryManager.add_item_to_toolkit(source_slot_index, dropped_texture, source_remaining)
				else:
					# Source slot is empty or gets swapped item
					if current_texture:
						InventoryManager.add_item_to_toolkit(source_slot_index, current_texture, current_stack_count)
					else:
						InventoryManager.remove_item_from_toolkit(source_slot_index)
		
		# Then update UI
		if source_node:
			if source_node.has_method("set_item"):
				if source_remaining > 0:
					# Update source slot to show remaining items with the same texture
					# CRITICAL: This preserves the original stack minus what was dragged
					print("DEBUG: Updating source slot to show ", source_remaining, " items")
					source_node.set_item(dropped_texture, source_remaining)
				else:
					# All items moved - source gets swapped item (if any) or becomes empty
					if current_texture:
						source_node.set_item(current_texture, current_stack_count)
					else:
						source_node.set_item(null, 0)
			else:
				print("ERROR: Source node doesn't have set_item method for right-click drag")
		else:
			print("ERROR: Source node is null for right-click drag")
	else:
		# Left-click drag: full swap
		# Source gets what was in the destination (current_texture, current_stack_count)
		# This is correct for a full swap - destination had current_texture/current_stack_count
		# Source had original_texture/original_stack_count, which is now in destination
		# So source should get what destination had
		# CRITICAL: Update InventoryManager FIRST before UI
		if InventoryManager:
			if current_texture:
				InventoryManager.add_item_to_toolkit(source_slot_index, current_texture, current_stack_count)
			else:
				InventoryManager.remove_item_from_toolkit(source_slot_index)
		
		# Then update UI
		if source_node and source_node.has_method("set_item"):
			source_node.set_item(current_texture, current_stack_count)
		elif source_node:
			# Fallback if set_item doesn't exist - shouldn't happen but be safe
			print("WARNING: Source node doesn't have set_item method")

	# Notify ToolSwitcher about the swap - update in correct order
	var tool_switcher = _find_tool_switcher()
	if tool_switcher:
		# If the dropped tool is the active tool, it's moving to this slot
		# Update this slot first so active tool follows
		tool_switcher.update_toolkit_slot(slot_index, dropped_texture)
		# Then update the source slot
		# CRITICAL: For right-click drags where texture doesn't change, SKIP ToolSwitcher
		# because it won't update the count (it only updates when texture changes)
		# and might interfere with our direct set_item() call above
		if is_right_click_drag:
			# Right-click: source keeps its original texture (unless all items were moved)
			if source_remaining > 0 and dropped_texture != current_texture:
				# Only notify ToolSwitcher if texture actually changed
				# For same-texture (most common), we already updated via set_item() above
				tool_switcher.update_toolkit_slot(source_slot_index, dropped_texture)
			elif source_remaining <= 0:
				# All items moved - notify about the swap
				tool_switcher.update_toolkit_slot(source_slot_index, current_texture)
			# else: same texture, source_remaining > 0 - already updated via set_item(), skip ToolSwitcher
			print("DEBUG: Right-click drop - skipped ToolSwitcher for source (same texture, already updated)")
		else:
			# Left-click: source gets destination's texture (full swap)
			tool_switcher.update_toolkit_slot(source_slot_index, current_texture)

	# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
	if source_node and source_node.has_method("_stop_drag_cleanup"):
		source_node._stop_drag_cleanup()

	return true


func _highlight_valid_drop() -> void:
	"""Highlight slot as valid drop target"""
	if not is_highlighted:
		is_highlighted = true
		modulate = Color(1.2, 1.2, 1.0, 1.0) # Slight yellow tint


func _reset_highlight() -> void:
	"""Reset slot highlight to default"""
	if is_highlighted:
		is_highlighted = false
		modulate = default_modulate


func _show_invalid_drop_feedback() -> void:
	"""Show visual feedback for invalid drop (red flash)"""
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_callback(_reset_highlight).set_delay(0.2)


func _select_slot() -> void:
	"""Select this slot when clicked (without dragging) - handles empty slots too"""

	# Get current texture (may be null for empty slots)
	var current_texture = get_item()

	# Notify ToolSwitcher to update active slot
	var tool_switcher = _find_tool_switcher()
	if tool_switcher:
		tool_switcher.set_hud_by_slot(slot_index)


# Godot's built-in drag-and-drop methods for receiving drops from inventory
func can_drop_data(_position: Vector2, data: Variant) -> bool:
	"""Check if data can be dropped on this toolkit slot - handles toolkit and inventory sources"""

	# Validate data structure
	if not data is Dictionary:
		_reset_highlight()
		return false

	if not data.has("item_texture"):
		_reset_highlight()
		return false

	# Accept drops from both inventory and toolkit
	var can_drop: bool = false
	if data.has("source"):
		var source: String = data["source"]
		if source == "inventory":
			can_drop = true
		elif source == "toolkit":
			# Don't allow dropping on the same slot
			var source_slot_index = data.get("slot_index", -1)
			if source_slot_index != slot_index:
				can_drop = true

	# Visual feedback
	if can_drop:
		_highlight_valid_drop()
	else:
		_reset_highlight()

	return can_drop


func drop_data(_position: Vector2, data: Variant) -> void:
	"""Handle drop operation - handles both toolkit-to-toolkit AND inventory-to-toolkit"""

	# Reset highlight
	_reset_highlight()

	if not data is Dictionary or not data.has("item_texture"):
		_show_invalid_drop_feedback()
		return

	var from_item_texture: Texture = data["item_texture"]
	var from_stack_count: int = data.get("stack_count", 1)
	var source_node = data.get("source_node", null)
	var source_slot_index = data.get("slot_index", -1)
	var source: String = data.get("source", "unknown")
	var is_right_click_drag: bool = data.get("is_right_click_drag", false)
	
	# CRITICAL: For right-click drags, use _receive_drop instead of full swap
	# This preserves the source stack correctly
	if is_right_click_drag and source_node:
		print("DEBUG drop_data: Detected right-click drag - calling _receive_drop instead of full swap")
		var success = _receive_drop(from_item_texture, from_stack_count, source_slot_index, source_node, source)
		if success:
			# CRITICAL: Clean up drag state on source slot after successful drop
			# This prevents _stop_drag() from trying to handle the drop again
			if source_node and source_node.has_method("_stop_drag_cleanup"):
				source_node._stop_drag_cleanup()
			return
		# If _receive_drop failed, fall through to normal swap logic

	# Edge case: Dropping on same slot
	if source == "toolkit" and source_slot_index == slot_index:
		return
	# Get current texture and stack count before swapping
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	var current_texture: Texture = null
	var current_stack_count: int = stack_count
	if hud_slot_rect and hud_slot_rect is TextureRect:
		current_texture = hud_slot_rect.texture

	# Attempt stacking if same item and space available (toolkit stack limit = 9)
	if (
		current_texture
		and from_item_texture
		and current_texture == from_item_texture
		and from_stack_count > 0
	):
		var space_available = MAX_TOOLBELT_STACK - current_stack_count
		if space_available > 0:
			var amount_to_add = mini(from_stack_count, space_available)
			var new_target_count = current_stack_count + amount_to_add
			set_item(current_texture, new_target_count)
			if InventoryManager:
				InventoryManager.add_item_to_toolkit(slot_index, current_texture, new_target_count)

			var remaining = from_stack_count - amount_to_add

			# CRITICAL: If there are remaining items, keep them on the cursor instead of putting them back
			# This allows the user to continue dragging the remainder to another slot
			if remaining > 0 and source_node and source == "toolkit":
				# Update drag state to continue dragging the remainder
				if "drag_count" in source_node:
					source_node.drag_count = remaining
				if "original_texture" in source_node:
					source_node.original_texture = from_item_texture
				# Update drag preview to show remaining count
				if source_node.has_method("_update_drag_preview_count"):
					source_node._update_drag_preview_count(remaining)
				elif source_node.has_method("_create_drag_preview"):
					# Recreate drag preview with new count
					if "drag_preview" in source_node and source_node.drag_preview:
						source_node._cleanup_drag_preview()
					source_node.drag_preview = source_node._create_drag_preview(from_item_texture, remaining)
				
				# Clear the source slot since all items are being dragged
				if source_node.has_method("set_item"):
					source_node.set_item(null, 0)
				if InventoryManager:
					InventoryManager.remove_item_from_toolkit(source_slot_index)
				
				# Don't call _stop_drag_cleanup() - let the user continue dragging the remainder
				print("DEBUG drop_data: Partial stack - keeping ", remaining, " items on cursor")
			else:
				# All items fit - handle normally
				if source == "toolkit" and source_slot_index >= 0:
					if remaining > 0:
						if source_node and source_node.has_method("set_item"):
							source_node.set_item(from_item_texture, remaining)
						InventoryManager.add_item_to_toolkit(
							source_slot_index, from_item_texture, remaining
						)
					else:
						if source_node and source_node.has_method("set_item"):
							source_node.set_item(null)
						InventoryManager.remove_item_from_toolkit(source_slot_index)
				elif source == "inventory" and source_slot_index >= 0:
					if source_node and source_node.has_method("set_item"):
						if remaining > 0:
							source_node.set_item(from_item_texture, remaining)
						else:
							source_node.set_item(null)
					if InventoryManager:
						if remaining > 0:
							InventoryManager.update_inventory_slots(
								source_slot_index, from_item_texture, remaining
							)
						else:
							InventoryManager.update_inventory_slots(source_slot_index, null, 0)

				# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
				# This prevents _stop_drag() from trying to handle the drop again
				if source_node and source_node.has_method("_stop_drag_cleanup"):
					source_node._stop_drag_cleanup()

			var tool_switcher = _find_tool_switcher()
			if tool_switcher and tool_switcher.has_method("update_toolkit_slot"):
				tool_switcher.update_toolkit_slot(slot_index, current_texture)
				if source == "toolkit" and source_slot_index >= 0 and remaining == 0:
					# Only update source slot if all items were stacked (not if remainder is on cursor)
					tool_switcher.update_toolkit_slot(source_slot_index, null)

			if source == "inventory" and InventoryManager:
				InventoryManager.sync_inventory_ui()

			return

	# CRITICAL: Update InventoryManager FIRST (before clearing UI slots)
	# This ensures InventoryManager has correct data when sync runs
	if InventoryManager:
		# Update toolkit tracking
		if from_item_texture:
			InventoryManager.add_item_to_toolkit(slot_index, from_item_texture, from_stack_count)
		else:
			InventoryManager.remove_item_from_toolkit(slot_index)

		# If source was inventory, update inventory tracking BEFORE clearing UI
		if source == "inventory" and source_slot_index >= 0:
			InventoryManager.update_inventory_slots(
				source_slot_index, current_texture, current_stack_count
			)

	# Swap items with stack counts
	set_item(from_item_texture, from_stack_count)

	# Update source slot with swapped item and stack
	if source_node and source_node.has_method("set_item"):
		source_node.set_item(current_texture, current_stack_count)

	# CRITICAL: Notify ToolSwitcher about the toolkit slot change
	var tool_switcher = _find_tool_switcher()
	if tool_switcher and tool_switcher.has_method("update_toolkit_slot"):
		tool_switcher.update_toolkit_slot(slot_index, from_item_texture)
		# If source was also toolkit, update that slot too
		if source == "toolkit" and source_slot_index >= 0:
			tool_switcher.update_toolkit_slot(source_slot_index, current_texture)

	# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
	# This prevents _stop_drag() from trying to handle the drop again
	if source_node and source_node.has_method("_stop_drag_cleanup"):
		source_node._stop_drag_cleanup()

	# Sync inventory UI AFTER all updates are complete
	if InventoryManager and source == "inventory" and source_slot_index >= 0:
		InventoryManager.sync_inventory_ui()


## Stack Management Functions


func _create_stack_label() -> void:
	"""Create a label to display stack count"""
	var stack_label = get_node_or_null("StackLabel")
	if not stack_label:
		stack_label = Label.new()
		stack_label.name = "StackLabel"
		stack_label.add_theme_font_size_override("font_size", 20)
		stack_label.add_theme_color_override("font_color", Color.WHITE)
		stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		stack_label.add_theme_constant_override("shadow_offset_x", 2)
		stack_label.add_theme_constant_override("shadow_offset_y", 2)
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stack_label)

		# Position in bottom-right corner
		stack_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		stack_label.offset_left = -30
		stack_label.offset_top = -25
		stack_label.offset_right = -5
		stack_label.offset_bottom = -5

	_update_stack_label()


func _update_stack_label() -> void:
	"""Update stack count label visibility and text"""
	var stack_label = get_node_or_null("StackLabel")
	if stack_label:
		if stack_count > 1:
			stack_label.text = str(stack_count)
			stack_label.visible = true
		else:
			stack_label.visible = false


func add_to_stack(amount: int = 1) -> int:
	"""Add items to stack, returns amount that couldn't be added"""
	var space_available = MAX_TOOLBELT_STACK - stack_count
	var amount_to_add = mini(amount, space_available)
	stack_count += amount_to_add
	_update_stack_label()
	return amount - amount_to_add # Return overflow


func remove_from_stack(amount: int = 1) -> int:
	"""Remove items from stack, returns amount actually removed"""
	var amount_to_remove = mini(amount, stack_count)
	stack_count -= amount_to_remove
	if stack_count <= 0:
		stack_count = 0
		set_item(null) # Clear item if stack is empty
	_update_stack_label()
	return amount_to_remove


func get_stack_count() -> int:
	"""Get current stack count"""
	return stack_count


func set_stack_count(count: int) -> void:
	"""Set stack count directly"""
	stack_count = clampi(count, 0, MAX_TOOLBELT_STACK)
	_update_stack_label()
