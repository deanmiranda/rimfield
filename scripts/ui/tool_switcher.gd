extends Node

signal tool_changed(new_tool: String)  # Explicitly used signal

@export var tool_label_path: NodePath  # Explicitly validated
@export var hud_path: NodePath  # Add a path to the HUD to connect directly

const TOOL_HOE = "hoe"
const TOOL_TILL = "till"
const TOOL_PICKAXE = "pickaxe"
const TOOL_SEED = "seed"  # Added seed tool

var current_tool: String = TOOL_HOE

func _ready() -> void:
	# Connect the signal to HUD, if the path is set
	if hud_path:
		var hud = get_node_or_null(hud_path)
		if hud:
			# Ensure the signal is connected properly to prevent duplicate connections
			if not hud.is_connected("tool_changed", Callable(hud, "_highlight_active_tool")):
				connect("tool_changed", Callable(hud, "_highlight_active_tool"))


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
