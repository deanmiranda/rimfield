extends Node

var grass_layer: TileMapLayer = null
var dirt_layer: TileMapLayer = null
var tilled_layer: TileMapLayer = null
var planted_layer: TileMapLayer = null

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

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not grass_layer or not dirt_layer or not tilled_layer or not planted_layer:
		print("Farming layers not initialized.")
		return

	# Convert mouse position to cell coordinates
	var cell_pos: Vector2i = grass_layer.local_to_map(target_pos)
	var player_cell: Vector2i = grass_layer.local_to_map(player_pos)

	print("Mouse Cell:", cell_pos, "Player Cell:", player_cell)
	if player_cell.distance_to(cell_pos) > 1:
		print("Player is not adjacent to the target cell.")
		return

	# Check which tile layer the cell belongs to and interact accordingly
	if grass_layer.get_cell_source_id(cell_pos) != -1:  # Check if a valid tile exists in grass layer
		print("Interacting with grass tile at: ", cell_pos)
		_on_grass_tile_interacted(cell_pos)
	elif dirt_layer.get_cell_source_id(cell_pos) != -1:  # Check if a valid tile exists in dirt layer
		print("Interacting with dirt tile at: ", cell_pos)
		_on_dirt_tile_interacted(cell_pos)
	elif tilled_layer.get_cell_source_id(cell_pos) != -1:  # Check if a valid tile exists in tilled layer
		print("Interacting with tilled tile at: ", cell_pos)
		_on_tilled_tile_interacted(cell_pos)
	else:
		print("No valid tile found to interact with.")

# Handle grass tile interaction
func _on_grass_tile_interacted(cell_pos: Vector2i) -> void:
	print("Changing grass tile to dirt at: ", cell_pos)
	grass_layer.set_cell(cell_pos, -1)  # Clear grass tile
	dirt_layer.set_cell(cell_pos, 0)  # Set dirt tile (replace `0` with the correct dirt tile ID)

# Handle dirt tile interaction
func _on_dirt_tile_interacted(cell_pos: Vector2i) -> void:
	print("Changing dirt tile to tilled at: ", cell_pos)
	dirt_layer.set_cell(cell_pos, -1)  # Clear dirt tile
	tilled_layer.set_cell(cell_pos, 0)  # Set tilled tile (replace `0` with the correct tilled tile ID)

# Handle tilled tile interaction
func _on_tilled_tile_interacted(cell_pos: Vector2i) -> void:
	print("Changing tilled tile to planted at: ", cell_pos)
	tilled_layer.set_cell(cell_pos, -1)  # Clear tilled tile
	planted_layer.set_cell(cell_pos, 0)  # Set planted tile (replace `0` with the correct planted tile ID)

func _ready() -> void:
	print("FarmingManager is ready in the scene:", get_tree().current_scene.name)
