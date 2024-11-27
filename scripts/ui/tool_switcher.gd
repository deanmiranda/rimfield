extends Node

signal tool_changed(new_tool: String)  # Explicitly used signal

@export var tool_label_path: NodePath  # Explicitly validated

const TOOL_HOE = "hoe"
const TOOL_TILL = "till"
const TOOL_PICKAXE = "pickaxe"
const TOOL_SEED = "seed"  # Added seed tool

var current_tool: String = TOOL_HOE

func _input(event: InputEvent) -> void:
	# Handle tool switching via input
	if event.is_action_pressed("ui_tool_hoe"):
		set_tool(TOOL_HOE)
	elif event.is_action_pressed("ui_tool_till"):
		set_tool(TOOL_TILL)
	elif event.is_action_pressed("ui_tool_pickaxe"):
		set_tool(TOOL_PICKAXE)
	elif event.is_action_pressed("ui_tool_seed"):  # Add input for seed tool
		set_tool(TOOL_SEED)

func set_tool(tool: String) -> void:
	if current_tool != tool:
		current_tool = tool
		emit_signal("tool_changed", current_tool)

		# Update tool label dynamically if available
		if tool_label_path:
			var tool_label = get_node_or_null(tool_label_path)
			if tool_label:
				tool_label.text = current_tool

# Decision for warning fix:
# `tool_changed` is explicitly used in the signal connection with HUD/FarmingManager.
# Added validation for `tool_label_path` to prevent missing nodes.
