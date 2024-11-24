extends Node

var grass_layer: TileMapLayer = null
var dirt_layer: TileMapLayer = null
var tilled_layer: TileMapLayer = null
var planted_layer: TileMapLayer = null

func _ready() -> void:
	print("FarmingManager is ready in the scene:", get_tree().current_scene.name)
	log_grass_layer_tiles()
	
func initialize_layers(Grass, Dirt, Tilled, Planted):
	grass_layer = Grass
	dirt_layer = Dirt
	tilled_layer = Tilled
	planted_layer = Planted
	print("Layers initialized. Grass:", Grass, " Dirt:", Dirt, " Tilled:", Tilled, " Planted:", Planted)

func clear_layers() -> void:
	grass_layer = null
	dirt_layer = null
	tilled_layer = null
	planted_layer = null
	print("Layers cleared.")
	
func log_grass_layer_tiles():
	if not grass_layer:
		print("Grass layer is null. Cannot log tiles.")
		return

	print("Logging tiles in the grass layer:")
	for x in range(grass_layer.get_used_rect().size.x):
		for y in range(grass_layer.get_used_rect().size.y):
			var cell_pos = Vector2(x, y)
			var tile_id = grass_layer.get_cell_source_id(cell_pos)
			print("Tile at", cell_pos, ":", tile_id)

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	# Ensure layers are initialized
	if not grass_layer or not dirt_layer or not tilled_layer or not planted_layer:
		print("Farming layers not initialized.")
		return

	# Get the cell position under the mouse
	var cell_pos = grass_layer.local_to_map(target_pos)
	var player_cell = grass_layer.local_to_map(player_pos)

	# Debug info
	print("Mouse clicked at cell:", cell_pos, "| Player at cell:", player_cell)

	# Ensure the player is adjacent to the cell
	if player_cell.distance_to(cell_pos) > 1:
		print("Player is not adjacent to the target cell.")
		return

	# Check if the grass layer has a tile
	var grass_tile_id = grass_layer.get_cell_source_id(cell_pos)
	print("Grass tile ID at", cell_pos, ":", grass_tile_id)

	# Transition logic: Grass → Dirt
	if grass_tile_id != -1:  # Check if the tile exists
		print("Interacting with grass at:", cell_pos)
		
		# Clear the grass tile and add a dirt tile
		grass_layer.set_cell(cell_pos, -1, Vector2.ZERO)  # Clear grass tile
		dirt_layer.set_cell(cell_pos, 0, Vector2.ZERO)  # Add dirt tile with tile ID 0
		print("Dirt tile set at:", cell_pos)
	else:
		print("No valid interaction found.")
