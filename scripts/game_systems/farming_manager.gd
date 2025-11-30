### farming_manager.gd ###
extends Node

# ======================================================================
# SAFETY RULE:
# NEVER place control-flow or logic at top-level in Godot scripts.
# Only declarations and functions may exist at class scope.
# ======================================================================

# Energy costs for tool usage
const ENERGY_COST_HOE = 2
const ENERGY_COST_WATERING_CAN = 1
const ENERGY_COST_PICKAXE = 3
const ENERGY_COST_SEED = 1

# Source ID for crop tiles (separate from terrain)
const SOURCE_ID_CROP = 3

# Terrain Set and IDs (configured in FarmingTerrain.tres)
# Terrain Set 0: Soil/Grass transitions
# Terrain 0: Grass (base, no terrain)
# Terrain 1: Soil (light dirt)
# Terrain 2: WetSoil (watered/tilled)
const TERRAIN_SET_ID := 0
const TERRAIN_ID_GRASS := 0
const TERRAIN_ID_SOIL := 1
const TERRAIN_ID_WET_SOIL := 2

# Atlas coordinate constants for manual tile placement (16×16 grid in tiles.png)
const SOURCE_ID := 0
const SOURCE_ID_TERRAIN := 0 # Reuse SOURCE_ID for terrain atlas

# Stardew-style soil visuals - explicit atlas coordinates (no terrain autotiling)
const SOIL_DRY_ATLAS := Vector2i(5, 6) # Plain solid dirt (no grass edge)
const SOIL_WET_ATLAS := Vector2i(5, 9) # Plain wet soil tile
const FARM_BASE_SOIL_ATLAS := Vector2i(12, 0) # Farm base tile - garden ground that can be hoed

@export var farmable_layer_path: NodePath
@export var crop_layer_path: NodePath
@export var farm_scene_path: NodePath
@export var base_ground_layer: TileMapLayer # TileMapLayer where the farm base tile (12, 0) is painted

var hud_instance: Node
var hud_path: Node
var farmable_layer: TileMapLayer
var crop_layer: TileMapLayer
var tool_switcher: Node
var current_tool: String = "hoe"
var farm_scene: Node2D
var tool_config: Resource = null
var game_config: Resource = null
var interaction_distance: float = 250.0

func _ready() -> void:
	print("[FarmingManager] Structure validated. No top-level logic detected.")
	
	tool_config = load("res://resources/data/tool_config.tres")
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		interaction_distance = game_config.interaction_distance
	
	# Note: farmable_layer is now set via set_farmable_layer() from FarmScene
	# Do not resolve via NodePath here to avoid incorrect resolution
	
	if crop_layer_path:
		crop_layer = get_node_or_null(crop_layer_path) as TileMapLayer
		if crop_layer:
			print("[FarmingManager] Crop layer found via path: %s" % crop_layer.name)
	
func set_farmable_layer(layer: TileMapLayer) -> void:
	"""Set farmable layer from FarmScene (validated reference)"""
	farmable_layer = layer
	if farmable_layer and farmable_layer.tile_set:
		print("[FarmingManager] Farmable layer set (TileSet: %s)" % farmable_layer.tile_set.resource_path)
	else:
		push_error("[FarmingManager] Invalid farmable_layer provided - missing TileSet")

func resolve_layers() -> void:
	"""Finalize layer setup after farmable_layer is set"""
	if not farmable_layer:
		push_error("[FarmingManager] Cannot resolve layers - farmable_layer is null")
		return
	print("[FarmingManager] Layers resolved")

func debug_farming_tileset() -> void:
	"""Diagnostic method to extract complete TileSet structure using Godot 4.4 API"""
	var tileset: TileSet = load("res://assets/tilesets/FarmingTerrain.tres")
	
	if tileset == null:
		print("[FARM DEBUG] Failed to load FarmingTerrain.tres")
		return
	
	print("[FARM DEBUG] TileSet loaded: ", tileset)
	
	# 1) Terrain sets
	var terrain_sets: Array = []
	var terrain_sets_count := tileset.get_terrain_sets_count()
	
	for set_id in range(terrain_sets_count):
		var set_mode := tileset.get_terrain_set_mode(set_id)
		var terrains := []
		var terrain_count := tileset.get_terrains_count(set_id)
		
		for terrain_index in range(terrain_count):
			var name := tileset.get_terrain_name(set_id, terrain_index)
			var color := tileset.get_terrain_color(set_id, terrain_index)
			terrains.append({
				"index": terrain_index,
				"name": name,
				"color": color
			})
		
		terrain_sets.append({
			"set_id": set_id,
			"mode": set_mode,
			"terrains": terrains
		})
	
	# 2) Sources and tiles (using Godot 4 TileSet / TileSetAtlasSource API)
	var sources: Array = []
	var source_count := tileset.get_source_count()
	
	for i in range(source_count):
		var source_id := tileset.get_source_id(i)
		var source := tileset.get_source(source_id)
		var source_info := {
			"source_id": source_id,
			"type": source.get_class(),
			"tiles": []
		}
		
		# Only inspect atlas sources for now
		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source
			var texture_path := ""
			if atlas.texture:
				texture_path = atlas.texture.resource_path
			var region_size := atlas.texture_region_size
			
			source_info["texture_path"] = texture_path
			source_info["region_size"] = region_size
			
			var tile_count := atlas.get_tiles_count()
			source_info["tile_count"] = tile_count
			
			for t in range(tile_count):
				var atlas_coords := atlas.get_tile_id(t) # returns Vector2i for atlas coords
				var data := atlas.get_tile_data(atlas_coords, 0) # layer 0
				var terrain := {}
				
				if data:
					terrain["terrain_set"] = data.get_terrain_set()
					terrain["terrain"] = data.get_terrain()
				
				source_info["tiles"].append({
					"index": t,
					"atlas_coords": atlas_coords,
					"terrain": terrain
				})
		
		sources.append(source_info)
	
	# 3) Extract terrain peering/connectivity rules
	var terrain_peering: Array = []
	for set_id in range(terrain_sets_count):
		var terrain_count := tileset.get_terrains_count(set_id)
		var peering_rules := []
		var set_mode := tileset.get_terrain_set_mode(set_id)
		
		# Note: Terrain peering in Godot 4.4 is typically automatic based on mode
		# Mode 0 = Match Corners (3x3 minimal) - handles edges and corners automatically
		# Peering rules are implicit based on terrain assignments on tiles
		for terrain_index in range(terrain_count):
			peering_rules.append({
				"terrain_index": terrain_index,
				"name": tileset.get_terrain_name(set_id, terrain_index),
				"note": "Peering is automatic based on mode %d (Match Corners)" % set_mode
			})
		
		terrain_peering.append({
			"set_id": set_id,
			"mode": set_mode,
			"rules": peering_rules
		})
	
	# 4) Find exact atlas coordinates for Grass, Soil, WetSoil
	var grass_atlas := Vector2i(-1, -1)
	var soil_atlas := Vector2i(-1, -1)
	var wetsoil_atlas := Vector2i(-1, -1)
	
	for source_info in sources:
		if source_info.has("tiles"):
			for tile_info in source_info["tiles"]:
				var terrain_data = tile_info.get("terrain", {})
				var terrain_set = terrain_data.get("terrain_set", -1)
				var terrain_id = terrain_data.get("terrain", -1)
				
				if terrain_set == 0:
					if terrain_id == 0 and grass_atlas == Vector2i(-1, -1):
						grass_atlas = tile_info["atlas_coords"]
					elif terrain_id == 1 and soil_atlas == Vector2i(-1, -1):
						soil_atlas = tile_info["atlas_coords"]
					elif terrain_id == 2 and wetsoil_atlas == Vector2i(-1, -1):
						wetsoil_atlas = tile_info["atlas_coords"]
	
	# 5) Create atlas coordinate → tile mapping
	var atlas_to_tile_mapping := {}
	for source_info in sources:
		if source_info.has("tiles"):
			for tile_info in source_info["tiles"]:
				var coords = tile_info["atlas_coords"]
				atlas_to_tile_mapping[coords] = {
					"source_id": source_info["source_id"],
					"tile_index": tile_info["index"],
					"terrain": tile_info.get("terrain", {})
				}
	
	# Print comprehensive report
	print("[FARM DEBUG] ========================================")
	print("[FARM DEBUG] TileSet loaded: ", tileset)
	print("[FARM DEBUG] ========================================")
	print("[FARM DEBUG] TERRAIN SETS: ", terrain_sets)
	print("[FARM DEBUG] TERRAIN PEERING RULES: ", terrain_peering)
	print("[FARM DEBUG] SOURCES: ", sources)
	print("[FARM DEBUG] ========================================")
	print("[FARM DEBUG] EXACT ATLAS COORDINATES:")
	print("[FARM DEBUG]   Grass (terrain 0): ", grass_atlas)
	print("[FARM DEBUG]   Soil (terrain 1): ", soil_atlas)
	print("[FARM DEBUG]   WetSoil (terrain 2): ", wetsoil_atlas)
	print("[FARM DEBUG] ========================================")
	print("[FARM DEBUG] ATLAS COORDINATE → TILE MAPPING (first 20 entries):")
	var mapping_count = 0
	for coords in atlas_to_tile_mapping.keys():
		if mapping_count < 20:
			print("[FARM DEBUG]   %s -> %s" % [coords, atlas_to_tile_mapping[coords]])
			mapping_count += 1
		else:
			print("[FARM DEBUG]   ... (total mappings: %d)" % atlas_to_tile_mapping.size())
			break
	print("[FARM DEBUG] ========================================")

func _discover_wet_soil_tiles() -> Dictionary:
	"""
	Scan the TileSet to discover all wet soil tiles (terrain_set=0, terrain=2).
	Returns a dictionary of discovered wet soil tiles.
	Note: This function is legacy and may not be used in the current simple system.
	"""
	var wet_tiles_by_shape := {}
	var tileset: TileSet = null
	
	if farmable_layer and farmable_layer.tile_set:
		tileset = farmable_layer.tile_set
	else:
		tileset = load("res://assets/tilesets/FarmingTerrain.tres")
	
	if tileset == null:
		push_warning("[FarmingManager] Cannot discover wet soil tiles: TileSet is null")
		return wet_tiles_by_shape
	
	var source_count := tileset.get_source_count()
	var all_wet_tiles: Array = []
	
	# Scan all sources for wet soil tiles
	for i in range(source_count):
		var source_id := tileset.get_source_id(i)
		var source := tileset.get_source(source_id)
		
		if source is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = source
			var tile_count := atlas.get_tiles_count()
			
			for t in range(tile_count):
				var atlas_coords := atlas.get_tile_id(t)
				var data := atlas.get_tile_data(atlas_coords, 0)
				
				if data:
					var terrain_set = data.get_terrain_set()
					var terrain_id = data.get_terrain()
					
					if terrain_set == TERRAIN_SET_ID and terrain_id == TERRAIN_ID_WET_SOIL:
						all_wet_tiles.append({
							"atlas_coords": atlas_coords,
							"tile_index": t
						})
	
	# Debug output removed - autotile system removed
	
	# Return all discovered wet tiles for manual mapping
	# Legacy function - autotile system removed
	return wet_tiles_by_shape

func set_farm_scene_reference(scene: Node2D) -> void:
	"""Set farm scene reference (alias for set_farm_scene for consistency)"""
	set_farm_scene(scene)

func set_farm_scene(scene: Node2D) -> void:
	farm_scene = scene
	print("[FarmingManager] Farm scene reference set: %s" % (scene.name if scene else "null"))
	
func _apply_terrain_to_cells(cells: Array[Vector2i], terrain_id: int) -> void:
	"""Apply terrain to multiple cells using Godot 4.4 terrain system"""
	if farmable_layer == null:
		push_error("[FarmingManager] Cannot apply terrain - farmable_layer is null")
		return
	
	if cells.is_empty():
		return
	
	# Godot 4.4 TileMapLayer API:
	# set_cells_terrain_connect(cells: Array[Vector2i], terrain_set: int, terrain: int, ignore_empty_terrains := true)
	farmable_layer.set_cells_terrain_connect(cells, TERRAIN_SET_ID, terrain_id)

func _apply_terrain_to_cell(cell: Vector2i, terrain_id: int) -> void:
	"""Apply terrain to a single cell using Godot 4.4 terrain system"""
	_apply_terrain_to_cells([cell], terrain_id)

func apply_terrain_to_cells(cells: Array[Vector2i], terrain_id: int) -> void:
	"""Public API for applying terrain to cells (used by FarmScene)"""
	_apply_terrain_to_cells(cells, terrain_id)

# ============================================================================
# ATLAS COORDINATE-BASED TILE PLACEMENT (for grass edges/corners)
# ============================================================================

func _set_farm_cell(cell: Vector2i, atlas_coords: Vector2i, source_id: int = SOURCE_ID) -> void:
	"""
	Helper to set a farmable layer tile with correct Godot 4.4 TileMapLayer API.
	Signature: set_cell(cell: Vector2i, source_id: int, atlas_coords: Vector2i, alternative_tile := 0)
	"""
	if farmable_layer == null:
		push_error("[FarmingManager] farmable_layer is null in _set_farm_cell")
		return
	farmable_layer.set_cell(cell, source_id, atlas_coords)

# ============================================================================
# FARMABLE CELL CHECKING
# ============================================================================

func is_farmable_cell(cell: Vector2i) -> bool:
	"""
	Check if a cell is farmable (has the farm base tile).
	Any cell in base_ground_layer with FARM_BASE_SOIL_ATLAS is considered farmable.
	"""
	if base_ground_layer == null:
		return false
	
	var source_id := base_ground_layer.get_cell_source_id(cell)
	if source_id != SOURCE_ID_TERRAIN:
		return false
	
	var atlas := base_ground_layer.get_cell_atlas_coords(cell)
	return atlas == FARM_BASE_SOIL_ATLAS

func _restore_farm_base_tile(cell: Vector2i) -> void:
	"""Restore the farm base tile at the given cell"""
	if base_ground_layer == null:
		return
	base_ground_layer.set_cell(cell, SOURCE_ID_TERRAIN, FARM_BASE_SOIL_ATLAS)

# ============================================================================
# STARDEW-STYLE SOIL VISUALS (EXPLICIT ATLAS COORDINATES)
# ============================================================================

func _set_dry_soil_visual(cell: Vector2i) -> void:
	"""Set a cell to dry soil visual using explicit atlas coordinates"""
	if farmable_layer == null:
		return
	farmable_layer.set_cell(cell, SOURCE_ID_TERRAIN, SOIL_DRY_ATLAS)

func _set_wet_soil_visual(cell: Vector2i) -> void:
	"""Set a cell to wet soil visual using explicit atlas coordinates"""
	if farmable_layer == null:
		return
	farmable_layer.set_cell(cell, SOURCE_ID_TERRAIN, SOIL_WET_ATLAS)

# ============================================================================
# SIMPLE SOIL HELPERS (NO AUTOTILING)
# ============================================================================

func create_crop_layer_if_missing() -> void:
	if not farm_scene:
		push_error("[FarmingManager] Cannot create crop layer - farm_scene is null")
		return
	if not farmable_layer:
		push_error("[FarmingManager] Cannot create crop layer - farmable_layer is null")
		return
	if farmable_layer.tile_set == null:
		push_error("[FarmingManager] Cannot create crop layer - farmable_layer.tile_set is null")
		return
	if not crop_layer:
		crop_layer = farm_scene.get_node_or_null("Crops") as TileMapLayer
		if not crop_layer:
			crop_layer = TileMapLayer.new()
			crop_layer.name = "Crops"
			crop_layer.tile_set = farmable_layer.tile_set
			print("[FarmingManager] Crop layer using TileSet from farmable layer")
			farm_scene.add_child(crop_layer)
			crop_layer.set_owner(farm_scene)
			crop_layer.z_index = 1
			print("[FarmingManager] Created crop layer programmatically: %s" % crop_layer.name)
		else:
			print("[FarmingManager] Found existing crop layer: %s" % crop_layer.name)

# ============================================================================
# AUTOTILE FUNCTIONS REMOVED - All legacy autotile code has been deleted
# ============================================================================

func connect_signals() -> void:
	"""Connect FarmingManager to required signals"""
	if GameTimeManager:
		if not GameTimeManager.day_changed.is_connected(_on_day_changed):
			GameTimeManager.day_changed.connect(_on_day_changed)
			print("[FarmingManager] Connected to GameTimeManager.day_changed signal")
		else:
			print("[FarmingManager] Already connected to GameTimeManager.day_changed signal")
	else:
		print("[FarmingManager] Warning: GameTimeManager not found, cannot connect to day_changed signal")

func set_hud(hud_scene_instance: Node) -> void:
	hud_path = hud_scene_instance
	tool_switcher = hud_scene_instance.get_node("ToolSwitcher")
	
	if tool_switcher:
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
		var _first_slot_tool = tool_switcher.get("current_tool")

func _on_tool_changed(_slot_index: int, item_texture: Texture) -> void:
	if item_texture:
		if tool_config and tool_config.has_method("get_tool_name"):
			current_tool = tool_config.get_tool_name(item_texture)
		else:
			current_tool = "unknown"
	else:
		current_tool = "unknown"

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		return
	
	if farmable_layer.tile_set == null:
		push_error("[FarmingManager] farmable_layer.tile_set is NULL — cannot interact.")
		return
	
	print("[FarmingManager] Interacting with tile using farmable_layer: %s, tool: %s" % [farmable_layer.name, current_tool])

	var target_local_pos = farmable_layer.to_local(target_pos)
	var target_cell = farmable_layer.local_to_map(target_local_pos)
	
	var player_local_pos = farmable_layer.to_local(player_pos)
	var player_cell = farmable_layer.local_to_map(player_local_pos)

	var cell_distance_x = abs(target_cell.x - player_cell.x)
	var cell_distance_y = abs(target_cell.y - player_cell.y)
	
	if cell_distance_x == 0 and cell_distance_y == 0:
		return
	
	if cell_distance_x > 1 or cell_distance_y > 1:
		return

	var is_soil := false
	var is_tilled := false
	var is_planted := false
	var tile_state = ""
	
	if GameState:
		tile_state = GameState.get_tile_state(target_cell)
		var tile_data = GameState.get_tile_data(target_cell)
		if tile_data is Dictionary:
			is_soil = tile_state == "soil" or tile_state == "tilled" or tile_state == "planted" or tile_state == "planted_tilled"
			is_tilled = tile_data.get("is_watered", false)
			is_planted = tile_state == "planted" or tile_state == "planted_tilled"
		else:
			is_soil = tile_state == "soil" or tile_state == "tilled" or tile_state == "planted" or tile_state == "planted_tilled"
			is_tilled = false
			is_planted = tile_state == "planted" or tile_state == "planted_tilled"
	
	var energy_cost := 0
	match current_tool:
		"hoe":
			energy_cost = ENERGY_COST_HOE
		"watering_can":
			energy_cost = ENERGY_COST_WATERING_CAN
		"pickaxe":
			energy_cost = ENERGY_COST_PICKAXE
		"seed":
			energy_cost = ENERGY_COST_SEED
		_:
			energy_cost = 0
	
	if PlayerStatsManager and energy_cost > 0:
		if not PlayerStatsManager.consume_energy(energy_cost):
			return
		print("[FarmingManager] Tool '%s' consumed %d energy (remaining: %d/%d)" % [current_tool, energy_cost, PlayerStatsManager.energy, PlayerStatsManager.max_energy])
	
	match current_tool:
		"hoe":
			# First gatekeeper: must be farmable cell
			if not is_farmable_cell(target_cell):
				return
			
			# Only hoe if not already soil
			if GameState:
				tile_state = GameState.get_tile_state(target_cell)
				if tile_state == "soil" or tile_state == "tilled" or tile_state == "planted" or tile_state == "planted_tilled":
					return
			
			# Visual: put dry soil on the farmable layer
			_set_dry_soil_visual(target_cell)
			
			# State: mark as soil in GameState
			if GameState:
				GameState.update_tile_state(target_cell, "soil")
				# Clear any watered flag if it exists
				var tile_data = GameState.get_tile_data(target_cell)
				if tile_data is Dictionary:
					tile_data["is_watered"] = false
					GameState.update_tile_crop_data(target_cell, tile_data)
		"watering_can":
			# First gatekeeper: must be farmable cell
			if not is_farmable_cell(target_cell):
				return
			
			if GameState:
				var tile_data: Variant = GameState.get_tile_data(target_cell)
				tile_state = GameState.get_tile_state(target_cell)
				
				# Only water soil or planted tiles
				if tile_state != "soil" and tile_state != "planted":
					return
				
				if tile_data is Dictionary:
					tile_data["is_watered"] = true
					if GameTimeManager:
						tile_data["last_watered_day"] = GameTimeManager.day
						var current_season = GameTimeManager.season
						var current_year = GameTimeManager.year
						var absolute_day = (current_year - 1) * 112 + current_season * 28 + GameTimeManager.day
						tile_data["last_watered_day_absolute"] = absolute_day
					GameState.update_tile_crop_data(target_cell, tile_data)
				
				# Visual: set wet soil
				_set_wet_soil_visual(target_cell)
				
				# Update state if needed
				if tile_state == "soil":
					GameState.update_tile_state(target_cell, "tilled")
				elif tile_state == "planted":
					GameState.update_tile_state(target_cell, "planted_tilled")
				
				if GameTimeManager:
					GameState.set_tile_watered(target_cell, GameTimeManager.day)
			elif is_planted:
				if tile_state == "planted":
					if GameState:
						var crop_data = GameState.get_tile_data(target_cell)
						if crop_data is Dictionary:
							crop_data["state"] = "planted_tilled"
							if GameTimeManager:
								var current_day = GameTimeManager.day
								var current_season = GameTimeManager.season
								var current_year = GameTimeManager.year
								var absolute_day = (current_year - 1) * 112 + current_season * 28 + current_day
								crop_data["last_watered_day"] = current_day
								crop_data["last_watered_day_absolute"] = absolute_day
								crop_data["is_watered"] = true
								print("[FarmingManager] Setting last_watered_day to %d (absolute: %d) for tile %s" % [current_day, absolute_day, target_cell])
							else:
								print("[FarmingManager] ERROR: GameTimeManager is null, cannot set last_watered_day")
							GameState.update_tile_crop_data(target_cell, crop_data)
							_set_wet_soil_visual(target_cell)
							var current_stage = crop_data.get("current_stage", 0)
							var layer_to_use = crop_layer if crop_layer else farmable_layer
							if layer_to_use:
								layer_to_use.set_cell(target_cell, SOURCE_ID_CROP, Vector2i(current_stage, 0))
							print("[FarmingManager] Watered planted tile at %s (state: planted_tilled, stage %d)" % [target_cell, current_stage])
						else:
							GameState.update_tile_state(target_cell, "planted_tilled")
							if GameState and GameTimeManager:
								GameState.set_tile_watered(target_cell, GameTimeManager.day)
							_set_wet_soil_visual(target_cell)
							var layer_to_use = crop_layer if crop_layer else farmable_layer
							if layer_to_use:
								layer_to_use.set_cell(target_cell, SOURCE_ID_CROP, Vector2i(0, 0))
							print("[FarmingManager] Watered planted tile at %s (fallback path, state: planted_tilled)" % target_cell)
				elif tile_state == "planted_tilled":
					if GameState and GameTimeManager:
						var crop_data = GameState.get_tile_data(target_cell)
						if crop_data is Dictionary:
							var absolute_day = GameTimeManager.get_absolute_day()
							crop_data["last_watered_day"] = GameTimeManager.day
							crop_data["last_watered_day_absolute"] = absolute_day
							crop_data["is_watered"] = true
							GameState.update_tile_crop_data(target_cell, crop_data)
							print("[FarmingManager] Updated watering day for already-watered tile at %s (day: %d, absolute: %d)" % [target_cell, GameTimeManager.day, absolute_day])
						else:
							GameState.set_tile_watered(target_cell, GameTimeManager.get_absolute_day())
							print("[FarmingManager] Tile at %s already watered, updated watering day (fallback)" % target_cell)
		"pickaxe":
			# First gatekeeper: must be farmable cell
			if not is_farmable_cell(target_cell):
				return
			
			# Check current tile state - only clear soil/planted tiles
			var should_clear := false
			if GameState:
				var current_state := GameState.get_tile_state(target_cell)
				# Only perform soil clearing if the state indicates farm soil
				if current_state == "soil" or current_state == "tilled" or current_state == "planted" or current_state == "planted_tilled":
					should_clear = true
			
			# If tile is not soil/planted, do nothing
			if not should_clear:
				return
			
			# Clear crop layer
			if crop_layer:
				crop_layer.erase_cell(target_cell)
			
			# Clear farmable visual (erases the cell so base map shows through)
			if farmable_layer:
				farmable_layer.erase_cell(target_cell)
			
			# Reset GameState - clear tile data so it can be hoed again
			if GameState:
				# Directly set to "grass" string to clear all crop data and watered flags
				# This resets the tile to a neutral state that allows re-hoeing
				GameState.farm_state[target_cell] = "grass"
			
			# Restore farm base tile
			_restore_farm_base_tile(target_cell)
		"seed":
			# First gatekeeper: must be farmable cell
			if not is_farmable_cell(target_cell):
				return
			
			print("[FarmingManager] Seed planting check - is_soil: %s, is_tilled: %s, is_planted: %s, tile_state: %s" % [is_soil, is_tilled, is_planted, tile_state])
			
			# Only plant on soil or wet tiles
			if GameState:
				tile_state = GameState.get_tile_state(target_cell)
				if tile_state != "soil" and tile_state != "tilled":
					return
			
			if not is_planted:
				if tool_switcher and InventoryManager:
					var current_slot_index = tool_switcher.get("current_hud_slot")
					if current_slot_index >= 0:
						var seed_count = InventoryManager.get_toolkit_item_count(current_slot_index)
						print("[FarmingManager] Seed count in slot %d: %d" % [current_slot_index, seed_count])
						if seed_count > 0:
							var new_count = seed_count - 1
							var seed_texture = InventoryManager.get_toolkit_item(current_slot_index)
							if new_count > 0:
								InventoryManager.add_item_to_toolkit(current_slot_index, seed_texture, new_count)
							else:
								InventoryManager.remove_item_from_toolkit(current_slot_index)
							InventoryManager.sync_toolkit_ui()
							print("[FarmingManager] Seed consumed, planting at %s" % target_cell)
							if GameState:
								var crop_data = {
									"state": "planted",
									"crop_id": "carrot",
									"growth_stages": 6,
									"days_per_stage": 1,
									"current_stage": 0,
									"days_watered_toward_next_stage": 0,
									"is_watered": false,
									"last_watered_day": - 1
								}
								GameState.update_tile_crop_data(target_cell, crop_data)
								print("[FarmingManager] Crop data initialized for tile %s (state: planted, is_watered: false)" % target_cell)
								
								# Place crop on crop layer (do NOT modify soil visuals)
								var layer_to_use = crop_layer if crop_layer else farmable_layer
								if layer_to_use:
									layer_to_use.set_cell(target_cell, SOURCE_ID_CROP, Vector2i(0, 0))
									print("[FarmingManager] Crop placed on %s layer at %s (stage 0)" % ["Crops" if crop_layer else "Farmable", target_cell])
								
								GameState.update_tile_state(target_cell, "planted")
							else:
								# Fallback: place crop without GameState (should not happen in normal flow)
								var layer_to_use = crop_layer if crop_layer else farmable_layer
								if layer_to_use:
									layer_to_use.set_cell(target_cell, SOURCE_ID_CROP, Vector2i(0, 0))
							print("[FarmingManager] Planted seed at %s (DRY - must be watered manually)" % target_cell)
						else:
							print("[FarmingManager] No seeds available in toolkit slot")
					else:
						print("[FarmingManager] Invalid toolkit slot index: %d" % current_slot_index)
				else:
					print("[FarmingManager] ToolSwitcher or InventoryManager not available")
			elif is_planted:
				print("[FarmingManager] Cannot plant: tile already has a crop (state: %s)" % tile_state)

# ============================================================================
# OLD HELPERS - Removed (replaced by simple Stardew-style system)
# ============================================================================

func _get_emitter_scene(state: String) -> Resource:
	var farm_scene = get_node_or_null(farm_scene_path)
	if farm_scene:
		match state:
			"soil":
				return farm_scene.dirt_emitter_scene
			"tilled", "planted_tilled":
				return farm_scene.tilled_emitter_scene
			"grass":
				return farm_scene.grass_emitter_scene
	return null

func _trigger_dust_at_tile(cell: Vector2i, emitter_scene: Resource) -> void:
	var farm_scene = get_node_or_null(farm_scene_path)
	if farm_scene and farm_scene.has_method("trigger_dust"):
		farm_scene.trigger_dust(cell, emitter_scene)

func _water_tile(cell: Vector2i) -> void:
	if not GameState or not GameTimeManager:
		return
	var current_day = GameTimeManager.day
	GameState.set_tile_watered(cell, current_day)
	print("[FarmingManager] Watered tile at %s on day %d" % [cell, current_day])

func _on_day_changed(new_day: int, _new_season: int, _new_year: int) -> void:
	print("[FarmingManager] _on_day_changed called - Day: %d, Season: %d, Year: %d" % [new_day, _new_season, _new_year])
	
	if not GameState:
		print("[FarmingManager] Warning: GameState is null, skipping day change processing")
		return
	
	_advance_crop_growth()
	
	if farmable_layer:
		_revert_watered_states()
		GameState.reset_watering_states()
		print("[FarmingManager] Watered states reverted and reset for new day")
	else:
		print("[FarmingManager] Warning: farmable_layer is null, skipping state reversion (farm scene may not be loaded)")
		GameState.reset_watering_states()

func _advance_crop_growth() -> void:
	if not GameState or not GameTimeManager:
		print("[FarmingManager] Cannot advance crop growth: GameState or GameTimeManager is null")
		return
	
	var current_day = GameTimeManager.day
	var current_season = GameTimeManager.season
	var current_year = GameTimeManager.year
	
	var previous_day = current_day - 1
	var previous_season = current_season
	var previous_year = current_year
	
	if previous_day < 1:
		previous_day = 28
		previous_season -= 1
		if previous_season < 0:
			previous_season = 3
			previous_year -= 1
	
	var current_absolute_day = (current_year - 1) * 112 + current_season * 28 + current_day
	var previous_absolute_day = (previous_year - 1) * 112 + previous_season * 28 + previous_day
	
	print("[FarmingManager] Advancing crop growth - current: Day %d, Season %d, Year %d (absolute: %d), checking for crops watered on absolute day %d" % [current_day, current_season, current_year, current_absolute_day, previous_absolute_day])
	
	var crops_checked = 0
	var crops_advanced = 0
	
	for tile_pos in GameState.farm_state.keys():
		var crop_data = GameState.get_tile_data(tile_pos)
		if not (crop_data is Dictionary):
			continue
		
		var tile_state = crop_data.get("state", "")
		if not crop_data.has("crop_id") or (tile_state != "planted" and tile_state != "planted_tilled"):
			continue
		
		crops_checked += 1
		
		var last_watered_absolute = crop_data.get("last_watered_day_absolute", -1)
		var last_watered_day = crop_data.get("last_watered_day", -1)
		
		if last_watered_absolute == -1 and last_watered_day != -1:
			last_watered_absolute = (current_year - 1) * 112 + current_season * 28 + last_watered_day
		
		var was_watered_yesterday = (last_watered_absolute == previous_absolute_day)
		
		if tile_state == "planted_tilled":
			was_watered_yesterday = true
		
		print("[FarmingManager] Crop at %s: state=%s, last_watered_absolute=%d, previous_absolute_day=%d, was_watered_yesterday=%s" % [tile_pos, tile_state, last_watered_absolute, previous_absolute_day, was_watered_yesterday])
		
		if was_watered_yesterday:
			var current_stage = crop_data.get("current_stage", 0)
			var max_stages = crop_data.get("growth_stages", 6)
			var days_per_stage = crop_data.get("days_per_stage", 1)
			var days_watered = crop_data.get("days_watered_toward_next_stage", 0)
			
			days_watered += 1
			
			if days_watered >= days_per_stage and current_stage < (max_stages - 1):
				current_stage += 1
				days_watered = 0
				crops_advanced += 1
				print("[FarmingManager] Crop at %s advanced to stage %d/%d" % [tile_pos, current_stage, max_stages - 1])
			else:
				print("[FarmingManager] Crop at %s: days_watered=%d, days_per_stage=%d, current_stage=%d, max_stages=%d (not ready to advance)" % [tile_pos, days_watered, days_per_stage, current_stage, max_stages])
			
			crop_data["current_stage"] = current_stage
			crop_data["days_watered_toward_next_stage"] = days_watered
			GameState.update_tile_crop_data(tile_pos, crop_data)
			
			_update_crop_visual(tile_pos, current_stage, max_stages)
		else:
			print("[FarmingManager] Crop at %s was not watered yesterday (last_watered_absolute=%d, previous_absolute_day=%d) - no growth" % [tile_pos, last_watered_absolute, previous_absolute_day])
	
	print("[FarmingManager] Crop growth check complete: %d crops checked, %d crops advanced" % [crops_checked, crops_advanced])

func _revert_watered_states() -> void:
	if not GameState:
		print("[FarmingManager] Cannot revert watered states: GameState is null")
		return
	
	if not farmable_layer:
		print("[FarmingManager] Cannot revert watered states: farmable_layer is null")
		return
	
	print("[FarmingManager] Reverting watered states for %d tiles" % GameState.farm_state.size())
	var reverted_count = 0
	
	for tile_pos in GameState.farm_state.keys():
		var tile_data = GameState.get_tile_data(tile_pos)
		var tile_state_str = ""
		
		if not (tile_data is Dictionary):
			tile_state_str = tile_data if tile_data is String else "grass"
		else:
			tile_state_str = tile_data.get("state", "")
		
		if tile_state_str == "tilled":
			if not (tile_data is Dictionary):
				GameState.update_tile_state(tile_pos, "soil")
			else:
				tile_data["state"] = "soil"
				GameState.update_tile_crop_data(tile_pos, tile_data)
			_set_dry_soil_visual(tile_pos)
			print("[FarmingManager] Reverted tilled tile at %s to soil (dry)" % tile_pos)
			reverted_count += 1
		elif tile_state_str == "planted_tilled":
			if tile_data is Dictionary:
				tile_data["state"] = "planted"
				tile_data["is_watered"] = false
				GameState.update_tile_crop_data(tile_pos, tile_data)
				_set_dry_soil_visual(tile_pos)
				var current_stage = tile_data.get("current_stage", 0)
				var max_stages = tile_data.get("growth_stages", 6)
				var layer_to_use = crop_layer if crop_layer else farmable_layer
				if layer_to_use:
					if current_stage >= max_stages - 1:
						layer_to_use.set_cell(tile_pos, SOURCE_ID_CROP, Vector2i(max_stages - 1, 0))
					else:
						layer_to_use.set_cell(tile_pos, SOURCE_ID_CROP, Vector2i(current_stage, 0))
				print("[FarmingManager] Reverted planted_tilled tile at %s to planted (dry, stage %d)" % [tile_pos, current_stage])
				reverted_count += 1
			else:
				GameState.update_tile_state(tile_pos, "planted")
				_set_dry_soil_visual(tile_pos)
				var layer_to_use = crop_layer if crop_layer else farmable_layer
				if layer_to_use:
					layer_to_use.set_cell(tile_pos, SOURCE_ID_CROP, Vector2i(0, 0))
				print("[FarmingManager] Reverted planted_tilled tile at %s to planted (dry, fallback)" % tile_pos)
				reverted_count += 1
	
	print("[FarmingManager] Reverted %d watered tiles to dry state" % reverted_count)

func _update_crop_visual(tile_pos: Vector2i, current_stage: int, max_stages: int) -> void:
	if not farmable_layer:
		print("[FarmingManager] Warning: farmable_layer is null, cannot update crop visual for tile %s" % tile_pos)
		return
	
	var layer_to_use = crop_layer if crop_layer else farmable_layer
	if not layer_to_use:
		return
	
	if current_stage >= max_stages - 1:
		layer_to_use.set_cell(tile_pos, SOURCE_ID_CROP, Vector2i(max_stages - 1, 0))
	else:
		layer_to_use.set_cell(tile_pos, SOURCE_ID_CROP, Vector2i(current_stage, 0))
	
	print("[FarmingManager] Updated crop visual at %s: stage %d on %s layer" % [tile_pos, current_stage, "Crops" if crop_layer else "Farmable"])

# ============================================================================
# TERRAIN-BASED TILE SYSTEM (GODOT BUILT-IN AUTO-TILING)
# ============================================================================

func _set_tile_terrain(tile_pos: Vector2i, terrain_id: int, game_state: String) -> void:
	"""Legacywrapper - use_apply_terrain_to_celldirectlyinstead"""
	if not farmable_layer:
		print("[FarmingManager] ERROR: _set_tile_terrain called but farmable_layer is null")
		return
	
	if farmable_layer.tile_set == null:
		push_error("[FarmingManager] Cannot set terrain - tile_set is null")
		return
	
	# Use terrain-based system - Godot handles all autotiling automatically
	_apply_terrain_to_cell(tile_pos, terrain_id)
	
	if GameState:
		GameState.update_tile_state(tile_pos, game_state)
	
	var emitter_scene = _get_emitter_scene(game_state)
	if emitter_scene:
		_trigger_dust_at_tile(tile_pos, emitter_scene)
	
	print("[FarmingManager] Set tile at %s to terrain_id=%d (state=%s) - Godot handles autotiling" % [tile_pos, terrain_id, game_state])

func _get_tile_state_from_terrain(tile_pos: Vector2i) -> String:
	# Primary: check GameState
	if GameState:
		var state = GameState.get_tile_state(tile_pos)
		if state != "":
			return state
	
	# Fallback: check terrain from TileMap
	if farmable_layer and farmable_layer.tile_set:
		var tile_data = farmable_layer.get_cell_tile_data(tile_pos)
		if tile_data:
			var terrain_set = tile_data.get_terrain_set()
			if terrain_set == TERRAIN_SET_ID:
				var terrain_id = tile_data.get_terrain()
				match terrain_id:
					TERRAIN_ID_GRASS:
						return "grass"
					TERRAIN_ID_SOIL:
						return "soil"
					TERRAIN_ID_WET_SOIL:
						return "tilled"
	
	return "grass"
