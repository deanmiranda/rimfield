extends TextureButton

@export var slot_index: int = 0
@export var empty_texture: Texture

#@export var tool_name: String = ""  # Logical name for the tool
#@export var can_farm: bool = false  # Can this tool be used for farming?

signal tool_selected(slot_index: int, item_texture: Texture)  # Signal emitted when the tool is selected
signal slot_drag_started(slot_index: int, item_texture: Texture)  # Signal emitted when drag starts

var item_texture: Texture = null
var stack_count: int = 0  # Stack count (0 = empty, max 9 for toolbelt)
var default_modulate: Color = Color.WHITE
var is_highlighted: bool = false

# Manual drag and drop state
var is_dragging: bool = false
var drag_preview: TextureRect = null
var original_texture: Texture = null  # Store original texture to restore if drop fails
var original_stack_count: int = 0  # Store original stack count to restore if drop fails

const BUTTON_LEFT = 1
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


func get_item() -> Texture:
	"""Get the item texture from child TextureRect"""
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		return hud_slot_rect.texture
	return item_texture


func set_item(new_texture: Texture, count: int = 1) -> void:
	item_texture = new_texture

	# Update stack count
	if new_texture:
		stack_count = maxi(count, 1)  # At least 1 if there's an item
	else:
		stack_count = 0  # No item = no stack

	# TextureButton always shows empty_texture as background
	# Only update child TextureRect (Hud_slot_X) with the item texture
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.texture = item_texture
		# Ensure child doesn't block mouse events - CRITICAL for drag and drop
		hud_slot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Also ensure it doesn't block input by making it non-interactive
		hud_slot_rect.focus_mode = Control.FOCUS_NONE

	_update_stack_label()


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
		return null  # No item to drag

	var drag_data = {
		"slot_index": slot_index,
		"item_texture": item_texture,
		"stack_count": stack_count,
		"source": "toolkit",  # Standardized source identifier
		"source_node": self  # Reference to source slot for swapping
	}

	# Create drag preview
	var drag_preview = TextureRect.new()
	drag_preview.texture = item_texture
	drag_preview.custom_minimum_size = Vector2(64, 64)
	drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
	set_drag_preview(drag_preview)

	emit_signal("slot_drag_started", slot_index, item_texture)
	print("DEBUG: Drag data created and preview set for toolkit slot ", slot_index)
	return drag_data


func _gui_input(event: InputEvent) -> void:
	"""Handle manual drag and drop for toolkit slots"""
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			# Start drag
			_start_drag()
		elif not event.pressed:
			if is_dragging:
				# Stop drag
				_stop_drag()
			else:
				# Click without drag - select this slot (even if empty)
				_select_slot()
	elif event is InputEventMouseMotion and is_dragging:
		# Update drag preview position
		_update_drag_preview_position()


func _start_drag() -> void:
	"""Start manual drag operation"""
	# Sync item_texture with child TextureRect
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		if hud_slot_rect.texture:
			item_texture = hud_slot_rect.texture
		else:
			item_texture = null

	if item_texture == null:
		return  # No item to drag

	is_dragging = true
	original_texture = item_texture
	original_stack_count = stack_count  # Store the stack count

	# Create ghost icon that follows cursor
	drag_preview = _create_drag_preview(item_texture)

	# Hide the item in the slot while dragging
	var hud_slot_rect_node = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect_node and hud_slot_rect_node is TextureRect:
		hud_slot_rect_node.modulate = Color(1, 1, 1, 0.3)  # Make slot semi-transparent

	emit_signal("slot_drag_started", slot_index, item_texture)


func _stop_drag() -> void:
	"""Stop drag and handle drop"""
	if not is_dragging:
		return

	# Get mouse position in viewport coordinates
	var viewport = get_viewport()
	var drop_position = viewport.get_mouse_position()
	var drop_success = _handle_drop(drop_position)

	# Clean up drag preview and its parent layer
	if drag_preview:
		# Find and remove the DragPreviewLayer
		var drag_layer = drag_preview.get_parent()
		if drag_layer and drag_layer.name == "DragPreviewLayer":
			drag_layer.queue_free()  # This will also free the preview
		else:
			drag_preview.queue_free()
		drag_preview = null

	# Restore slot visibility
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	if hud_slot_rect and hud_slot_rect is TextureRect:
		hud_slot_rect.modulate = Color.WHITE

	# If drop failed, restore original texture and count
	if not drop_success:
		set_item(original_texture, original_stack_count)

	is_dragging = false
	original_texture = null
	original_stack_count = 0


func _create_drag_preview(texture: Texture) -> TextureRect:
	"""Create ghost icon that follows cursor - 50% smaller than original"""
	var preview = TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(32, 32)  # 50% smaller (was 64x64)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent ghost
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create a dedicated CanvasLayer on top of everything for the drag preview
	# This ensures it's always visible, even over the pause menu
	var drag_layer = CanvasLayer.new()
	drag_layer.name = "DragPreviewLayer"
	drag_layer.layer = 100  # Very high layer to be above everything
	get_tree().root.add_child(drag_layer)

	# Add preview to the dedicated layer
	drag_layer.add_child(preview)
	preview.z_index = 1000
	preview.z_as_relative = false

	var viewport = get_viewport()
	if viewport:
		var mouse_pos = viewport.get_mouse_position()
		preview.global_position = mouse_pos - Vector2(16, 16)  # Center on cursor (half of 32)

	return preview


func _update_drag_preview_position() -> void:
	"""Update ghost icon position to follow cursor"""
	if drag_preview:
		var viewport = get_viewport()
		if viewport:
			# Use viewport mouse position for UI elements (screen space, not world space)
			var mouse_pos = viewport.get_mouse_position()
			drag_preview.global_position = mouse_pos - Vector2(16, 16)  # Center on cursor (half of 32)


func _handle_drop(drop_position: Vector2) -> bool:
	"""Handle drop at position - toolkit-to-toolkit or toolkit-to-inventory"""

	# Get mouse position in viewport/screen coordinates (UI space, not world space)
	# UI elements use viewport coordinates, not world coordinates
	var viewport = get_viewport()
	var mouse_pos = viewport.get_mouse_position() if viewport else drop_position

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
					# Check if dropping on same slot (no-op)
					if texture_button == self:
						return true  # Return true but don't swap

					# Found a different toolkit slot - swap items
					if texture_button.has_method("_receive_drop"):
						var success = texture_button._receive_drop(
							original_texture, original_stack_count, slot_index, self
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
			. get_node_or_null(
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
						# Create drag data in the format expected by inventory slots
						var drag_data = {
							"slot_index": slot_index,
							"item_texture": original_texture,
							"stack_count": stack_count,
							"source": "toolkit",
							"source_node": self
						}

						# Check if the inventory slot can accept this drop
						if inventory_slot.has_method("can_drop_data"):
							var can_drop = inventory_slot.can_drop_data(mouse_pos, drag_data)
							if can_drop and inventory_slot.has_method("drop_data"):
								# Perform the drop
								inventory_slot.drop_data(mouse_pos, drag_data)
								return true
						else:
							print("DEBUG: Inventory slot ", i, " doesn't have can_drop_data method")
		else:
			print("DEBUG: Could not find inventory grid in pause menu")
	else:
		print("DEBUG: Could not find pause menu")

	return false


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
	dropped_texture: Texture, dropped_stack_count: int, source_slot_index: int, source_node: Node
) -> bool:
	"""Receive a drop from another slot - returns true if successful"""
	print("DEBUG: Receiving drop in toolkit slot ", slot_index, " from slot ", source_slot_index)

	# Get current item and stack count in this slot BEFORE swapping
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	var current_texture: Texture = null
	var current_stack_count: int = stack_count
	if hud_slot_rect and hud_slot_rect is TextureRect:
		current_texture = hud_slot_rect.texture

	# Swap items with stack counts
	set_item(dropped_texture, dropped_stack_count)
	if source_node and source_node.has_method("set_item"):
		source_node.set_item(current_texture, current_stack_count)

	# Notify ToolSwitcher about the swap - update in correct order
	# Update destination slot first (where the dropped tool went)
	# Then update source slot (where the swapped tool went)
	var tool_switcher = _find_tool_switcher()
	if tool_switcher:
		# If the dropped tool is the active tool, it's moving to this slot
		# Update this slot first so active tool follows
		tool_switcher.update_toolkit_slot(slot_index, dropped_texture)
		# Then update the source slot
		tool_switcher.update_toolkit_slot(source_slot_index, current_texture)

	return true


func _highlight_valid_drop() -> void:
	"""Highlight slot as valid drop target"""
	if not is_highlighted:
		is_highlighted = true
		modulate = Color(1.2, 1.2, 1.0, 1.0)  # Slight yellow tint


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
	print("DEBUG: Slot ", slot_index, " clicked - selecting slot")

	# Get current texture (may be null for empty slots)
	var current_texture = get_item()

	# Notify ToolSwitcher to update active slot
	var tool_switcher = _find_tool_switcher()
	if tool_switcher:
		tool_switcher.set_hud_by_slot(slot_index)
	else:
		print("DEBUG: ToolSwitcher not found - cannot select slot")


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

	# Edge case: Dropping on same slot
	if source == "toolkit" and source_slot_index == slot_index:
		return
	# Get current texture and stack count before swapping
	var hud_slot_rect = get_node_or_null("Hud_slot_" + str(slot_index))
	var current_texture: Texture = null
	var current_stack_count: int = stack_count
	if hud_slot_rect and hud_slot_rect is TextureRect:
		current_texture = hud_slot_rect.texture

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

	# Update InventoryManager
	if InventoryManager:
		# Update toolkit tracking
		if from_item_texture:
			InventoryManager.add_item_to_toolkit(slot_index, from_item_texture, from_stack_count)
		else:
			InventoryManager.remove_item_from_toolkit(slot_index)

		# If source was inventory, update inventory tracking
		if source == "inventory" and source_slot_index >= 0:
			InventoryManager.update_inventory_slots(
				source_slot_index, current_texture, current_stack_count
			)


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
	return amount - amount_to_add  # Return overflow


func remove_from_stack(amount: int = 1) -> int:
	"""Remove items from stack, returns amount actually removed"""
	var amount_to_remove = mini(amount, stack_count)
	stack_count -= amount_to_remove
	if stack_count <= 0:
		stack_count = 0
		set_item(null)  # Clear item if stack is empty
	_update_stack_label()
	return amount_to_remove


func get_stack_count() -> int:
	"""Get current stack count"""
	return stack_count


func set_stack_count(count: int) -> void:
	"""Set stack count directly"""
	stack_count = clampi(count, 0, MAX_TOOLBELT_STACK)
	_update_stack_label()
