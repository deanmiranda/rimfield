# trash_can.gd
# Trash can drop target for deleting inventory items
# Accepts drops from any container and deletes the item

extends Control

class_name TrashCan

# Visual
@onready var texture_rect: TextureRect = $TextureRect

# Trash can texture
const TRASH_TEXTURE_PATH = "res://assets/ui/trash-can.png"


func _ready() -> void:
	# Set up as drop target
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(64, 64)
	
	# Create texture rect if it doesn't exist
	if not texture_rect:
		texture_rect = TextureRect.new()
		texture_rect.name = "TextureRect"
		texture_rect.texture = load(TRASH_TEXTURE_PATH)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		add_child(texture_rect)
	
	# Load texture
	if not texture_rect.texture:
		texture_rect.texture = load(TRASH_TEXTURE_PATH)


func _gui_input(event: InputEvent) -> void:
	"""Handle mouse input to detect drops from DragManager"""
	if not DragManager:
		return
	
	# Only handle mouse button release when dragging
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			# Left mouse button released - check if we're dragging and mouse is over trash can
			if DragManager.is_dragging:
				_handle_drop()
				accept_event()
				get_viewport().set_input_as_handled()


func _handle_drop() -> void:
	"""Handle drop - delete the item from source container"""
	if not DragManager:
		return
	
	if not DragManager.is_dragging:
		return
	
	# Get drag data
	var source_container = DragManager.drag_source_container
	var source_slot_index = DragManager.drag_source_slot_index
	var drag_texture = DragManager.drag_item_texture
	var drag_count = DragManager.drag_item_count
	var is_right_click = DragManager.is_right_click_drag
	
	if not source_container:
		DragManager.cancel_drag()
		return
	
	# For right-click, only delete 1 item; for left-click, delete all dragged
	var delete_count = drag_count
	if is_right_click:
		delete_count = 1
	
	# Get current source slot data
	if not source_container.has_method("get_slot_data"):
		DragManager.cancel_drag()
		return
	
	var source_data = source_container.get_slot_data(source_slot_index)
	if not source_data or not source_data["texture"]:
		# Empty slot - nothing to delete
		DragManager.cancel_drag()
		return
	
	# Verify it matches drag data
	if source_data["texture"] != drag_texture:
		DragManager.cancel_drag()
		return
	
	# Calculate remaining count after deletion
	var current_count = source_data.get("count", 0)
	var remaining = current_count - delete_count
	
	# Delete from source container
	if remaining > 0:
		# Partial deletion - update count
		if source_container.has_method("set_slot_data"):
			source_container.set_slot_data(source_slot_index, drag_texture, remaining)
		else:
			# Fallback
			source_container.remove_item_from_slot(source_slot_index)
			source_container.add_item_to_slot(source_slot_index, drag_texture, remaining)
	else:
		# Full deletion - remove item
		source_container.remove_item_from_slot(source_slot_index)
	
	# Clear drag state (item deleted, don't restore)
	DragManager.clear_drag_state()
	
	# Refresh UI if container has sync method
	if source_container.has_method("sync_ui"):
		source_container.sync_ui()
	elif source_container.has_method("sync_slot_ui"):
		source_container.sync_slot_ui(source_slot_index)
