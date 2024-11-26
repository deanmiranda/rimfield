### farming_manager.gd ###
extends Node

@export var farmable_layer_path: NodePath
@export var tool_switcher_path: NodePath

var farmable_layer: TileMapLayer
var tool_switcher: Node

const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2

var current_tool: String = "hoe"

func _ready() -> void:
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer

	if tool_switcher_path:
		tool_switcher = get_node_or_null(tool_switcher_path) as Node
		if tool_switcher and not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
			current_tool = tool_switcher.get("current_tool")

	var hud = get_node("../HUD")
	if hud and not hud.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
		hud.connect("tool_changed", Callable(self, "_on_tool_changed"))

func _on_tool_changed(new_tool: String) -> void:
	current_tool = new_tool

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		return

	var target_cell = farmable_layer.local_to_map(target_pos)
	if target_cell.distance_to(farmable_layer.local_to_map(player_pos)) > 1.5:
		return

	var tile_data = farmable_layer.get_cell_tile_data(target_cell)
	if tile_data:
		var is_grass = tile_data.get_custom_data("grass") == true
		var is_dirt = tile_data.get_custom_data("dirt") == true
		var is_tilled = tile_data.get_custom_data("tilled") == true

		match current_tool:
			"hoe":
				if is_grass:
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
			"till":
				if is_dirt:
					_set_tile_custom_state(target_cell, TILE_ID_TILLED, "tilled")
			"pickaxe":
				if is_tilled:
					_set_tile_custom_state(target_cell, TILE_ID_GRASS, "grass")

func _set_tile_custom_state(cell: Vector2i, tile_id: int, _state: String) -> void:
	farmable_layer.set_cell(cell, tile_id, Vector2i(0, 0))

# --- NEXT STEPS ---
# 1. Refactor interact_with_tile:
#    - Move tile interaction logic into smaller, more reusable functions.
#    - Create a system for queued actions to improve player efficiency (e.g., multi-tile farming).
#
# 2. Add hover/visual feedback:
#    - Highlight tiles as the player moves near them or hovers the mouse for clearer interaction cues.
#
# 3. Expand tool functionality:
#    - Support additional tools and tile types (e.g., watering can for watering crops).
#
# 4. Future-proof paths:
#    - Use a configuration or singleton to centralize node paths, reducing dependency on hardcoded paths.
