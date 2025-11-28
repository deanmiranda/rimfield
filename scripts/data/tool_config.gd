extends Resource
class_name ToolConfig

# Tool mapping from texture to tool name
# Shared resource to avoid duplication (follows .cursor/rules/godot.md)
var tool_map: Dictionary = {
	preload("res://assets/tiles/tools/shovel.png"): "hoe",
	preload("res://assets/tiles/tools/watering-can.png"): "watering_can",
	preload("res://assets/tiles/tools/pick-axe.png"): "pickaxe",
	preload("res://assets/tilesets/full version/tiles/FartSnipSeeds.png"): "seed"
}


func get_tool_name(item_texture: Texture) -> String:
	return tool_map.get(item_texture, "unknown")
