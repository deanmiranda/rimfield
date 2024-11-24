extends Node

@export var farmable_layer_path: NodePath
var farmable_layer: TileMapLayer  # The farmable layer itself

const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2

func _ready() -> void:
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer
		if farmable_layer:
			print("Farmable layer initialized:", farmable_layer.name)
		else:
			print("Error: Farmable layer is not a valid TileMapLayer.")
	else:
		print("Farmable layer path is not assigned.")

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		print("Farmable layer is not assigned.")
		return

	var target_cell = farmable_layer.local_to_map(target_pos)
	var player_cell = farmable_layer.local_to_map(player_pos)

	print("Mouse clicked at cell:", target_cell, "| Player at cell:", player_cell)

	# Check distance for neighboring tiles
	var distance = target_cell.distance_to(player_cell)
	print("Distance to player cell:", distance)

	if distance > 1.5:  # Allow slight leeway for floating-point inaccuracies
		print("Target cell is not within valid range of 8 neighbors.")
		return

	# Proceed with tile interaction
	var current_tile_id = farmable_layer.get_cell_source_id(target_cell)
	print("Current Tile ID at", target_cell, ":", current_tile_id)

	match current_tile_id:
		TILE_ID_GRASS:
			print("Interacting with layer:", farmable_layer.name)

			print("Interacting with grass at:", target_cell)
			farmable_layer.set_cell(target_cell, TILE_ID_DIRT)
			print("Tile updated to dirt at:", target_cell)
		TILE_ID_DIRT:
			print("Interacting with dirt at:", target_cell)
			farmable_layer.set_cell(target_cell, TILE_ID_TILLED)
			print("Tile updated to tilled at:", target_cell)
		TILE_ID_TILLED:
			print("Interacting with tilled at:", target_cell)
			# Placeholder for planting logic
			print("Tile remains tilled at:", target_cell)
		_:
			print("No valid interaction found.")

	# Confirm update visually
	var updated_tile_id = farmable_layer.get_cell_source_id(target_cell)
	print("Updated Tile ID at", target_cell, ":", updated_tile_id)
