extends Node

signal tool_changed(new_tool: String)  # Explicitly used signal

const TOOL_HOE = "hoe"
const TOOL_TILL = "till"
const TOOL_PICKAXE = "pickaxe"
const TOOL_SEED = "seed"  # Added seed tool

var current_tool: String = TOOL_HOE

func _ready() -> void:
	# Access HUD via sibling relationship
	var hud = get_node("../HUD")
	if hud:
		print("HUD found as sibling:", hud.name)
		if not is_connected("tool_changed", Callable(hud, "_highlight_active_tool")):
			connect("tool_changed", Callable(hud, "_highlight_active_tool"))
	else:
		print("Error: HUD not found as sibling.")

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

# Helper function to check if a node shares the same tree
func is_a_parent(node: Node) -> bool:
	return node and node.get_tree() == get_tree()
