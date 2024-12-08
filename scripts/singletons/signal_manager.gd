extends Node

signal tool_changed(slot_index: int, item_texture: Texture, tool_name: String)

# SignalManager.gd
var TOOL_MAP: Dictionary = {
	preload("res://assets/tiles/tools/shovel.png"): "hoe",
	preload("res://assets/tiles/tools/rototiller.png"): "till",
	preload("res://assets/tiles/tools/pick-axe.png"): "pickaxe",
	preload("res://assets/tilesets/full version/tiles/FartSnipSeeds.png"): "seed"
}

# Utility function to fetch the tool name from a texture
func get_tool_name(item_texture: Texture) -> String:
	return TOOL_MAP.get(item_texture, "unknown")

# Connects the tool_changed signal from emitter to receiver
func connect_tool_changed(emitter: Node, receiver: Node) -> void:
	if not emitter.has_signal("tool_changed"):
		print("ERROR: Emitter does not have 'tool_changed' signal:", emitter.name)
		return
	if not emitter.is_connected("tool_changed", Callable(receiver, "_on_tool_changed")):
		emitter.connect("tool_changed", Callable(receiver, "_on_tool_changed"))
		print("DEBUG: Connected tool_changed from", emitter.name, "to", receiver.name)

# SignalManager connections at runtime
func _ready() -> void:
	# Find FarmingManager and connect it to the signal
	var farming_manager = get_node_or_null("/root/Farm/FarmingManager")
	if farming_manager:
		connect_tool_changed(self, farming_manager)  # Connect SignalManager to FarmingManager

	# Find HUD and connect it to the signal
	var hud = get_node_or_null("/root/Farm/Hud")
	if hud:
		# Connect directly to the HUD's _on_tool_changed method
		if not is_connected("tool_changed", Callable(hud, "_on_tool_changed")):
			connect("tool_changed", Callable(hud, "_on_tool_changed"))
			print("DEBUG: Connected tool_changed signal to HUD's _on_tool_changed")
