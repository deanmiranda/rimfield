### farming_manager.gd ###
extends Node

# Constants (follows .cursor/rules/godot.md script ordering: Signals → Constants → Exports → Vars)
const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2
const TILE_ID_PLANTED = 3
const TILE_ID_GROWN = 4  # Assuming "grown" is the next state after planting

@export var farmable_layer_path: NodePath
@export var farm_scene_path: NodePath  # Reference the farm scene

var hud_instance: Node
var hud_path: Node
var farmable_layer: TileMapLayer
var tool_switcher: Node
var current_tool: String = "hoe"  # Default starting tool

func _ready() -> void:
	# Load shared Resources
	tool_config = load("res://resources/data/tool_config.tres")
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		interaction_distance = game_config.interaction_distance
	
	# Get the farmable layer for tile interactions
	if farmable_layer_path:
		farmable_layer = get_node_or_null(farmable_layer_path) as TileMapLayer
		if not farmable_layer:
			print("Error: Farmable layer not found!")
	 
func set_hud(hud_scene_instance: Node) -> void:
	hud_path = hud_scene_instance
	tool_switcher = hud_scene_instance.get_node("ToolSwitcher")
	
	if tool_switcher:
		# Connect the tool_changed signal
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
		
		# Ensure a valid tool is set on load
		var _first_slot_tool = tool_switcher.get("current_tool")
	else:
		print("Error: ToolSwitcher not found as a child of HUD.")



# Use shared ToolConfig Resource instead of duplicated tool mapping (follows .cursor/rules/godot.md)
var tool_config: Resource = null
# Use shared GameConfig Resource for magic numbers (follows .cursor/rules/godot.md)
var game_config: Resource = null
var interaction_distance: float = 250.0  # Default (will be overridden by GameConfig) - allows up to ~15 cell interaction range

func _on_tool_changed(_slot_index: int, item_texture: Texture) -> void:
	"""Update current_tool based on tool texture - tools are identified by texture, not slot"""
	if item_texture:
		# Use shared ToolConfig to map texture to tool name
		if tool_config and tool_config.has_method("get_tool_name"):
			current_tool = tool_config.get_tool_name(item_texture)
			print("DEBUG: FarmingManager tool changed to: ", current_tool, " (texture-based, not slot-based)")
		else:
			print("Error: ToolConfig not loaded. Cannot map tool.")
			current_tool = "unknown"
	else:
		# Tool texture is null - clear the tool (no tool selected)
		print("DEBUG: FarmingManager tool cleared - no tool in slot")
		current_tool = "unknown"

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		return

	# Convert world position to cell coordinates
	# IMPORTANT: target_pos is in global/world coordinates from MouseUtil
	# TileMapLayer can be a child of any Node2D, so use its own coordinate system
	# Convert world position to TileMapLayer's local coordinates, then to cell coordinates
	var target_local_pos = farmable_layer.to_local(target_pos)
	var target_cell = farmable_layer.local_to_map(target_local_pos)
	
	# Calculate player's tile position
	# IMPORTANT: player_pos is in global/world coordinates (from Camera2D via MouseUtil)
	var player_local_pos = farmable_layer.to_local(player_pos)
	var player_cell = farmable_layer.local_to_map(player_local_pos)
	
	# Debug output to verify coordinates
	print("DEBUG: Player cell: ", player_cell, " Target cell: ", target_cell)
	print("DEBUG: Player world pos: ", player_pos, " Target world pos: ", target_pos)
	
	# Check if target is in the 3x3 grid around player (8 adjacent tiles ONLY, NOT center)
	# Character CANNOT use tools on the tile they're standing on
	# Character can only use tools on tiles directly adjacent (including diagonals)
	# This is cell-based distance, which works correctly with Camera2D since we're using
	# world coordinates converted to tilemap local coordinates
	var cell_distance_x = abs(target_cell.x - player_cell.x)
	var cell_distance_y = abs(target_cell.y - player_cell.y)
	
	print("DEBUG: Cell distance: (", cell_distance_x, ", ", cell_distance_y, ")")
	
	# Prevent interaction with the tile the player is standing on
	if cell_distance_x == 0 and cell_distance_y == 0:
		print("DEBUG: Cannot interact with tile player is standing on")
		return
	
	# Only allow interaction if target is within 1 tile distance (adjacent tiles only)
	# This means max distance of 1 cell in X and Y directions (including diagonals)
	# But NOT the center tile (already checked above)
	if cell_distance_x > 1 or cell_distance_y > 1:
		print("DEBUG: Tile too far - cell distance exceeds 1 tile")
		return

	var tile_data = farmable_layer.get_cell_tile_data(target_cell)
	#if tile_data:
		#print("Tile data found for cell:", target_cell)
		##print("Custom data:", tile_data.get_custom_data())
	#else:
		##print("No tile data found for cell:", target_cell)
		#return

	if tile_data:
		# In Godot 4, get_custom_data() takes the layer name as a String
		# Custom data layers: "grass" (layer 0), "dirt" (layer 1), "tilled" (layer 2)
		# There is no "planted" custom data layer - planted tiles use a different source_id (TILE_ID_PLANTED = 3)
		var is_grass = tile_data.get_custom_data("grass") == true
		var is_dirt = tile_data.get_custom_data("dirt") == true
		var is_tilled = tile_data.get_custom_data("tilled") == true
		# Check if tile is planted by checking the source_id instead of custom_data
		var source_id = farmable_layer.get_cell_source_id(target_cell)
		var is_planted = (source_id == TILE_ID_PLANTED)
		
		# Only perform tool actions if a valid tool is selected (not "unknown")
		# This ensures empty slots don't perform tool actions
		if current_tool == "unknown":
			return  # No tool selected, don't perform any actions
		
		match current_tool:
			"hoe":
				if is_grass:
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
			"till":
				if is_dirt:
					_set_tile_custom_state(target_cell, TILE_ID_TILLED, "tilled")
			"pickaxe":
				if is_planted:
					# Pickaxe on planted seed returns to dirt
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
				elif is_tilled:
					# Pickaxe on tilled soil (no seed) returns to dirt
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
				elif is_dirt:
					# Pickaxe on dirt returns to grass
					_set_tile_custom_state(target_cell, TILE_ID_GRASS, "grass")
			"seed":
				if is_tilled:  # Only allow planting on tilled soil
					_set_tile_custom_state(target_cell, TILE_ID_PLANTED, "planted")
					#_start_growth_cycle(target_cell)

func _get_emitter_scene(state: String) -> Resource:
	# Fetch the correct emitter based on the state
	var farm_scene = get_node_or_null(farm_scene_path)
	if farm_scene:
		match state:
			"dirt":
				return farm_scene.dirt_emitter_scene
			"tilled":
				return farm_scene.tilled_emitter_scene
			"grass":
				return farm_scene.grass_emitter_scene
	return null

func _trigger_dust_at_tile(cell: Vector2i, emitter_scene: Resource) -> void:
	var farm_scene = get_node_or_null(farm_scene_path)
	if farm_scene and farm_scene.has_method("trigger_dust"):
		farm_scene.trigger_dust(cell, emitter_scene)

func _set_tile_custom_state(cell: Vector2i, tile_id: int, _state: String) -> void:

	# Update the visual state
	# In Godot 4, set_cell() automatically uses the custom_data from the TileSet source
	# set_cell(coords, source_id, atlas_coords, alternative_tile)
	# Verify the TileSet has the source_id before setting
	var tile_set = farmable_layer.tile_set
	if not tile_set:
		print("ERROR: TileSet is null!")
		return
	
	# Check if the source_id exists in the TileSet
	var source_exists = tile_set.has_source(tile_id)
	if not source_exists:
		print("ERROR: Source ID ", tile_id, " does not exist in TileSet! Available sources:", tile_set.get_source_count())
		return
	
	farmable_layer.set_cell(cell, tile_id, Vector2i(0, 0), 0)

	# Update the GameState for persistence
	if GameState:
		GameState.update_tile_state(cell, _state)
	else:
		print("Error: GameState is null!")

	# Trigger the corresponding emitter for the updated state
	var emitter_scene = _get_emitter_scene(_state)
	if emitter_scene:
		_trigger_dust_at_tile(cell, emitter_scene)
