extends TextureButton

@export var slot_index: int = 0
@export var empty_texture: Texture
var item_quantity: int = 0

signal tool_selected(slot_index: int, item_texture: Texture) # Signal emitted when the tool is selected

var item_texture: Texture = null

const BUTTON_LEFT = 1
# hud_slot.gd
signal drag_started(slot_data: Dictionary)
signal item_dropped(slot_index: int, dropped_data: Dictionary)

func _ready() -> void:
	# Initialize the slot with empty or item texture
	if item_texture == null:
		texture_normal = empty_texture
	else:
		texture_normal = item_texture

	# Ensure the node receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_item(new_texture: Texture, quantity: int = 1) -> void:
	item_texture = new_texture
	item_quantity = quantity

	# Update the slot appearance
	if item_texture == null:
		texture_normal = empty_texture
		item_quantity = 0
	else:
		texture_normal = item_texture

	_update_quantity_label()

func _update_quantity_label() -> void:
	var label = $Label  # Replace with the actual path to your Label node
	if item_quantity > 1:
		label.text = str(item_quantity)
		label.visible = true
	else:
		label.text = ""
		label.visible = false

func stack_items(item_type: Texture, quantity: int, source_slot: TextureButton = null) -> bool:
	if item_texture == item_type:
		# Stack items if they match
		item_quantity += quantity
		if source_slot:
			source_slot.set_item(null, 0)  # Clear the source slot
		_update_quantity_label()
		return true
	elif item_texture == null:
		# If the slot is empty, add the item here
		set_item(item_type, quantity)
		if source_slot:
			source_slot.set_item(null, 0)  # Clear the source slot
		return true
	else:
		# Cannot stack, item mismatch
		return false

# hud_slot.gd
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		if item_texture:
			var drag_data = {
				"slot_index": slot_index,
				"item_texture": item_texture,
				"item_quantity": item_quantity
			}
			emit_signal("drag_started", drag_data)
			# Notify tool_selected centrally
			SignalManager.connect_tool_changed(self, self)
		else:
			print("DEBUG: No item to drag in slot", slot_index)
		emit_signal("tool_selected", slot_index)
		

# hud_slot.gd
func drop_data(_mouse_position, data):
	if data.has("item_texture"):
		print("DEBUG: Drop detected. Target slot:", slot_index, "Data:", data)

		if stack_items(data["item_texture"], data["item_quantity"], data.get("source")):
			print("DEBUG: Items stacked successfully.")
		else:
			print("DEBUG: Swapping items in slot:", slot_index)
			var temp_texture = item_texture
			var temp_quantity = item_quantity
			set_item(data["item_texture"], data["item_quantity"])
			if data.has("source") and data["source"].has_method("set_item"):
				data["source"].set_item(temp_texture, temp_quantity)
		# Emit item_dropped signal to notify HUD
		emit_signal("item_dropped", slot_index, data)
