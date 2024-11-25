extends Node

# Signal to notify when the tool changes
signal tool_changed(new_tool: String)

@export var tool_label_path: NodePath  # Path to the ToolLabel

const TOOL_HOE = "hoe"
const TOOL_TILL = "till"
const TOOL_PICKAXE = "pickaxe"

var current_tool: String = TOOL_HOE

func _ready() -> void:
	# Ensure the label exists and the initial tool is displayed
	if tool_label_path:
		var label = get_node_or_null(tool_label_path) as Label
		if label:
			label.text = "Current Tool: %s" % current_tool.capitalize()

	# Connect the signal to the _on_tool_changed method
	print("ToolSwitcher initialized with tool:", current_tool)

func _input(event: InputEvent) -> void:
	# Map input actions to tools
	if event.is_action_pressed("ui_tool_hoe"):
		set_tool(TOOL_HOE)
	elif event.is_action_pressed("ui_tool_till"):
		set_tool(TOOL_TILL)
	elif event.is_action_pressed("ui_tool_pickaxe"):
		set_tool(TOOL_PICKAXE)

func set_tool(tool: String) -> void:
	if current_tool != tool:
		current_tool = tool
		emit_signal("tool_changed", current_tool)
		print("Tool switched to:", current_tool)

func _on_tool_changed(new_tool: String) -> void:
	if tool_label_path:
		var label = get_node_or_null(tool_label_path) as Label
		if label:
			label.text = "Current Tool: %s" % new_tool.capitalize()

func get_current_tool() -> String:
	return current_tool
