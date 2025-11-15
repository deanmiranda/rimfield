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
	if item_texture:
		# Use shared ToolConfig to map texture to tool name
		if tool_config and tool_config.has_method("get_tool_name"):
			current_tool = tool_config.get_tool_name(item_texture)
		else:
			print("Error: ToolConfig not loaded. Cannot map tool.")
	else:
		print("Error: Tool texture is null. Cannot update tool.")

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	# ============================================
	# CURSOR AI CONFIRMATION: This function is being called
	# ============================================
	var timestamp = Time.get_datetime_string_from_system()
	print("DEBUG: interact_with_tile called - tool:", current_tool, " target_pos:", target_pos, " player_pos:", player_pos)
	print(">>> CURSOR AI: Farming manager is working! Last edit: ", timestamp, " <<<")
	
	if not farmable_layer:
		print("DEBUG: Farmable layer is null!")
		return

	# Convert world position to cell coordinates
	# IMPORTANT: target_pos is in global/world coordinates from MouseUtil
	# TileMapLayer can be a child of any Node2D, so use its own coordinate system
	# Convert world position to TileMapLayer's local coordinates, then to cell coordinates
	var target_local_pos = farmable_layer.to_local(target_pos)
	var target_cell = farmable_layer.local_to_map(target_local_pos)
	
	# Debug: Check TileMapLayer's transform
	var layer_global_pos = farmable_layer.global_position
	var layer_local_pos = farmable_layer.position
	print("DEBUG: Coordinate conversion - target_pos (world):", target_pos, " target_local (TileMapLayer):", target_local_pos, " target_cell:", target_cell)
	print("DEBUG: TileMapLayer transform - global_position:", layer_global_pos, " position:", layer_local_pos)

	# Calculate distance in world coordinates (not cell coordinates)
	# Get the center of the target tile in TileMapLayer's local coordinates, then convert to global
	var target_tile_center_local = farmable_layer.map_to_local(target_cell)
	# Convert to global coordinates using TileMapLayer's transform
	var target_global_pos = farmable_layer.to_global(target_tile_center_local)
	
	# Calculate distance between player and target tile center (both in global coordinates)
	var distance = player_pos.distance_to(target_global_pos)
	
	# interaction_distance is in world units (pixels), not cells
	# For 16x16 tiles, 250px allows interaction with tiles up to ~15 cells away
	print("DEBUG: Distance check - target_global:", target_global_pos, " player_pos:", player_pos, " distance:", distance, " max:", interaction_distance)
	if distance > interaction_distance:
		print("DEBUG: Target too far from player (distance: ", distance, " > max: ", interaction_distance, ")")
		return

	var tile_data = farmable_layer.get_cell_tile_data(target_cell)
	print("DEBUG: Tile data found:", tile_data != null)
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
		print("DEBUG: Tile states - Grass:", is_grass, "Dirt:", is_dirt, "Tilled:", is_tilled, "Planted:", is_planted, "source_id:", source_id)
		
		match current_tool:
			"hoe":
				if is_grass:
					print("DEBUG: Hoe on grass - converting to dirt")
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
				else:
					print("DEBUG: Hoe can only be used on grass (current state doesn't match)")
			"till":
				if is_dirt:
					print("DEBUG: Till on dirt - converting to tilled")
					_set_tile_custom_state(target_cell, TILE_ID_TILLED, "tilled")
				else:
					print("DEBUG: Till can only be used on dirt (current state doesn't match)")
			"pickaxe":
				if is_planted:
					# Pickaxe on planted seed returns to dirt
					print("DEBUG: Pickaxe on planted - converting to dirt")
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
				elif is_tilled:
					# Pickaxe on tilled soil (no seed) returns to dirt
					print("DEBUG: Pickaxe on tilled - converting to dirt")
					_set_tile_custom_state(target_cell, TILE_ID_DIRT, "dirt")
				elif is_dirt:
					# Pickaxe on dirt returns to grass
					print("DEBUG: Pickaxe on dirt - converting to grass")
					_set_tile_custom_state(target_cell, TILE_ID_GRASS, "grass")
				else:
					print("DEBUG: Pickaxe can only be used on planted/tilled/dirt")
			"seed":
				if is_tilled:  # Only allow planting on tilled soil
					print("DEBUG: Seed on tilled - planting")
					_set_tile_custom_state(target_cell, TILE_ID_PLANTED, "planted")
					#_start_growth_cycle(target_cell)
				else:
					print("DEBUG: Seed can only be planted on tilled soil")
	else:
		print("DEBUG: No tile data found for cell:", target_cell)

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
	print("DEBUG: _set_tile_custom_state - Setting cell:", cell, "to tile_id:", tile_id, "state:", _state)
	
	# Verify the cell coordinate before setting
	var cell_before = farmable_layer.get_cell_source_id(cell)
	print("DEBUG: Cell before change - cell:", cell, "source_id:", cell_before)

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
	
	print("DEBUG: Setting cell with source_id:", tile_id, " (source exists:", source_exists, ")")
	
	# Get TileMapLayer configuration for debugging
	var tile_set_source = tile_set.get_source(tile_id)
	if tile_set_source:
		print("DEBUG: TileSet source found - ID:", tile_id, " type:", tile_set_source.get_class())
	
	# Check TileMapLayer's tile size (should be 16x16 based on the scene)
	var tile_size = Vector2i(16, 16)  # Default, but we should verify
	if tile_set:
		# Try to get tile size from the first source
		var first_source = tile_set.get_source(0)
		if first_source and first_source.has_method("get_texture"):
			var texture = first_source.get_texture()
			if texture:
				# For TileSetAtlasSource, tiles are typically the texture size divided by atlas grid
				# But we'll use the default 16x16 for now
				pass
	
	print("DEBUG: TileMapLayer info - name:", farmable_layer.name, " parent:", farmable_layer.get_parent().name if farmable_layer.get_parent() else "null")
	
	# CRITICAL: Check for multiple TileMapLayers
	var parent = farmable_layer.get_parent()
	if parent:
		var all_layers = []
		for child in parent.get_children():
			if child is TileMapLayer:
				all_layers.append(child.name)
		print("DEBUG: *** ALL TileMapLayers found:", all_layers, "***")
	
	print("DEBUG: *** ABOUT TO SET CELL:", cell, "with source_id:", tile_id, "***")
	farmable_layer.set_cell(cell, tile_id, Vector2i(0, 0), 0)
	print("DEBUG: *** CELL SET - checking what's at (0,0):", farmable_layer.get_cell_source_id(Vector2i(0, 0)), "***")
	
	# Verify the cell was set correctly
	var cell_after = farmable_layer.get_cell_source_id(cell)
	var cell_atlas = farmable_layer.get_cell_atlas_coords(cell)
	var cell_alt = farmable_layer.get_cell_alternative_tile(cell)
	print("DEBUG: Cell after change - cell:", cell, "source_id:", cell_after, "atlas_coords:", cell_atlas, "alt:", cell_alt)
	
	# Verify the cell position in world coordinates
	var cell_local_pos = farmable_layer.map_to_local(cell)
	var cell_world_pos = farmable_layer.to_global(cell_local_pos)
	print("DEBUG: Cell position - cell:", cell, "local:", cell_local_pos, "world:", cell_world_pos)
	
	# Double-check: Get the cell at the actual world position to see if it matches
	var check_cell = farmable_layer.local_to_map(farmable_layer.to_local(cell_world_pos))
	print("DEBUG: Verification - world_pos:", cell_world_pos, " converts back to cell:", check_cell, " (should be:", cell, ")")
	
	# Check if the cell actually exists in the TileMapLayer
	var cell_exists = (farmable_layer.get_cell_source_id(cell) != -1)
	print("DEBUG: Cell exists in layer:", cell_exists)
	
	# Check what cell is at (0,0) to see if that's where the tile is actually appearing
	var cell_at_origin = farmable_layer.get_cell_source_id(Vector2i(0, 0))
	print("DEBUG: Cell at origin (0,0) has source_id:", cell_at_origin)
	
	# CRITICAL: Check if the "Grass" layer might be interfering
	# Reuse parent variable from above (already declared at line 227)
	if parent:
		var grass_layer = parent.get_node_or_null("Grass")
		if grass_layer and grass_layer is TileMapLayer:
			var grass_cell_at_origin = grass_layer.get_cell_source_id(Vector2i(0, 0))
			var grass_cell_at_target = grass_layer.get_cell_source_id(cell)
			print("DEBUG: *** Grass layer - cell at (0,0):", grass_cell_at_origin, " cell at target", cell, ":", grass_cell_at_target, "***")
	
	# Verify the cell we just set is actually visible/accessible
	var verify_source = farmable_layer.get_cell_source_id(cell)
	var verify_atlas = farmable_layer.get_cell_atlas_coords(cell)
	print("DEBUG: *** FINAL VERIFICATION - Cell", cell, "has source_id:", verify_source, "atlas:", verify_atlas, "***")

	# Update the GameState for persistence
	if GameState:
		GameState.update_tile_state(cell, _state)
	else:
		print("Error: GameState is null!")

	# Trigger the corresponding emitter for the updated state
	var emitter_scene = _get_emitter_scene(_state)
	if emitter_scene:
		_trigger_dust_at_tile(cell, emitter_scene)
