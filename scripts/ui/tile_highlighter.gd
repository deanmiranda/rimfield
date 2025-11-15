extends Node2D

@export var farmable_layer_path: NodePath
@export var tool_switcher_path: NodePath  # To locate ToolSwitcher in the scene
var farmable_layer: TileMapLayer  # The farmable layer to highlight on
var highlight_sprite: Sprite2D  # Visual feedback sprite

@export var highlight_texture: Texture2D
@export var highlight_color: Color = Color(1, 1, 0, 0.5)  # Semi-transparent yellow
@export var tile_size: Vector2 = Vector2(16, 16)  # Adjust to match your tile size

# Use shared ToolConfig Resource to convert texture to tool name
var tool_config: Resource = null
var current_tool: String = "unknown"  # Track current tool for debugging

func _ready() -> void:
	# Load ToolConfig Resource
	tool_config = load("res://resources/data/tool_config.tres")
	
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer

	# Locate ToolSwitcher and connect its signal to update highlighting
	if tool_switcher_path:
		var tool_switcher = get_node_or_null(tool_switcher_path) as Node
		if tool_switcher:
			if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
				tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
		else:
			print("Error: ToolSwitcher node not found.")

	# Create and configure the highlight sprite
	highlight_sprite = Sprite2D.new()
	add_child(highlight_sprite)
	if highlight_texture:
		highlight_sprite.texture = highlight_texture
	else:
		# Create a simple colored rectangle if no texture is provided
		var image = Image.create(int(tile_size.x), int(tile_size.y), false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 0, 0.5))  # Yellow semi-transparent
		var texture = ImageTexture.create_from_image(image)
		highlight_sprite.texture = texture
	highlight_sprite.modulate = highlight_color
	highlight_sprite.visible = false
	highlight_sprite.z_index = 100

func _on_tool_changed(_slot_index: int, item_texture: Texture) -> void:
	# Signal signature matches tool_changed(slot_index: int, item_texture: Texture)
	# Convert texture to tool name using ToolConfig
	if item_texture and tool_config and tool_config.has_method("get_tool_name"):
		current_tool = tool_config.get_tool_name(item_texture)
		print("Tool changed to:", current_tool, " (slot:", _slot_index, ")")
	else:
		current_tool = "unknown"
		print("Tool changed but texture is null or ToolConfig unavailable")

func _process(_delta: float) -> void:
	if not farmable_layer:
		highlight_sprite.visible = false
		return

	if not highlight_sprite:
		return

	# Restrict to viewport
	var viewport = get_viewport()
	if not viewport:
		highlight_sprite.visible = false
		return
		
	var mouse_position = MouseUtil.get_world_mouse_pos_2d(self)
	var viewport_rect = Rect2(Vector2.ZERO, viewport.size)
	if not viewport_rect.has_point(viewport.get_mouse_position()):
		highlight_sprite.visible = false
		return

	# Calculate tile position
	var local_mouse_position = farmable_layer.to_local(mouse_position)
	var tile_position = farmable_layer.local_to_map(local_mouse_position)
	var tile_world_position = farmable_layer.map_to_local(tile_position)
	
	# Center the highlight on the tile
	tile_world_position += tile_size / 2.0

	# Check if tile is within farmable layer bounds
	var used_rect = farmable_layer.get_used_rect()
	if used_rect.has_point(tile_position):
		highlight_sprite.global_position = farmable_layer.to_global(tile_world_position)
		highlight_sprite.visible = true
	else:
		highlight_sprite.visible = false
