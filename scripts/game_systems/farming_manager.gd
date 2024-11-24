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

# Helper function to get all 8 neighboring tiles
func get_neighbors(cell_pos: Vector2) -> Array:
	var neighbors = []
	for x in range(-1, 2):  # Loop through -1, 0, 1 for x
		for y in range(-1, 2):  # Loop through -1, 0, 1 for y
			if x == 0 and y == 0:  # Skip the center cell (current tile)
				continue
			var neighbor_pos = cell_pos + Vector2(x, y)
			neighbors.append(neighbor_pos)
	return neighbors

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not grass_layer or not dirt_layer or not tilled_layer or not planted_layer:
		print("Farming layers not initialized.")
		return

	var target_cell = grass_layer.local_to_map(target_pos)
	var player_cell = grass_layer.local_to_map(player_pos)
	print("Mouse clicked at cell:", target_cell, "| Player at cell:", player_cell)

	# Define the 8 neighboring positions relative to the player
	var neighbors = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),  # Top row
		Vector2i(-1, 0), Vector2i(1, 0),                    # Middle row (left and right only)
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)     # Bottom row
	]

	# Calculate valid neighboring cells
	var valid_neighbors = []
	for offset in neighbors:
		var neighbor = player_cell + offset
		valid_neighbors.append(neighbor)
	print("Valid neighboring tiles:", valid_neighbors)

	# Check if target cell is one of the valid neighbors
	if not valid_neighbors.has(target_cell):
		print("Target cell is not one of the 8 neighboring tiles.")
		return

	# Get grass tile at target position
	var grass_tile_id = grass_layer.get_cell_source_id(target_cell)
	print("Grass tile ID at", target_cell, ":", grass_tile_id)

	if grass_tile_id != -1:  # Grass exists
		print("Interacting with grass at:", target_cell)
		grass_layer.set_cell(target_cell, -1, Vector2.ZERO)  # Clear grass
		dirt_layer.set_cell(target_cell, 0, Vector2.ZERO)  # Add dirt
		print("Dirt tile set at:", target_cell)
	else:
		print("No valid interaction found.")
