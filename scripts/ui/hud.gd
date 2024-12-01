extends CanvasLayer

@export var tool_switcher_path: NodePath
signal tool_changed(new_tool: String)

const TOOL_NAMES = ["hoe", "till", "pickaxe", "seed"]

func _ready() -> void:
	# Connect the signal to highlight the active tool
	connect("tool_changed", Callable(self, "_highlight_active_tool"))

	# Connect to ToolSwitcher signals if path provided
	if tool_switcher_path:
		var tool_switcher = get_node_or_null(tool_switcher_path)
		if tool_switcher and not tool_switcher.is_connected("tool_changed", Callable(self, "_highlight_active_tool")):
			tool_switcher.connect("tool_changed", Callable(self, "_highlight_active_tool"))

	# Dynamically connect signals for each TextureButton node
	var tool_buttons = $MarginContainer/HBoxContainer.get_children()
	for i in range(TOOL_NAMES.size()):
		if i < tool_buttons.size() and tool_buttons[i] is TextureButton:
			var tool_slot = tool_buttons[i]
			tool_slot.set_meta("tool_index", i)
			tool_slot.connect("gui_input", Callable(self, "_on_tool_clicked").bind(tool_slot))

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
