extends Node

signal tool_changed(slot_index: int, item_texture: Texture)  # Signal for tool changes

var current_tool_slot: int = -1  # Currently active tool slot index
var current_tool_texture: Texture = null  # Texture of the currently active tool

func _ready() -> void:
	print("ToolSwitcher ready: Connecting tool_changed signal to HUD.")
	
	# Access HUD via sibling relationship
	var hud = get_node("../HUD")
	if hud:
		if not is_connected("tool_changed", Callable(hud, "_highlight_active_tool")):
			connect("tool_changed", Callable(hud, "_highlight_active_tool"))
	else:
		print("Error: HUD not found as sibling.")

func _input(event: InputEvent) -> void:
	# Handle key inputs to switch tools based on slot numbers (1-0)
	for i in range(10):  # Keys 1-0 correspond to HUD slots 0-9
		var action = "ui_hud_" + str(i + 1)
		if i == 9:  # Special case for "0" key (maps to slot 9)
			action = "ui_hud_0"
		if event.is_action_pressed(action):
			set_tool_by_slot(i)

func set_tool_by_slot(slot_index: int) -> void:
	print("Setting tool by slot:", slot_index)

	var hud = get_node("../HUD")
	if not hud:
		print("Error: HUD not found.")
		return

	# Access the TextureButton and list its children
	var button_path = "MarginContainer/HBoxContainer/TextureButton_" + str(slot_index)
	var texture_button = hud.get_node_or_null(button_path)
	
	if texture_button:
		print("Found TextureButton at:", button_path, "Children:", texture_button.get_children())
		
		# Access the Tool_slot_X child
		var slot_path = button_path + "/Tool_slot_" + str(slot_index)
		var tool_slot = hud.get_node_or_null(slot_path)

		if tool_slot:
			print("Tool slot is dean: ", tool_slot)
			var item_texture = tool_slot.get_texture() if tool_slot.has_method("get_texture") else null
			print("item_texture is not found! dean: ", item_texture)
			
			if item_texture:
				print("Tool selected from slot:", slot_index, "Texture:", item_texture)
				current_tool_slot = slot_index
				print("problem area is here dean: ", current_tool_slot);
				current_tool_texture = item_texture
				
				print("or here dean: ", current_tool_slot);
				emit_signal("tool_changed", slot_index, item_texture)
			else:
				print("Tool node in slot ", slot_index, " is empty. Cannot set tool.")
		else:
			print("Tool slot not found at path:", slot_path)
	else:
		print("TextureButton not found at path:", button_path)
