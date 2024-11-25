# farming_manager.gd
# Handles tile interactions for farming and integrates with ToolSwitcher.

extends Node

@export var farmable_layer_path: NodePath
@export var tool_switcher_path: NodePath
var farmable_layer: TileMapLayer
var tool_switcher: Node

const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2

var current_tool: String = "hoe"  # Default tool, synced with ToolSwitcher

func _ready() -> void:
	# Load the farmable layer
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer
		if not farmable_layer or not farmable_layer.tile_set:
			print("Error: Farmable layer or tileset is not valid.")
	else:
		print("Farmable layer path is not assigned.")

	# Load the tool switcher
	if tool_switcher_path:
		tool_switcher = get_node_or_null(tool_switcher_path)
		if tool_switcher:
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
			current_tool = tool_switcher.get_current_tool()
			print("ToolSwitcher connected. Current tool:", current_tool)
		else:
			print("Error: ToolSwitcher is not a valid node.")
	else:
		print("ToolSwitcher path is not assigned.")

func _on_tool_changed(new_tool: String) -> void:
	# Update the current tool when ToolSwitcher changes
	current_tool = new_tool
	print("FarmingManager: Tool changed to", current_tool)

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		print("Farmable layer is not assigned.")
		return

	var target_cell = farmable_layer.local_to_map(target_pos)
	var player_cell = farmable_layer.local_to_map(player_pos)
	print("Interacting with tile at:", target_cell, "with tool:", current_tool)

	print("Mouse clicked at cell:", target_cell, "| Player at cell:", player_cell)

	if target_cell.distance_to(player_cell) > 1.5:
		print("Target cell is not within valid range of 8 neighbors.")
		return

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

		match current_tool:
			"hoe":
				if is_grass:
					print("Hoeing grass. Changing to dirt.")
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
				else:
					print("Hoe not applicable on this tile.")
			"till":
				if is_dirt:
					print("Tilling dirt. Changing to tilled.")
					_set_tile_custom_state(target_cell, TILE_ID_TILLED, "tilled")
				else:
					print("Tiller not applicable on this tile.")
			"pickaxe":
				if is_tilled:
					print("Using pickaxe on tilled. Changing back to grass.")
					_set_tile_custom_state(target_cell, TILE_ID_GRASS, "grass")
				else:
					print("Pickaxe action not valid for this tile.")
	else:
		print("No tile data found at", target_cell)

func _set_tile_custom_state(cell: Vector2i, tile_id: int, state: String) -> void:
	var tile_data = farmable_layer.get_cell_tile_data(cell)
	if not tile_data:
		print("No tile data found at", cell)
		return

	# Reset all states to false
	tile_data.set_custom_data("grass", false)
	tile_data.set_custom_data("dirt", false)
	tile_data.set_custom_data("tilled", false)
	
	# Set the specific state
	tile_data.set_custom_data(state, true)

	# Update the visual appearance
	farmable_layer.set_cell(cell, tile_id, Vector2i(0, 0))  # Adjust atlas coordinates if needed
	print("Updated cell:", cell, "to tile_id:", tile_id, "with state:", state)

	# Debug: Confirm state change
	var new_tile_data = farmable_layer.get_cell_tile_data(cell)
	print("New tile state at", cell, ":", {
		"grass": new_tile_data.get_custom_data("grass"),
		"dirt": new_tile_data.get_custom_data("dirt"),
		"tilled": new_tile_data.get_custom_data("tilled"),
	})
