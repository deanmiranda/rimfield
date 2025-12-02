extends Resource
class_name ToolConfig

# Tool mapping from texture to tool name
# Shared resource to avoid duplication (follows .cursor/rules/godot.md)
var tool_map: Dictionary = {
	preload("res://assets/tiles/tools/shovel.png"): "hoe",
	preload("res://assets/tiles/tools/watering-can.png"): "watering_can",
	preload("res://assets/tiles/tools/pick-axe.png"): "pickaxe",
	preload("res://assets/tilesets/full version/tiles/FartSnipSeeds.png"): "seed",
	preload("res://assets/icons/chest_icon.png"): "chest",
	preload("res://assets/tilesets/full version/tiles/tiles.png"): "chest", # Also support tiles.png for chest (used with AtlasTexture)
}


func get_tool_name(item_texture: Texture) -> String:
	if not item_texture:
		print("[ToolConfig] get_tool_name: item_texture is null")
		return "unknown"
	
	var texture_path = item_texture.resource_path
	print("[ToolConfig] get_tool_name: texture_path = ", texture_path)
	
	# Check if texture is in tool_map
	if item_texture in tool_map:
		var tool_name = tool_map[item_texture]
		print("[ToolConfig] get_tool_name: Found in tool_map: ", tool_name)
		return tool_name
	
	# Fallback: check by resource path (for AtlasTexture cases)
	for key_texture in tool_map.keys():
		if key_texture and key_texture.resource_path == texture_path:
			var tool_name = tool_map[key_texture]
			print("[ToolConfig] get_tool_name: Found by path match: ", tool_name)
			return tool_name
	
	print("[ToolConfig] get_tool_name: Not found, returning 'unknown'")
	return "unknown"
