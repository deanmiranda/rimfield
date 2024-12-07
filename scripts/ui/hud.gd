extends CanvasLayer

@export var tool_switcher_path: NodePath
signal tool_changed(slot_index: int, item_texture: Texture)

var farming_manager: Node = null  # Reference to FarmingManager

func _ready() -> void:
# Connect the signal to highlight the active tool
	connect("tool_changed", Callable(self, "_highlight_active_tool"))
	farming_manager =  get_node("../../FarmingManager")
	
	if farming_manager:
		print("Farming Manager found:", farming_manager)
	else:
		print("Error: Farming Manager node not found.")
	# Access ToolSwitcher via sibling relationship
	var tool_switcher = get_node("../ToolSwitcher")
	if tool_switcher:
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_highlight_active_tool")):
			tool_switcher.connect("tool_changed", Callable(self, "_highlight_active_tool"))
	else:
		print("Error: ToolSwitcher not found as sibling.")

	# Dynamically connect signals for each TextureButton node
	var tool_buttons = $MarginContainer/HBoxContainer.get_children()
	for i in range(tool_buttons.size()):
		print("Tool button:", tool_buttons[i], "Children:", tool_buttons[i].get_children())

	for i in range(tool_buttons.size()):
		if tool_buttons[i] is TextureButton:
			var hud_slot = tool_buttons[i].get_node("Hud_slot_" + str(i))
			if hud_slot and hud_slot is TextureRect:  # Adjust for TextureRect
				hud_slot.set_meta("slot_index", i)  # Assign slot index for tracking
				tool_buttons[i].connect("gui_input", Callable(self, "_on_tool_clicked").bind(hud_slot))  # No need to cast
			else:
				print("Error: hud_slot not found or invalid for tool button", i)
	
	# Emit tool_changed for the first slot (slot 0)
	if tool_buttons.size() > 0:
		var first_slot = tool_buttons[0].get_node("Hud_slot_0")
		print("should have first tool assigned", first_slot)
		if first_slot and first_slot.texture:
			emit_signal("tool_changed", 0, first_slot.texture)  # Emit signal with the texture in slot 0
			_update_farming_manager_tool(0, first_slot.texture)  # Sync farming manager with the initial tool
		else:
			print("Warning: No texture in the first slot. Defaulting to empty.")
			emit_signal("tool_changed", 0, null)
		
func set_farming_manager(farming_manager_instance: Node) -> void:
	if farming_manager_instance:
		farming_manager = farming_manager_instance  # Save the reference
	else:
		print("Error: FarmingManager instance is null. Cannot link.")
		
func _update_farming_manager_tool(slot_index: int, item_texture: Texture) -> void:
	print("DEBUG: _update_farming_manager_tool called with index:", slot_index, "and texture:", item_texture)
	if farming_manager:
		farming_manager._on_tool_changed(slot_index, item_texture)
		print("DEBUG: Updated farming manager with tool.")
	else:
		print("ERROR: Farming manager not found.")
	
func _on_tool_clicked(event: InputEvent, clicked_texture_rect: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		if clicked_texture_rect and clicked_texture_rect.has_meta("slot_index"):
			var index = clicked_texture_rect.get_meta("slot_index")
			var parent_button = clicked_texture_rect.get_parent()  # Assuming the parent is the TextureButton
			if parent_button and parent_button is TextureButton:
				var item_texture = parent_button.texture_normal  # Example for retrieving texture
				emit_signal("tool_changed", index, item_texture)
			else:
				print("Error: Parent is not a TextureButton for clicked slot:", index)

func _highlight_active_tool(slot_index: int, _item_texture: Texture) -> void:
	print("DEBUG: _highlight_active_tool called with slot index:", slot_index)
	var tool_buttons = $MarginContainer/HBoxContainer.get_children()
	for i in range(tool_buttons.size()):
		if tool_buttons[i] is TextureButton:
			var highlight = tool_buttons[i].get_node("Highlight")
			if highlight:
				highlight.visible = (i == slot_index)
				if i == slot_index:
					print("DEBUG: Highlighting tool slot:", i)
