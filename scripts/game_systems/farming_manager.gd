# farming_manager.gd
# Handles tile interactions for farming (grass, dirt, tilled states).

extends Node

@export var farmable_layer_path: NodePath
var farmable_layer: TileMapLayer  # The farmable layer itself

const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2

func _ready() -> void:
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer
		if farmable_layer and farmable_layer.tile_set:
			print("Farmable layer and tileset confirmed:", farmable_layer.name)
		else:
			print("Error: Farmable layer or tileset is not valid.")
	else:
		print("Farmable layer path is not assigned.")

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		print("Farmable layer is not assigned.")
		return

	# Convert mouse position and player position to tile cells
	var target_cell = farmable_layer.local_to_map(target_pos)
	var player_cell = farmable_layer.local_to_map(player_pos)

	print("Mouse clicked at cell:", target_cell, "| Player at cell:", player_cell)

	# Check adjacency (ensure target cell is near the player)
	var distance = target_cell.distance_to(player_cell)
	if distance > 1.5:
		print("Target cell is not within valid range of 8 neighbors.")
		return

	# Retrieve tile data and custom properties
	var tile_data = farmable_layer.get_cell_tile_data(target_cell)
	if tile_data:
		var is_grass = tile_data.get_custom_data("grass") == true
		var is_dirt = tile_data.get_custom_data("dirt") == true
		var is_tilled = tile_data.get_custom_data("tilled") == true

		print("Tile state at", target_cell, ":", {
			"grass": is_grass,
			"dirt": is_dirt,
			"tilled": is_tilled
		})

		# Handle tile interaction based on custom data
		if is_grass:
			print("Interacting with grass. Changing to 'dirt'.")
			_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
		elif is_dirt:
			print("Interacting with dirt. Changing to 'tilled'.")
			_set_tile_custom_state(target_cell, TILE_ID_TILLED, "tilled")
		elif is_tilled:
			print("Interacting with tilled tile. Placeholder for planting.")
		else:
			print("No valid interaction found for the tile.")
	else:
		print("No tile data found at", target_cell)

func _set_tile_custom_state(cell: Vector2i, tile_id: int, state: String) -> void:
	# Update the tile's custom state dynamically
	var tile_data = farmable_layer.get_cell_tile_data(cell)
	if not tile_data:
		print("No tile data found at", cell)
		return

	# Modify tile's state and update its appearance
	tile_data.set_custom_data(state, true)
	farmable_layer.set_cell(cell, tile_id, Vector2i(0, 0))  # Assuming atlas coordinates are (0, 0)
	print("Updated cell:", cell, "to tile_id:", tile_id, "with state:", state)
