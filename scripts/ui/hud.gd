extends CanvasLayer

@export var tool_switcher_path: NodePath
signal tool_changed(new_tool: String)

const TOOL_NAMES = ["hoe", "till", "pickaxe", "seed"]

func _ready() -> void:
	# Connect the signal to highlight the active tool
	connect("tool_changed", Callable(self, "_highlight_active_tool"))

	# Access ToolSwitcher via sibling relationship
	var tool_switcher = get_node("../ToolSwitcher")
	if tool_switcher:
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_highlight_active_tool")):
			tool_switcher.connect("tool_changed", Callable(self, "_highlight_active_tool"))
	else:
		print("Error: ToolSwitcher not found as sibling.")

	# Dynamically connect signals for each TextureButton node
	var tool_buttons = $MarginContainer/HBoxContainer.get_children()
	for i in range(TOOL_NAMES.size()):
		if i < tool_buttons.size() and tool_buttons[i] is TextureButton:
			var tool_slot = tool_buttons[i]
			tool_slot.set_meta("tool_index", i)
			tool_slot.connect("gui_input", Callable(self, "_on_tool_clicked").bind(tool_slot))
			tool_slot.mouse_filter = Control.MOUSE_FILTER_STOP

	# Set default tool as "hoe"
	emit_signal("tool_changed", TOOL_NAMES[0])

func _on_tool_clicked(event: InputEvent, clicked_texture_button: TextureButton) -> void:
	if event is InputEventMouseButton and event.pressed:
		if clicked_texture_button and clicked_texture_button.has_meta("tool_index"):
			var index = clicked_texture_button.get_meta("tool_index")
			if index >= 0 and index < TOOL_NAMES.size():
				emit_signal("tool_changed", TOOL_NAMES[index])

func _highlight_active_tool(new_tool: String) -> void:
	# Update the highlight state for each tool slot
	var tool_buttons = $MarginContainer/HBoxContainer.get_children()
	for i in range(TOOL_NAMES.size()):
		if i < tool_buttons.size() and tool_buttons[i] is TextureButton:
			var highlight = tool_buttons[i].get_node("Highlight")
			if highlight:
				highlight.visible = (TOOL_NAMES[i] == new_tool)

func update_hud() -> void:
	print('update hud reached error on InventoryManager maybe?');
	if InventoryManager:
		print("HUD requesting inventory update...")
		InventoryManager.update_hud_slots(self)
	else:
		print("Error: InventoryManager not found.")
		
# Helper function to check if a node shares the same tree
func is_a_parent(node: Node) -> bool:
	return node and node.get_tree() == get_tree()
