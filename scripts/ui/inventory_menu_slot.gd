# inventory_menu_slot.gd
# Slot for the inventory menu grid (3x10)
# Extensible for future drag/drop functionality

extends TextureButton

@export var slot_index: int = 0
@export var empty_texture: Texture
@export var is_locked: bool = false  # For grayed-out upgrade slots

signal slot_clicked(slot_index: int)
signal slot_drag_started(slot_index: int, item_texture: Texture)
signal slot_drop_received(slot_index: int, data: Dictionary)

var item_texture: Texture = null
var default_modulate: Color = Color.WHITE
var is_highlighted: bool = false
var custom_drag_preview: Control = null  # For high-layer drag preview

# Manual drag system (like toolkit)
var is_dragging: bool = false
var drag_preview: TextureRect = null
var original_texture: Texture = null

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
		modulate = Color(0.5, 0.5, 0.5, 0.7)  # Grayed out
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
	
	# Start with process disabled (enable when dragging)
	set_process(false)
	
	# CRITICAL: Ensure any child nodes (like Border) don't block mouse events
	# Wait a frame for children to be added, then fix their mouse_filter
	call_deferred("_fix_children_mouse_filter")

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

func set_item(new_texture: Texture) -> void:
	"""Set the item texture for this slot"""
	item_texture = new_texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

func get_item() -> Texture:
	"""Get the item texture from this slot"""
	return item_texture

func _gui_input(event: InputEvent) -> void:
	"""Handle manual drag and drop for inventory slots"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start drag if slot has an item and isn't locked
			if item_texture and not is_locked:
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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Right-click for future context menu
		pass

func _start_drag() -> void:
	"""Start manual drag operation"""
	if is_locked or item_texture == null:
		return
	
	is_dragging = true
	original_texture = item_texture
	
	# Create drag preview on high layer
	drag_preview = _create_drag_preview(item_texture)
	
	# Dim the source slot
	modulate = Color(0.5, 0.5, 0.5, 0.7)

func _stop_drag() -> void:
	"""Stop drag operation - cleanup"""
	
	# Get mouse position for drop detection
	var viewport = get_viewport()
	var drop_position = viewport.get_mouse_position()
	var drop_success = _handle_drop(drop_position)
	
	# Clean up drag preview and its parent layer
	if drag_preview:
		var drag_layer = drag_preview.get_parent()
		if drag_layer and drag_layer.name == "InventoryDragPreviewLayer":
			drag_layer.queue_free()
		else:
			drag_preview.queue_free()
		drag_preview = null
	
	# Restore slot appearance
	modulate = default_modulate
	
	# If drop failed, restore original texture
	if not drop_success:
		set_item(original_texture)
	
	is_dragging = false
	original_texture = null

func _create_drag_preview(texture: Texture) -> TextureRect:
	"""Create ghost icon that follows cursor - 50% smaller than original"""
	var preview = TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(32, 32)  # 50% smaller
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent ghost
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create a dedicated CanvasLayer on top of everything
	var drag_layer = CanvasLayer.new()
	drag_layer.name = "InventoryDragPreviewLayer"
	drag_layer.layer = 100  # Very high layer
	get_tree().root.add_child(drag_layer)
	
	# Add preview to the dedicated layer
	drag_layer.add_child(preview)
	preview.z_index = 1000
	preview.z_as_relative = false
	
	var viewport = get_viewport()
	if viewport:
		var mouse_pos = viewport.get_mouse_position()
		preview.global_position = mouse_pos - Vector2(16, 16)
	
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
		var inventory_grid = pause_menu.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid")
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var inventory_slot = inventory_grid.get_child(i)
				if inventory_slot and inventory_slot is TextureButton and inventory_slot != self:
					var slot_rect = inventory_slot.get_global_rect()
					
					if slot_rect.has_point(mouse_pos):
						
						# Check if it's locked
						if inventory_slot.is_locked:
							continue
						
						# Swap items
						var target_texture = inventory_slot.item_texture
						inventory_slot.set_item(original_texture)
						set_item(target_texture)
						
						# Notify InventoryManager
						if InventoryManager:
							InventoryManager.update_inventory_slots(i, original_texture)
							InventoryManager.update_inventory_slots(slot_index, target_texture)
						
						return true
	
	return false

func _find_toolkit_container(node: Node) -> Node:
	# Debug: show what we're searching
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
		"source": "inventory",  # Standardized source identifier
		"source_node": self  # Reference to source slot for swapping
	}
	
	# Create custom drag preview on high layer (like toolkit does)
	# This ensures it's visible above the pause menu (layer 10)
	var drag_layer = CanvasLayer.new()
	drag_layer.name = "InventoryDragPreviewLayer"
	drag_layer.layer = 100  # Very high layer
	get_tree().root.add_child(drag_layer)
	
	var drag_preview = TextureRect.new()
	drag_preview.texture = item_texture
	drag_preview.custom_minimum_size = Vector2(32, 32)  # 50% smaller
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
	invisible_preview.modulate = Color(1, 1, 1, 0)  # Fully transparent
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
		return  # Cannot drop on locked slots
	
	# Edge case: Dragging to same slot (no-op)
	var source_slot_index = data.get("slot_index", -1)
	if data.has("source") and data["source"] == "inventory" and source_slot_index == slot_index:
		return  # Same slot, no-op
	
	var from_item_texture: Texture = data["item_texture"]
	var source_node = data.get("source_node", null)
	
	# Swap items if slot is occupied
	var temp_texture: Texture = item_texture
	set_item(from_item_texture)
	
	# Update source slot if it's a node reference
	if source_node and source_node.has_method("set_item"):
		source_node.set_item(temp_texture)
	# Emit signal to notify InventoryManager
	emit_signal("slot_drop_received", slot_index, data)

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

func _receive_drop_from_toolkit(dropped_texture: Texture, source_slot_index: int, source_node: Node) -> bool:
	"""Receive a drop from toolkit slot - returns true if successful"""
	
	if is_locked:
		return false
	
	# Get current item in this slot
	var current_texture: Texture = item_texture
	
	# Swap items
	set_item(dropped_texture)
	if source_node and source_node.has_method("set_item"):
		source_node.set_item(current_texture)
	
	# Notify InventoryManager
	if InventoryManager:
		InventoryManager.update_inventory_slots(slot_index, dropped_texture)
		if current_texture:
			InventoryManager.add_item_to_toolkit(source_slot_index, current_texture)
		else:
			InventoryManager.remove_item_from_toolkit(source_slot_index)
	
	# Emit signal
	var drag_data = {
		"slot_index": source_slot_index,
		"item_texture": dropped_texture,
		"source": "toolkit",
		"source_node": source_node
	}
	emit_signal("slot_drop_received", slot_index, drag_data)
	
	return true
