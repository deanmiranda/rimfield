# inventory_menu_slot.gd
# Slot for the inventory menu grid (3x10)
# Extensible for future drag/drop functionality

extends TextureButton

@export var slot_index: int = 0
@export var empty_texture: Texture
@export var is_locked: bool = false # For grayed-out upgrade slots

signal slot_clicked(slot_index: int)
signal slot_drag_started(slot_index: int, item_texture: Texture)
signal slot_drop_received(slot_index: int, data: Dictionary)

var item_texture: Texture = null
var stack_count: int = 0 # Stack count (0 = empty, max 99 for inventory)
var default_modulate: Color = Color.WHITE
var is_highlighted: bool = false
var custom_drag_preview: Control = null # For high-layer drag preview

# Manual drag system (like toolkit)
var is_dragging: bool = false
var drag_preview: TextureRect = null
var original_texture: Texture = null
var original_stack_count: int = 0 # Store original stack count
var _is_right_click_drag: bool = false # Track if this is a right-click drag
var drag_count: int = 0 # Number of items being dragged (for right-click accumulation)
var drag_preview_label: Label = null # Label for showing drag count

const MAX_INVENTORY_STACK = 99


func _ready() -> void:
	# Initialize the slot - ensure texture is set
	if empty_texture:
		texture_normal = empty_texture
		ignore_texture_size = true
		stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	if item_texture != null:
		texture_normal = item_texture
	
	# Apply locked state (grayed out for future upgrades)
	if is_locked:
		modulate = Color(0.5, 0.5, 0.5, 0.7) # Grayed out
		disabled = true
		default_modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE
		disabled = false
		default_modulate = Color.WHITE
	
	# CRITICAL: Ensure the node receives mouse events for dragging
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	
	# Force visibility
	visible = true

	# Create stack count label
	_create_stack_label()

	# Start with process disabled (enable when dragging)
	set_process(false)

	# CRITICAL: Ensure any child nodes (like Border) don't block mouse events
	# Wait a frame for children to be added, then fix their mouse_filter
	call_deferred("_fix_children_mouse_filter")


func set_slot_index(value: int) -> void:
	slot_index = value


func _fix_children_mouse_filter() -> void:
	"""Ensure all child nodes ignore mouse events so they don't block dragging"""
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			child.focus_mode = Control.FOCUS_NONE


func _process(_delta: float) -> void:
	"""Update custom drag preview position"""
	if custom_drag_preview:
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			custom_drag_preview.global_position = mouse_pos - Vector2(16, 16)
	
	# Also update drag_preview position if it exists (for right-click drags)
	if drag_preview:
		_update_drag_preview_position()


func set_item(new_texture: Texture, count: int = 1) -> void:
	"""Set the item texture for this slot"""

	item_texture = new_texture

	# Update stack count
	if new_texture:
		stack_count = maxi(count, 1) # At least 1 if there's an item
	else:
		stack_count = 0 # No item = no stack

	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

	_update_stack_label()


func get_item() -> Texture:
	"""Get the item texture from this slot"""
	return item_texture


func _gui_input(event: InputEvent) -> void:
	"""Handle manual drag and drop for inventory slots"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# FIRST: Check if another slot is dragging (toolkit or inventory)
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
			
			# No active drag from another slot - start drag if slot has an item
			# CRITICAL: Check if we're transitioning from right-click to left-click drag
			# If so, preserve original_stack_count before starting left-click drag
			if item_texture and not is_locked:
				print("DEBUG inventory _gui_input: Left-click pressed - checking for right-click drag transition")
				print("DEBUG inventory _gui_input: is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag, " original_stack_count=", original_stack_count, " stack_count=", stack_count)
				
				# If we're in a right-click drag, preserve original_stack_count before starting left-click drag
				if is_dragging and _is_right_click_drag and original_stack_count > 0:
					print("DEBUG inventory _gui_input: Transitioning from right-click to left-click drag - preserving original_stack_count=", original_stack_count)
					# Store the original_stack_count temporarily so _start_drag() can use it
					# We'll restore it after _start_drag() detects it
					var preserved_original_stack_count = original_stack_count
					_start_drag()
					# If _start_drag() didn't detect it (shouldn't happen, but just in case), restore it
					if original_stack_count == 0 and preserved_original_stack_count > 0:
						print("DEBUG inventory _gui_input: WARNING - _start_drag() didn't preserve original_stack_count, restoring it")
						original_stack_count = preserved_original_stack_count
				else:
					_start_drag()
			else:
				emit_signal("slot_clicked", slot_index)
		elif not event.pressed:
			if is_dragging:
				# Stop drag
				_stop_drag()
			else:
				# Click without drag
				emit_signal("slot_clicked", slot_index)
	elif event is InputEventMouseMotion and is_dragging:
		# Update drag preview position
		_update_drag_preview_position()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		# Right-click drag: grab one item at a time
		_start_right_click_drag()


func _start_drag() -> void:
	"""Start manual drag operation"""
	if is_locked or item_texture == null:
		return

	# CRITICAL: If a right-click drag is already in progress, use the original_stack_count
	# from the right-click drag, not the reduced stack_count
	print("DEBUG inventory _start_drag: ENTRY - is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag, " original_stack_count=", original_stack_count, " stack_count=", stack_count, " drag_count=", drag_count, " drag_preview=", drag_preview != null)
	
	var stack_to_drag = stack_count
	var was_right_click_drag = false
	
	# CRITICAL: Check if we're in a right-click drag state - check multiple indicators
	# because the drag state might be partially cleaned up but original_stack_count still valid
	var has_right_click_indicator = false
	if is_dragging and _is_right_click_drag and original_stack_count > 0:
		has_right_click_indicator = true
		print("DEBUG inventory _start_drag: Right-click drag indicator 1 - is_dragging=true, _is_right_click_drag=true")
	elif original_stack_count > 0 and (drag_count > 0 or drag_preview != null):
		# CRITICAL: If original_stack_count exists and we have drag indicators (drag_count or drag_preview),
		# we're likely in a right-click drag that was partially cleaned up
		has_right_click_indicator = true
		print("DEBUG inventory _start_drag: Right-click drag indicator 2 - original_stack_count=", original_stack_count, " drag_count=", drag_count, " drag_preview=", drag_preview != null)
	elif original_stack_count > 0 and stack_count < original_stack_count:
		# CRITICAL: If original_stack_count exists and is greater than current stack_count,
		# we were definitely in a right-click drag (stack was reduced)
		has_right_click_indicator = true
		print("DEBUG inventory _start_drag: Right-click drag indicator 3 - original_stack_count=", original_stack_count, " > stack_count=", stack_count)
	
	if has_right_click_indicator:
		# Right-click drag detected - use the original stack count
		stack_to_drag = original_stack_count
		was_right_click_drag = true
		print("DEBUG inventory: Left-click during/after right-click drag - using original_stack_count=", original_stack_count, " instead of current stack_count=", stack_count)
	
	print("DEBUG inventory _start_drag: After checks - stack_to_drag=", stack_to_drag, " was_right_click_drag=", was_right_click_drag)

	# CRITICAL: Clean up right-click drag state if it was active
	# BUT: Preserve original_stack_count BEFORE cleaning up, so we can use it for left-click drag
	var preserved_original_for_left_click = 0
	if was_right_click_drag or (is_dragging and _is_right_click_drag):
		# CRITICAL: Preserve original_stack_count BEFORE cleaning up right-click drag state
		# This ensures we can use it for the left-click drag even after cleanup
		if original_stack_count > 0:
			preserved_original_for_left_click = original_stack_count
			print("DEBUG inventory _start_drag: Preserving original_stack_count=", preserved_original_for_left_click, " for left-click drag")
		
		# Clean up the right-click drag preview first
		if drag_preview:
			var drag_layer = drag_preview.get_parent()
			if drag_layer and drag_layer.name == "InventoryDragPreviewLayer":
				drag_layer.queue_free()
			else:
				drag_preview.queue_free()
			drag_preview = null
		if drag_preview_label:
			drag_preview_label.queue_free()
			drag_preview_label = null
		
		# CRITICAL: Restore the slot to show the full original stack count in InventoryManager
		# before we clear it for the left-click drag
		if stack_to_drag > stack_count:
			# Update InventoryManager first to reflect the full stack
			if InventoryManager:
				InventoryManager.update_inventory_slots(slot_index, item_texture, stack_to_drag)
			# Update UI to show full stack temporarily (before we clear it for drag)
			# CRITICAL: Temporarily clear is_dragging so set_item doesn't warn
			var temp_is_dragging = is_dragging
			is_dragging = false
			set_item(item_texture, stack_to_drag)
			is_dragging = temp_is_dragging
		
		# Clear is_dragging temporarily so set_item doesn't warn when we clear the slot
		is_dragging = false
	else:
		# No right-click drag was active - ensure is_dragging is false before clearing slot
		is_dragging = false

	# CRITICAL: Clear the slot visually (set to 0) since we're dragging the entire stack
	# This matches the behavior of left-click drag in toolkit
	# Do this BEFORE setting is_dragging = true to avoid warnings
	set_item(item_texture, 0)

	is_dragging = true
	_is_right_click_drag = false # Mark this as a left-click drag
	original_texture = item_texture
	# CRITICAL: Use preserved_original_for_left_click if it was set (from right-click drag transition)
	# Otherwise use stack_to_drag
	if preserved_original_for_left_click > 0:
		original_stack_count = preserved_original_for_left_click
		print("DEBUG inventory _start_drag: Using preserved original_stack_count=", original_stack_count, " from right-click drag")
	else:
		original_stack_count = stack_to_drag # Store the stack count (use original if right-click was active)
	drag_count = stack_to_drag # For left-click, drag the entire stack

	print("DEBUG inventory: Starting left-click drag - original_stack_count=", original_stack_count, " drag_count=", drag_count, " stack_to_drag=", stack_to_drag)

	# Create drag preview on high layer
	drag_preview = _create_drag_preview(item_texture, stack_to_drag)

	# Dim the source slot
	modulate = Color(0.5, 0.5, 0.5, 0.7)

	# Enable process to keep ghost icon visible globally
	set_process(true)


func _start_right_click_drag() -> void:
	"""Start or accumulate right-click drag (instantly takes one item, no hold needed)"""
	if item_texture == null or stack_count <= 0:
		return # No item to drag

	# If already dragging the same item from THIS slot, add one more to the drag count
	if is_dragging and _is_right_click_drag and original_texture == item_texture:
		# CRITICAL: Can't drag more than the original stack count (prevent creating items)
		if drag_count >= original_stack_count:
			print("DEBUG inventory: Cannot accumulate more - already at max (", original_stack_count, ")")
			return # Already dragging the full stack
		
		# Accumulate one more item
		drag_count += 1
		print("DEBUG inventory: Accumulating right-click drag - now dragging ", drag_count, " items")
		
		# Update the displayed count to reflect the new drag
		var new_remaining = original_stack_count - drag_count
		
		# CRITICAL: Update InventoryManager FIRST before UI to prevent sync issues
		if InventoryManager:
			if new_remaining > 0:
				InventoryManager.update_inventory_slots(slot_index, item_texture, new_remaining)
			else:
				InventoryManager.update_inventory_slots(slot_index, null, 0)
		
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
	print("DEBUG inventory _start_right_click_drag: BEFORE - is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag, " original_stack_count=", original_stack_count, " stack_count=", stack_count, " drag_count=", drag_count)
	
	is_dragging = true
	_is_right_click_drag = true # Mark this as a right-click drag
	original_texture = item_texture
	original_stack_count = stack_count # Store the original stack count BEFORE reducing
	drag_count = 1 # Start with 1 item
	
	print("DEBUG inventory: Starting right-click drag - original_stack_count=", original_stack_count, " drag_count=", drag_count, " AFTER setting - is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag)

	# Create ghost icon that follows cursor
	drag_preview = _create_drag_preview(item_texture, 1)

	# Update slot to show reduced count (stack_count - 1)
	var remaining = original_stack_count - drag_count
	
	# CRITICAL: Update InventoryManager FIRST before UI to prevent sync issues
	if InventoryManager:
		if remaining > 0:
			InventoryManager.update_inventory_slots(slot_index, item_texture, remaining)
		else:
			InventoryManager.update_inventory_slots(slot_index, null, 0)
	
	# Then update UI
	set_item(item_texture, remaining)

	# Make slot semi-transparent while dragging
	modulate = Color(1, 1, 1, 0.3)

	# Enable process to keep ghost icon visible globally
	set_process(true)


func _stop_drag() -> void:
	"""Stop drag operation - cleanup"""
	
	# CRITICAL: If is_dragging is already false, _stop_drag_cleanup() was already called
	# This means the drop was already handled by drop_data() - don't try to handle it again
	if not is_dragging:
		print("DEBUG inventory _stop_drag: is_dragging is already false - drop was already handled")
		return

	# Get mouse position for drop detection
	var viewport = get_viewport()
	var drop_position = viewport.get_mouse_position()
	
	# FIRST: Check if clicking on UI (toolkit or inventory slots)
	var drop_success = _handle_drop(drop_position)
	
	# CRITICAL: After _handle_drop(), check if is_dragging is still true
	# If _stop_drag_cleanup() was called by drop_data(), is_dragging will be false
	# In that case, the drop was already handled and cleaned up - don't do anything else
	if not is_dragging:
		print("DEBUG inventory _stop_drag: After _handle_drop(), is_dragging is false - drop was already handled")
		return
	
	# If drop didn't succeed on UI, check if clicking on world (throw-to-world)
	if not drop_success:
		# Check if mouse is over any UI Control node
		var is_over_ui = _is_mouse_over_ui(drop_position)
		if not is_over_ui:
			# Not over UI - throw to world
			_throw_to_world(drop_position)
			drop_success = true # Mark as successful to prevent cancel

	# Clean up drag preview and its parent layer
	if drag_preview:
		var drag_layer = drag_preview.get_parent()
		if drag_layer and drag_layer.name == "InventoryDragPreviewLayer":
			drag_layer.queue_free()
		else:
			drag_preview.queue_free()
		drag_preview = null
	
	# Clean up drag preview label
	if drag_preview_label:
		drag_preview_label.queue_free()
		drag_preview_label = null

	# Restore slot appearance
	modulate = default_modulate

	# If drop failed, restore original texture and count
	if not drop_success:
		set_item(original_texture, original_stack_count)

	is_dragging = false
	_is_right_click_drag = false
	drag_count = 0
	original_texture = null
	original_stack_count = 0
	
	# Disable process
	set_process(false)


func _stop_drag_cleanup() -> void:
	"""Clean up drag state without handling drop (called by drop handler)"""
	print("DEBUG inventory _stop_drag_cleanup: Cleaning up drag state - is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag, " original_stack_count=", original_stack_count, " drag_count=", drag_count)
	
	# Clean up drag preview and its parent layer
	if drag_preview:
		var drag_layer = drag_preview.get_parent()
		if drag_layer and drag_layer.name == "InventoryDragPreviewLayer":
			drag_layer.queue_free()
		else:
			drag_preview.queue_free()
		drag_preview = null
	
	# Clean up drag preview label
	if drag_preview_label:
		drag_preview_label.queue_free()
		drag_preview_label = null
	
	# Restore slot appearance
	modulate = default_modulate
	
	# Clear drag state
	is_dragging = false
	_is_right_click_drag = false
	drag_count = 0
	original_texture = null
	original_stack_count = 0
	
	print("DEBUG inventory _stop_drag_cleanup: AFTER cleanup - is_dragging=", is_dragging, " _is_right_click_drag=", _is_right_click_drag, " original_stack_count=", original_stack_count)
	
	# Disable process
	set_process(false)


func _update_drag_preview_count(new_count: int) -> void:
	"""Update the count label on the drag preview"""
	if drag_preview:
		if new_count > 1:
			if drag_preview_label:
				drag_preview_label.text = str(new_count)
				drag_preview_label.visible = true
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


func _create_drag_preview(texture: Texture, count: int = 0) -> TextureRect:
	"""Create ghost icon that follows cursor - 50% smaller than original"""
	var preview = TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(32, 32) # 50% smaller
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.7) # Semi-transparent ghost
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create a dedicated CanvasLayer on top of everything
	var drag_layer = CanvasLayer.new()
	drag_layer.name = "InventoryDragPreviewLayer"
	drag_layer.layer = 100 # Very high layer
	get_tree().root.add_child(drag_layer)

	# Add preview to the dedicated layer
	drag_layer.add_child(preview)
	preview.z_index = 1000
	preview.z_as_relative = false

	var viewport = get_viewport()
	if viewport:
		var mouse_pos = viewport.get_mouse_position()
		preview.global_position = mouse_pos - Vector2(16, 16)

	# Add count label if count > 1
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
		drag_preview_label.position = Vector2(0, 20)
		drag_preview_label.size = Vector2(32, 12)
		preview.add_child(drag_preview_label)

	return preview


func _update_drag_preview_position() -> void:
	"""Update ghost icon position to follow cursor"""
	if drag_preview:
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			drag_preview.global_position = mouse_pos - Vector2(16, 16)


func _handle_drop(drop_position: Vector2) -> bool:
	"""Handle drop at position - inventory-to-inventory or inventory-to-toolkit"""
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position() if viewport else drop_position


	# PRIORITY 1: Check toolkit slots (in HUD)
	var hud = _find_hud()
	if hud:
		for i in range(hud.get_child_count()):
			var child = hud.get_child(i)

		# Navigate the known path: HUD/MarginContainer/HBoxContainer
		var margin_container = hud.get_node_or_null("MarginContainer")
		if margin_container:
			var toolkit_container = margin_container.get_node_or_null("HBoxContainer")
			if toolkit_container:
				for i in range(toolkit_container.get_child_count()):
					var toolkit_slot = toolkit_container.get_child(i)
					if toolkit_slot and toolkit_slot is TextureButton:
						var slot_rect = toolkit_slot.get_global_rect()

						if slot_rect.has_point(mouse_pos):
							# Create drag data in the format expected by toolkit slots
							var drag_data = {
								"slot_index": slot_index,
								"item_texture": original_texture,
								"stack_count": original_stack_count, # Use original count, not current
								"source": "inventory",
								"source_node": self
							}

							# Check if toolkit slot can accept this drop
							if toolkit_slot.has_method("can_drop_data"):
								var can_drop = toolkit_slot.can_drop_data(mouse_pos, drag_data)
								if can_drop and toolkit_slot.has_method("drop_data"):
									toolkit_slot.drop_data(mouse_pos, drag_data)
									return true

	# PRIORITY 2: Check other inventory slots (in pause menu)
	var pause_menu = _find_pause_menu()
	if pause_menu:
		var inventory_grid = (
			pause_menu
			.get_node_or_null(
				"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
			)
		)
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var inventory_slot = inventory_grid.get_child(i)
				if inventory_slot and inventory_slot is TextureButton and inventory_slot != self:
					var slot_rect = inventory_slot.get_global_rect()

					if slot_rect.has_point(mouse_pos):
						# Check if it's locked
						if inventory_slot.is_locked:
							continue

						# Create drag data in the format expected by inventory slots
						var drag_data = _get_drag_data_for_drop()
						
						# Check if inventory slot can accept this drop
						if inventory_slot.has_method("can_drop_data"):
							var can_drop = inventory_slot.can_drop_data(mouse_pos, drag_data)
							if can_drop and inventory_slot.has_method("drop_data"):
								inventory_slot.drop_data(mouse_pos, drag_data)
								return true

						return false

	return false


func _is_mouse_over_ui(mouse_pos: Vector2) -> bool:
	"""Check if mouse is over any UI Control node (toolkit or inventory)"""
	# Check toolkit slots
	var hud = _find_hud()
	if hud:
		var margin_container = hud.get_node_or_null("MarginContainer")
		if margin_container:
			var toolkit_container = margin_container.get_node_or_null("HBoxContainer")
			if toolkit_container:
				for i in range(toolkit_container.get_child_count()):
					var slot = toolkit_container.get_child(i)
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


func _cancel_drag() -> void:
	"""Cancel drag operation and restore items to original slot"""
	if not is_dragging:
		return

	# Clean up drag preview
	_cleanup_drag_preview()

	# Restore slot appearance
	modulate = default_modulate

	# Restore original texture and count
	set_item(original_texture, original_stack_count)

	is_dragging = false
	original_texture = null
	original_stack_count = 0
	set_process(false)


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
	var item_count = original_stack_count
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
	
	# Remove items from inventory
	if InventoryManager:
		InventoryManager.update_inventory_slots(slot_index, null, 0)
	
	# Clean up drag
	is_dragging = false
	original_texture = null
	original_stack_count = 0
	set_process(false)
	_cleanup_drag_preview()
	
	# Clear slot
	set_item(null, 0)


func _find_toolkit_container(node: Node) -> Node:
	if node is HBoxContainer and node.get_child_count() > 0:
		var first_child = node.get_child(0)

		# Check if it's a TextureButton (toolkit slots are TextureButtons)
		if first_child and first_child is TextureButton:
			# Check if it has the hud_slot.gd script methods
			if first_child.has_method("_start_drag"):
				return node

	# Recursively check children
	for child in node.get_children():
		var result = _find_toolkit_container(child)
		if result:
			return result
	return null


func _find_pause_menu() -> Node:
	"""Find pause menu in scene tree"""
	var root = get_tree().root
	return _search_for_pause_menu(root)


func _search_for_pause_menu(node: Node) -> Node:
	"""Recursively search for pause menu node"""
	if not node:
		return null
	if node is Control and node.has_method("_setup_inventory_slots"):
		return node
	for child in node.get_children():
		var result = _search_for_pause_menu(child)
		if result:
			return result
	return null


func _find_hud() -> Node:
	"""Find HUD CanvasLayer in scene tree - NOT the autoload singleton!"""
	# The hud.tscn is instantiated as "Hud" (Node), which contains "HUD" (CanvasLayer)
	# We need to find "Hud" node first, then get its "HUD" child

	# Search for the "Hud" node (root of hud.tscn instance)
	var hud_root = _search_for_hud_root(get_tree().root)
	if hud_root:
		# Get the HUD CanvasLayer child
		var hud_canvas = hud_root.get_node_or_null("HUD")
		if hud_canvas:
			return hud_canvas
	return null


func _find_dragging_slot() -> Node:
	"""Find any slot (toolkit or inventory) that is currently dragging"""
	# Check toolkit slots first
	var hud = _find_hud()
	if hud:
		var margin_container = hud.get_node_or_null("MarginContainer")
		if margin_container:
			var toolkit_container = margin_container.get_node_or_null("HBoxContainer")
			if toolkit_container:
				for i in range(toolkit_container.get_child_count()):
					var slot = toolkit_container.get_child(i)
					if slot and slot is TextureButton:
						# Check if slot has is_dragging variable
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
				if slot and slot is TextureButton and slot != self:
					# Check if slot has is_dragging variable
					if "is_dragging" in slot and slot.is_dragging:
						return slot
	
	return null


func _get_drag_data_for_drop() -> Dictionary:
	"""Get drag data for dropping into another slot"""
	if not is_dragging:
		return {}
	
	# For right-click drags, use drag_count instead of original_stack_count
	var stack_count_to_send = drag_count if _is_right_click_drag else original_stack_count
	
	return {
		"slot_index": slot_index,
		"item_texture": original_texture,
		"stack_count": stack_count_to_send,
		"source": "inventory",
		"source_node": self,
		"is_right_click_drag": _is_right_click_drag, # CRITICAL: Include right-click drag flag
		"original_stack_count": original_stack_count # CRITICAL: Include original stack count for right-click drags
	}


func _search_for_hud_root(node: Node) -> Node:
	"""Recursively search for Hud Node (root of hud.tscn)"""
	if not node:
		return null
	# Look for a Node named "Hud" that has a CanvasLayer child named "HUD"
	if node.name == "Hud" and node is Node:
		# Verify it has an "HUD" CanvasLayer child
		var hud_child = node.get_node_or_null("HUD")
		if hud_child and hud_child is CanvasLayer:
			return node

	# Recursively check children
	for child in node.get_children():
		var result = _search_for_hud_root(child)
		if result:
			return result
	return null


# Drag/drop functionality
func get_drag_data(_position: Vector2) -> Variant:
	"""Prepare for drag operation from inventory slot"""

	if item_texture == null or is_locked:
		return null
	
	var drag_data = {
		"slot_index": slot_index,
		"item_texture": item_texture,
		"stack_count": stack_count,
		"source": "inventory", # Standardized source identifier
		"source_node": self # Reference to source slot for swapping
	}

	# Create custom drag preview on high layer (like toolkit does)
	# This ensures it's visible above the pause menu (layer 10)
	var drag_layer = CanvasLayer.new()
	drag_layer.name = "InventoryDragPreviewLayer"
	drag_layer.layer = 100 # Very high layer
	get_tree().root.add_child(drag_layer)

	var drag_preview = TextureRect.new()
	drag_preview.texture = item_texture
	drag_preview.custom_minimum_size = Vector2(32, 32) # 50% smaller
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.modulate = Color(1, 1, 1, 0.7)
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 1000
	drag_preview.z_as_relative = false

	drag_layer.add_child(drag_preview)

	# Store reference for cleanup and updates
	custom_drag_preview = drag_preview

	# Position at mouse
	var viewport = get_viewport()
	if viewport:
		var mouse_pos = viewport.get_mouse_position()
		drag_preview.global_position = mouse_pos - Vector2(16, 16)

	# Start updating preview position
	set_process(true)

	# Still use set_drag_preview for Godot's drag system, but make it invisible
	var invisible_preview = Control.new()
	invisible_preview.modulate = Color(1, 1, 1, 0) # Fully transparent
	set_drag_preview(invisible_preview)
	
	emit_signal("slot_drag_started", slot_index, item_texture)
	return drag_data


func can_drop_data(_position: Vector2, data: Variant) -> bool:
	"""Check if data can be dropped here - with visual feedback"""
	var can_drop: bool = false
	
	# Cannot drop on locked slots
	if is_locked:
		_reset_highlight()
		return false
	
	# Validate data structure
	if not data is Dictionary:
		_reset_highlight()
		return false
	
	if not data.has("item_texture"):
		_reset_highlight()
		return false
	
	# Accept drops from toolkit (Phase 1) or inventory (Phase 3)
	if data.has("source"):
		var source: String = data["source"]
		if source == "toolkit" or source == "inventory":
			can_drop = true
	
	# Visual feedback: highlight valid drop targets
	if can_drop:
		_highlight_valid_drop()
	else:
		_reset_highlight()
	
	return can_drop


func drop_data(_position: Vector2, data: Variant) -> void:
	"""Handle drop operation - swap items if slot is occupied"""

	# Clean up custom drag preview if it exists
	_cleanup_drag_preview()

	# Reset highlight after drop
	_reset_highlight()
	
	if not data is Dictionary or not data.has("item_texture"):
		_show_invalid_drop_feedback()
		return
	
	if is_locked:
		_show_invalid_drop_feedback()
		return # Cannot drop on locked slots
	
	# Edge case: Dragging to same slot (no-op)
	var source_slot_index = data.get("slot_index", -1)
	if data.has("source") and data["source"] == "inventory" and source_slot_index == slot_index:
		return # Same slot, no-op
	
	var from_item_texture: Texture = data["item_texture"]
	var from_stack_count: int = data.get("stack_count", 1)
	var source_node = data.get("source_node", null)
	var source: String = data.get("source", "unknown")
	
	# CRITICAL: Check drag data FIRST for right-click drag flag (more reliable)
	var is_right_click_drag: bool = data.get("is_right_click_drag", false)
	var source_original_stack_count: int = data.get("original_stack_count", 0)
	
	# CRITICAL: For right-click drags from toolkit, we need to preserve the source stack
	# If drag data doesn't have the flag, check source_node as fallback
	if source == "toolkit" and source_node and not is_right_click_drag:
		# Fallback: Check if source_node has right-click drag state
		if "_is_right_click_drag" in source_node and source_node._is_right_click_drag:
			is_right_click_drag = true
			
			# CRITICAL: Calculate original_stack_count defensively
			var source_current = source_node.stack_count if "stack_count" in source_node else 0
			var source_drag = source_node.drag_count if "drag_count" in source_node else from_stack_count
			var calculated_original = source_current + source_drag
			
			# Also read stored value
			var stored_original = 0
			if "original_stack_count" in source_node:
				stored_original = source_node.original_stack_count
			
			# Use stored if valid, otherwise calculated
			if stored_original > 0:
				source_original_stack_count = stored_original
			else:
				source_original_stack_count = calculated_original
			
			# Defensive fallback
			if source_original_stack_count <= 0:
				source_original_stack_count = from_stack_count
			
			print("DEBUG inventory drop_data: Right-click drag detected from source_node, source_original_stack_count=", source_original_stack_count, " (stored=", stored_original, " calculated=", calculated_original, ")")
	
	if is_right_click_drag:
		print("DEBUG inventory drop_data: Right-click drag detected from drag data, is_right_click_drag=", is_right_click_drag, " source_original_stack_count=", source_original_stack_count)

	# Get current item BEFORE swapping (for InventoryManager update)
	var temp_texture: Texture = item_texture
	var temp_stack_count: int = stack_count

	# Attempt stacking if same item and space available
	if (
		temp_texture
		and from_item_texture
		and temp_texture == from_item_texture
		and from_stack_count > 0
	):
		var space_available = MAX_INVENTORY_STACK - temp_stack_count
		if space_available > 0:
			var amount_to_add = mini(from_stack_count, space_available)
			var new_target_count = temp_stack_count + amount_to_add

			# Update this slot visually and in InventoryManager
			set_item(temp_texture, new_target_count)
			if InventoryManager:
				InventoryManager.update_inventory_slots(slot_index, temp_texture, new_target_count)

			var remaining = from_stack_count - amount_to_add

			if source == "inventory" and source_slot_index >= 0:
				# CRITICAL: For right-click drags, if there are remaining items, keep them on the cursor
				# instead of putting them back in the source slot
				if is_right_click_drag and source_original_stack_count > 0 and remaining > 0:
					print("DEBUG inventory drop_data: Right-click stack with remainder - keeping ", remaining, " items on cursor")
					# Update source node's drag state to continue dragging the remainder
					if "drag_count" in source_node:
						source_node.drag_count = remaining
					if "original_texture" in source_node:
						source_node.original_texture = from_item_texture
					if "original_stack_count" in source_node:
						source_node.original_stack_count = source_original_stack_count
					# Update drag preview to show remaining count
					if source_node.has_method("_update_drag_preview_count"):
						source_node._update_drag_preview_count(remaining)
					elif source_node.has_method("_create_drag_preview"):
						# Recreate drag preview with new count
						if "drag_preview" in source_node and source_node.drag_preview:
							if source_node.has_method("_cleanup_drag_preview"):
								source_node._cleanup_drag_preview()
						source_node.drag_preview = source_node._create_drag_preview(from_item_texture, remaining)
					# Clear the source slot since all items are being dragged
					if source_node.has_method("set_item"):
						source_node.set_item(null, 0)
					if InventoryManager:
						InventoryManager.update_inventory_slots(source_slot_index, null, 0)
					# Don't call _stop_drag_cleanup() - let the user continue dragging the remainder
				else:
					# Left-click drag or no remainder - normal handling
					if InventoryManager:
						if remaining > 0:
							InventoryManager.update_inventory_slots(
								source_slot_index, from_item_texture, remaining
							)
						else:
							InventoryManager.update_inventory_slots(source_slot_index, null, 0)
					if source_node and source_node.has_method("set_item"):
						if remaining > 0:
							source_node.set_item(from_item_texture, remaining)
						else:
							source_node.set_item(null)
					
					# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
					if source_node and source_node.has_method("_stop_drag_cleanup"):
						source_node._stop_drag_cleanup()
					elif source_node:
						# Fallback: directly clear drag state if method doesn't exist
						if "is_dragging" in source_node:
							source_node.is_dragging = false
						if "_is_right_click_drag" in source_node:
							source_node._is_right_click_drag = false
						if "drag_preview" in source_node and source_node.drag_preview:
							if source_node.has_method("_cleanup_drag_preview"):
								source_node._cleanup_drag_preview()
			elif source == "toolkit" and source_slot_index >= 0:
				# For right-click drags, calculate remaining from original_stack_count
				var source_remaining = remaining
				if is_right_click_drag and source_original_stack_count > 0:
					# Right-click: source should have (original - dragged) items remaining
					source_remaining = source_original_stack_count - from_stack_count
					print("DEBUG inventory drop_data: Right-click stack - original=", source_original_stack_count, " dragged=", from_stack_count, " remaining=", source_remaining)
				
				if source_remaining > 0:
					InventoryManager.add_item_to_toolkit(
						source_slot_index, from_item_texture, source_remaining
					)
					if source_node and source_node.has_method("set_item"):
						source_node.set_item(from_item_texture, source_remaining)
				else:
					InventoryManager.remove_item_from_toolkit(source_slot_index)
					if source_node and source_node.has_method("set_item"):
						source_node.set_item(null)
				
				# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
				if source_node and source_node.has_method("_stop_drag_cleanup"):
					source_node._stop_drag_cleanup()
				elif source_node:
					# Fallback: directly clear drag state if method doesn't exist
					if "is_dragging" in source_node:
						source_node.is_dragging = false
					if "_is_right_click_drag" in source_node:
						source_node._is_right_click_drag = false
					if "drag_preview" in source_node and source_node.drag_preview:
						if source_node.has_method("_cleanup_drag_preview"):
							source_node._cleanup_drag_preview()

			if InventoryManager:
				InventoryManager.sync_inventory_ui()

			emit_signal("slot_drop_received", slot_index, data)
			return

	# CRITICAL: Update InventoryManager FIRST (before UI swap)
	# This ensures InventoryManager has correct data when sync runs
	if InventoryManager:
		# Update inventory slot with dropped item
		InventoryManager.update_inventory_slots(slot_index, from_item_texture, from_stack_count)

		# If source is toolkit, update toolkit slot with swapped item
		if source == "toolkit":
			var toolkit_slot_index = data.get("slot_index", -1)
			if toolkit_slot_index >= 0:
				if temp_texture:
					InventoryManager.add_item_to_toolkit(
						toolkit_slot_index, temp_texture, temp_stack_count
					)
				else:
					InventoryManager.remove_item_from_toolkit(toolkit_slot_index)
		# If source is inventory, update inventory slot with swapped item
		# CRITICAL: For right-click drags, preserve the remaining stack instead of swapping
		elif source == "inventory" and source_slot_index >= 0:
			if is_right_click_drag and source_original_stack_count > 0:
				# Right-click drag: source should have (original - dragged) items remaining
				var source_remaining = source_original_stack_count - from_stack_count
				if source_remaining > 0:
					InventoryManager.update_inventory_slots(source_slot_index, from_item_texture, source_remaining)
				else:
					InventoryManager.update_inventory_slots(source_slot_index, null, 0)
			elif temp_texture:
				InventoryManager.update_inventory_slots(
					source_slot_index, temp_texture, temp_stack_count
				)
			else:
				InventoryManager.update_inventory_slots(source_slot_index, null, 0)

	# NOW swap items in UI
	set_item(from_item_texture, from_stack_count)
	
	# Update source slot if it's a node reference
	# For right-click drags from toolkit, preserve the remaining stack
	if source == "toolkit" and source_slot_index >= 0 and is_right_click_drag and source_original_stack_count > 0:
		# Right-click drag: source should have (original - dragged) items remaining
		var source_remaining = source_original_stack_count - from_stack_count
		print("DEBUG inventory drop_data: Right-click full swap from toolkit - original=", source_original_stack_count, " dragged=", from_stack_count, " remaining=", source_remaining)
		if source_node and source_node.has_method("set_item"):
			if source_remaining > 0:
				source_node.set_item(from_item_texture, source_remaining)
			else:
				# All items moved - source gets swapped item (if any) or becomes empty
				source_node.set_item(temp_texture, temp_stack_count)
		# Update InventoryManager
		if InventoryManager:
			if source_remaining > 0:
				InventoryManager.add_item_to_toolkit(source_slot_index, from_item_texture, source_remaining)
			else:
				if temp_texture:
					InventoryManager.add_item_to_toolkit(source_slot_index, temp_texture, temp_stack_count)
				else:
					InventoryManager.remove_item_from_toolkit(source_slot_index)
		
		# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
		if source_node and source_node.has_method("_stop_drag_cleanup"):
			source_node._stop_drag_cleanup()
		elif source_node:
			# Fallback: directly clear drag state if method doesn't exist
			if "is_dragging" in source_node:
				source_node.is_dragging = false
			if "_is_right_click_drag" in source_node:
				source_node._is_right_click_drag = false
			if "drag_preview" in source_node and source_node.drag_preview:
				if source_node.has_method("_cleanup_drag_preview"):
					source_node._cleanup_drag_preview()
	# For right-click drags from inventory, preserve the remaining stack
	elif source == "inventory" and source_slot_index >= 0 and is_right_click_drag and source_original_stack_count > 0:
		# Right-click drag: source should have (original - dragged) items remaining, plus swapped item
		var source_remaining = source_original_stack_count - from_stack_count
		print("DEBUG inventory drop_data: Right-click drop from inventory - original=", source_original_stack_count, " dragged=", from_stack_count, " remaining=", source_remaining, " temp_texture=", temp_texture)
		
		# Update source slot: swap the items, preserving remaining items if same type
		# CRITICAL: Handle empty slot case (temp_texture is null)
		if source_node and source_node.has_method("set_item"):
			if not temp_texture:
				# Empty slot - just update source with remaining items
				print("DEBUG inventory drop_data: Right-click drop on empty slot - updating source with remaining items")
				if source_remaining > 0:
					source_node.set_item(from_item_texture, source_remaining)
				else:
					source_node.set_item(null, 0)
				# Clean up drag state
				if source_node.has_method("_stop_drag_cleanup"):
					source_node._stop_drag_cleanup()
			elif source_remaining > 0 and temp_texture == from_item_texture:
				# Same item type - stack the remaining items with the swapped item
				var new_source_count = temp_stack_count + source_remaining
				source_node.set_item(temp_texture, new_source_count)
				if InventoryManager:
					InventoryManager.update_inventory_slots(source_slot_index, temp_texture, new_source_count)
				# All items handled - clean up drag state
				if source_node.has_method("_stop_drag_cleanup"):
					source_node._stop_drag_cleanup()
			else:
				# Different item type or no remaining items - swap: source gets swapped item
				# CRITICAL: If remaining items exist, keep them on the cursor instead of losing them
				if source_remaining > 0:
					print("DEBUG inventory drop_data: Right-click swap with different item type - keeping ", source_remaining, " items on cursor")
					# CRITICAL: Source slot gets the swapped item (temp_texture, temp_stack_count)
					# This is the item that was in the target slot before the swap
					source_node.set_item(temp_texture, temp_stack_count)
					if InventoryManager:
						InventoryManager.update_inventory_slots(source_slot_index, temp_texture, temp_stack_count)
					
					# Update source node's drag state to continue dragging the remaining items
					if "drag_count" in source_node:
						source_node.drag_count = source_remaining
					if "original_texture" in source_node:
						source_node.original_texture = from_item_texture
					if "original_stack_count" in source_node:
						source_node.original_stack_count = source_original_stack_count
					# Update drag preview to show remaining count
					if source_node.has_method("_update_drag_preview_count"):
						source_node._update_drag_preview_count(source_remaining)
					elif source_node.has_method("_create_drag_preview"):
						# Recreate drag preview with new count
						if "drag_preview" in source_node and source_node.drag_preview:
							if source_node.has_method("_cleanup_drag_preview"):
								source_node._cleanup_drag_preview()
						source_node.drag_preview = source_node._create_drag_preview(from_item_texture, source_remaining)
					# Don't call _stop_drag_cleanup() - let the user continue dragging the remainder
				else:
					# No remaining items - just swap
					source_node.set_item(temp_texture, temp_stack_count)
					if InventoryManager:
						InventoryManager.update_inventory_slots(source_slot_index, temp_texture, temp_stack_count)
					# Clean up drag state
					if source_node.has_method("_stop_drag_cleanup"):
						source_node._stop_drag_cleanup()
		
		# Only clean up if _stop_drag_cleanup() wasn't called above
		if source_node and source_node.has_method("_stop_drag_cleanup") and source_node.is_dragging:
			# This should only happen if source_remaining == 0 and same item type (already handled above)
			# But just in case, check if drag state is still active
			if not (source_remaining > 0 and temp_texture != from_item_texture):
				source_node._stop_drag_cleanup()
		elif source_node and not source_node.has_method("_stop_drag_cleanup"):
			# Fallback: directly clear drag state if method doesn't exist
			if "is_dragging" in source_node:
				source_node.is_dragging = false
			if "_is_right_click_drag" in source_node:
				source_node._is_right_click_drag = false
			if "drag_preview" in source_node and source_node.drag_preview:
				if source_node.has_method("_cleanup_drag_preview"):
					source_node._cleanup_drag_preview()
	elif source_node and source_node.has_method("set_item"):
		# Left-click drag: full swap
		source_node.set_item(temp_texture, temp_stack_count)
		
		# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
		if source_node.has_method("_stop_drag_cleanup"):
			source_node._stop_drag_cleanup()
		else:
			# Fallback: directly clear drag state if method doesn't exist
			if "is_dragging" in source_node:
				source_node.is_dragging = false
			if "_is_right_click_drag" in source_node:
				source_node._is_right_click_drag = false
			if "drag_preview" in source_node and source_node.drag_preview:
				if source_node.has_method("_cleanup_drag_preview"):
					source_node._cleanup_drag_preview()

	# Emit signal to notify other systems (ToolSwitcher, etc.)
	emit_signal("slot_drop_received", slot_index, data)

	# Sync inventory UI to ensure consistency
	if InventoryManager:
		InventoryManager.sync_inventory_ui()


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
	# Clean up drag preview on invalid drop
	_cleanup_drag_preview()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_callback(_reset_highlight).set_delay(0.2)


func _cleanup_drag_preview() -> void:
	"""Clean up custom drag preview and its layer"""
	if custom_drag_preview:
		var drag_layer = custom_drag_preview.get_parent()
		if drag_layer and drag_layer.name == "InventoryDragPreviewLayer":
			drag_layer.queue_free()
		else:
			custom_drag_preview.queue_free()
		custom_drag_preview = null
		set_process(false)


func _notification(what: int) -> void:
	"""Handle cleanup when slot is removed or drag is cancelled"""
	if what == NOTIFICATION_DRAG_END:
		# Godot calls this when drag ends (success or cancel)
		_cleanup_drag_preview()
	elif what == NOTIFICATION_EXIT_TREE:
		# Clean up if slot is removed while dragging
		_cleanup_drag_preview()


func _receive_drop_from_toolkit(
	dropped_texture: Texture, dropped_stack_count: int, source_slot_index: int, source_node: Node
) -> bool:
	"""Receive a drop from toolkit slot - returns true if successful"""
	
	if is_locked:
		return false
	
	# Get current item and stack count in this slot
	var current_texture: Texture = item_texture
	var current_stack_count: int = stack_count
	
	# Swap items with stack counts
	set_item(dropped_texture, dropped_stack_count)
	if source_node and source_node.has_method("set_item"):
		source_node.set_item(current_texture, current_stack_count)
	
	# Notify InventoryManager
	if InventoryManager:
		InventoryManager.update_inventory_slots(slot_index, dropped_texture, dropped_stack_count)
		if current_texture:
			InventoryManager.add_item_to_toolkit(
				source_slot_index, current_texture, current_stack_count
			)
		else:
			InventoryManager.remove_item_from_toolkit(source_slot_index)
	
	# Emit signal
	var drag_data = {
		"slot_index": source_slot_index,
		"item_texture": dropped_texture,
		"stack_count": dropped_stack_count,
		"source": "toolkit",
		"source_node": source_node
	}
	emit_signal("slot_drop_received", slot_index, drag_data)
	
	return true


## Stack Management Functions


func _create_stack_label() -> void:
	"""Create a label to display stack count"""
	var stack_label = get_node_or_null("StackLabel")
	if not stack_label:
		stack_label = Label.new()
		stack_label.name = "StackLabel"
		stack_label.add_theme_font_size_override("font_size", 16)
		stack_label.add_theme_color_override("font_color", Color.WHITE)
		stack_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		stack_label.add_theme_constant_override("shadow_offset_x", 1)
		stack_label.add_theme_constant_override("shadow_offset_y", 1)
		stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stack_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stack_label)

		# Position in bottom-right corner
		stack_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		stack_label.offset_left = -25
		stack_label.offset_top = -20
		stack_label.offset_right = -3
		stack_label.offset_bottom = -3

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
	var space_available = MAX_INVENTORY_STACK - stack_count
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
	stack_count = clampi(count, 0, MAX_INVENTORY_STACK)
	_update_stack_label()
