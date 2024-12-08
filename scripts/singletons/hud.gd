extends CanvasLayer

@export var tool_switcher_path: NodePath
signal tool_changed(slot_index: int, item_texture: Texture)

var farming_manager: Node = null  # Reference to FarmingManager

func _ready() -> void:
# Connect the signal to highlight the active tool
	connect("tool_changed", Callable(self, "_highlight_active_tool"))
	
	# Connect to UiManager's scene_changed signal
	if UiManager:
		UiManager.connect("scene_changed", Callable(self, "_on_scene_changed"))

	# Check current scene on startup
	_on_scene_changed(get_tree().current_scene.name)

func _on_scene_changed(new_scene_name: String) -> void:
	print("Scene changed to:", new_scene_name)
	if UiManager._is_not_game_scene():
		print("Not in a game scene")
	else:
		print("In a game scene, setting up HUD")
		setup_hud()
		
func setup_hud() -> void:
	var farm_node = get_node_or_null("/root/Farm")  # Adjust to your scene structure
	if farm_node:
		print("Farm node found", farm_node)
		
		farming_manager = get_node_or_null("/root/Farm/FarmingManager")
	else:
		print("Error: Farming Manager node not found.")
		print("Current Scene:", get_tree().current_scene)
#
	# Access ToolSwitcher via sibling relationship
	var tool_switcher = get_node("/root/Farm/Hud/ToolSwitcher")
	if tool_switcher:
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_highlight_active_tool")):
			tool_switcher.connect("tool_changed", Callable(self, "_highlight_active_tool"))
	else:
		print("Error: ToolSwitcher not found as sibling.")

	# Dynamically connect signals for each TextureButton node
	var tool_buttons = get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer").get_children()
	#for i in range(tool_buttons.size()):
		#print("Tool button:", tool_buttons[i], "Children:", tool_buttons[i].get_children())

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
		#print("should have first tool assigned", first_slot)
		if first_slot and first_slot.texture:
			emit_signal("tool_changed", 0, first_slot.texture)  # Emit signal with the texture from Hud_slot_0
			_update_farming_manager_tool(0, first_slot.texture)  # Sync farming manager with the initial tool texture
		else:
			print("Warning: No texture in Hud_slot_0. Defaulting to empty.")
			emit_signal("tool_changed", 0, null)

		
func set_farming_manager(farming_manager_instance: Node) -> void:
	if farming_manager_instance:
		farming_manager = farming_manager_instance  # Save the reference
	else:
		print("Error: FarmingManager instance is null. Cannot link.")
		
func _update_farming_manager_tool(slot_index: int, item_texture: Texture) -> void:
	print("Updating farming manager with slot:", slot_index, "and texture:", item_texture)
	if farming_manager:
		farming_manager._on_tool_changed(slot_index, item_texture)
	else:
		print("Error: Farming manager is not linked.")

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
	var tool_buttons = get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer").get_children()
	for i in range(tool_buttons.size()):
		if tool_buttons[i] is TextureButton:
			var highlight = tool_buttons[i].get_node("Highlight")
			if highlight:
				highlight.visible = (i == slot_index)
			
