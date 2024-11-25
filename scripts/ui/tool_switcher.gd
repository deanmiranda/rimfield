### tool_switcher.gd ###
extends Node

signal tool_changed(new_tool: String)  # Notify listeners of tool changes

@export var tool_label_path: NodePath

const TOOL_HOE = "hoe"
const TOOL_TILL = "till"
const TOOL_PICKAXE = "pickaxe"

var current_tool: String = TOOL_HOE

func _ready() -> void:
	if tool_label_path:
		var label = get_node_or_null(tool_label_path) as Label
		if label:
			label.text = "Current Tool: %s" % current_tool.capitalize()

	print("ToolSwitcher initialized with tool:", current_tool)

func _input(event: InputEvent) -> void:
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

func get_current_tool() -> String:
	return current_tool
