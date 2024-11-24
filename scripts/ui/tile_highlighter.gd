extends Node2D

@export var farmable_layers_paths: Array[NodePath] = []
var farmable_layers: Array[TileMapLayer] = []

var highlight_sprite: Sprite2D
@export var highlight_texture: Texture2D
@export var highlight_color: Color = Color(1, 1, 0, 0.5)  # Semi-transparent yellow
@export var tile_size: Vector2 = Vector2(16, 16)  # Adjust to match your tile size

func _ready() -> void:
	# Resolve the NodePaths into actual node references
	farmable_layers.clear()
	for path in farmable_layers_paths:
		var node = get_node_or_null(path)
		if node and node is TileMapLayer:
			farmable_layers.append(node)
		else:
			print("Invalid NodePath or not a TileMapLayer:", path)

	# Create and configure the highlight sprite
	highlight_sprite = Sprite2D.new()
	add_child(highlight_sprite)
	highlight_sprite.texture = highlight_texture
	highlight_sprite.modulate = highlight_color
	highlight_sprite.visible = false
	highlight_sprite.z_index = 100

func _process(delta: float) -> void:
	if farmable_layers.is_empty():
		print("Farmable layers are not assigned. Cannot highlight tiles.")
		return

	# Restrict to viewport
	var mouse_position = get_global_mouse_position()
	var viewport_rect = Rect2(Vector2.ZERO, get_viewport().size)
	if not viewport_rect.has_point(get_viewport().get_mouse_position()):
		highlight_sprite.visible = false
		return

	var current_tile_position = Vector2.ZERO
	var current_layer = null

	# Check each farmable layer for the hovered tile
	for layer in farmable_layers:
		if not layer or not layer.is_visible_in_tree():
			continue

		# Convert the mouse position to tile coordinates
		var local_mouse_position = layer.to_local(mouse_position)
		var tile_position = layer.local_to_map(local_mouse_position)
		if layer.get_used_rect().has_point(tile_position):
			current_tile_position = tile_position
			current_layer = layer
			break

	if current_layer:
		# Calculate tile world position and update sprite
		var tile_world_position = current_layer.map_to_local(current_tile_position)
		highlight_sprite.global_position = current_layer.to_global(tile_world_position)
		highlight_sprite.visible = true

		# Debugging info
		print("Hovered Tile Position on layer", current_layer.name, ":", current_tile_position)
		print("Highlight Sprite Position:", highlight_sprite.global_position)
	else:
		highlight_sprite.visible = false
		print("No tile hovered.")
