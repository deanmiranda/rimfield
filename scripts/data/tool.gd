extends Resource
class_name Tool

# Tool resource class - represents a tool with its properties
# Tools are identified by their texture, not their slot position

@export var tool_name: String = "unknown"  # e.g., "hoe", "pickaxe", "till", "seed"
@export var texture: Texture  # The visual representation of the tool
@export var can_farm: bool = false  # Can this tool be used for farming?
@export var interaction_type: String = "none"  # Type of interaction this tool performs


func _init(p_tool_name: String = "unknown", p_texture: Texture = null):
	tool_name = p_tool_name
	texture = p_texture


func get_tool_name() -> String:
	return tool_name


func get_texture() -> Texture:
	return texture


func is_same_tool(other_tool: Tool) -> bool:
	"""Check if this tool is the same as another tool (by texture)"""
	if not other_tool:
		return false
	return texture == other_tool.texture
