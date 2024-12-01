extends Node2D

@export var farmable_layer_path: NodePath
@export var tool_switcher_path: NodePath  # To locate ToolSwitcher in the scene
var farmable_layer: TileMapLayer  # The farmable layer to highlight on
var highlight_sprite: Sprite2D  # Visual feedback sprite

@export var highlight_texture: Texture2D
@export var highlight_color: Color = Color(1, 1, 0, 0.5)  # Semi-transparent yellow
@export var tile_size: Vector2 = Vector2(16, 16)  # Adjust to match your tile size

func _ready() -> void:
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer
		if farmable_layer:
			print("Tile Highlighter initialized. Layer:", farmable_layer.name)
		else:
			print("Error: Farmable layer is not a valid TileMapLayer.")
	else:
		print("Farmable layer path is not assigned.")

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
	highlight_sprite.texture = highlight_texture
	highlight_sprite.modulate = highlight_color
	highlight_sprite.visible = false
	highlight_sprite.z_index = 100

func _on_tool_changed(new_tool: String) -> void:
	# This function will be called when the tool changes via keyboard input
	# For now, we are only printing to verify if it's being called.
	print("Tool changed to:", new_tool)

func _process(_delta: float) -> void:
	if not farmable_layer:
		print("Farmable layer is not assigned. Cannot highlight tiles.")
		return

	# Restrict to viewport
	var mouse_position = get_global_mouse_position()
	var viewport_rect = Rect2(Vector2.ZERO, get_viewport().size)
	if not viewport_rect.has_point(get_viewport().get_mouse_position()):
		highlight_sprite.visible = false
		return

	# Calculate tile position
	var local_mouse_position = farmable_layer.to_local(mouse_position)
	var tile_position = farmable_layer.local_to_map(local_mouse_position)
	var tile_world_position = farmable_layer.map_to_local(tile_position)

	# Check if tile is within farmable layer bounds
	if farmable_layer.get_used_rect().has_point(tile_position):
		highlight_sprite.global_position = farmable_layer.to_global(tile_world_position)
		highlight_sprite.visible = true
	else:
		highlight_sprite.visible = false
