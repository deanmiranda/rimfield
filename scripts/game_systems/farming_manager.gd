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

# ============================================================================
# ADJACENCY-BASED SOIL AUTOTILING SYSTEM
# ============================================================================
# Approach: Singles, straight paths (N-S / E-W), and 2×2 centers.
# Designed to be extended later with corners, T-junctions, etc.
# Each soil tile's visual is determined by checking its 4 cardinal neighbors.
# ============================================================================

# Atlas coordinate constants for manual tile placement (16×16 grid in tiles.png)
const SOURCE_ID := 0
const GRASS_CENTER := Vector2i(1, 1)
const WET_SOIL_TILE := Vector2i(5, 9)

# ============================================================================
# SOIL AUTOTILING SYSTEM
# ============================================================================
# SoilShape enum defines all possible soil tile shapes based on neighbor patterns.
# Each SoilShape maps to a SOIL_* constant, which contains the exact atlas coordinates.
# 
# Shape Categories:
#   - Singles/BlockCenter: Isolated patches and interior blobs
#   - Middles: Straight path segments (vertical/horizontal, length ≥ 3)
#   - Ends: Path endpoints (1 neighbor)
#   - Corners: 90° L-shaped turns (2 neighbors on perpendicular axes)
#   - T-junctions: 3-way intersections (3 neighbors)
#   - Cross: 4-way intersection (4 neighbors, not a solid blob)
# ============================================================================

# Soil shape types for adjacency-based autotiling
enum SoilShape {
	SINGLE, # Isolated patch, no soil neighbors
	VERT_MIDDLE, # Vertical path middle (soil above & below)
	VERT_END_UP, # Vertical path end at top (soil only below)
	VERT_END_DOWN, # Vertical path end at bottom (soil only above)
	HORZ_MIDDLE, # Horizontal path middle (soil left & right)
	HORZ_END_LEFT, # Horizontal path end pointing left (soil only right)
	HORZ_END_RIGHT, # Horizontal path end pointing right (soil only left)
	T_UP, # T-junction: horizontal bar with leg pointing down (up+left+right)
	T_RIGHT, # T-junction: vertical bar with leg pointing left (up+down+left)
	T_DOWN, # T-junction: horizontal bar with leg pointing up (down+left+right)
	T_LEFT, # T-junction: vertical bar with leg pointing right (up+down+right)
	CORNER_UP_RIGHT, # 90° corner: path goes up and right
	CORNER_UP_LEFT, # 90° corner: path goes up and left
	CORNER_DOWN_RIGHT, # 90° corner: path goes down and right
	CORNER_DOWN_LEFT, # 90° corner: path goes down and left
	CROSS, # 4-way path cross (all 4 neighbors are soil)
	BLOCK_CENTER # Center of 2×2+ area (interior of large soil patches)
}

# ============================================================================
# SOIL ATLAS COORDINATES (Dry Soil Only)
# ============================================================================
# Exact atlas coordinates for each soil shape. These are used by _soil_shape_to_atlas()
# to map SoilShape enum values to the correct tile sprite in the tileset.
# 
# Note: Wet soil uses TERRAIN_ID_WET_SOIL via terrain system, not these coordinates.
# ============================================================================

# Singles/BlockCenter
const SOIL_SINGLE := Vector2i(8, 9) # Isolated 1-tile patch
const SOIL_BLOCK_CENTER := Vector2i(5, 6) # Interior blob tile (no grass edge)

# Straight middles (length ≥ 3)
const SOIL_HORZ_MIDDLE := Vector2i(12, 9) # Middle of horizontal paths
const SOIL_VERT_MIDDLE := Vector2i(12, 8) # Middle of vertical paths

# Line ends (1 neighbor)
const SOIL_HORZ_END_LEFT := Vector2i(10, 6) # Horizontal end pointing left
const SOIL_HORZ_END_RIGHT := Vector2i(9, 6) # Horizontal end pointing right
const SOIL_VERT_END_UP := Vector2i(13, 6) # Vertical end at top
const SOIL_VERT_END_DOWN := Vector2i(13, 11) # Vertical end at bottom

# Corners (L-shapes, 2 neighbors on perpendicular axes)
# Each corner tile shows an L-shaped path with grass on the opposite diagonal
# CORNER_UP_LEFT: path goes up and left, grass on bottom-right
const SOIL_CORNER_UP_LEFT := Vector2i(10, 15)
# CORNER_UP_RIGHT: path goes up and right, grass on bottom-left
const SOIL_CORNER_UP_RIGHT := Vector2i(12, 14)
# CORNER_DOWN_LEFT: path goes down and left, grass on top-right
const SOIL_CORNER_DOWN_LEFT := Vector2i(13, 15)
# CORNER_DOWN_RIGHT: path goes down and right, grass on top-left
const SOIL_CORNER_DOWN_RIGHT := Vector2i(13, 12)

# T-junctions (3-way intersections, DRY soil)
# The shape name is based on the MISSING side:
# T_UP    → neighbors on Right, Down, Left  (open upwards)  → horizontal path with road coming from bottom
# T_DOWN  → neighbors on Up, Left, Right    (open downwards) → horizontal path with road coming from top
# T_LEFT  → neighbors on Up, Right, Down    (open left)      → vertical path with road from right
# T_RIGHT → neighbors on Up, Left, Down     (open right)     → vertical path with road from left
const SOIL_T_UP := Vector2i(10, 18) # T with leg pointing down
const SOIL_T_DOWN := Vector2i(12, 18) # T with leg pointing up
const SOIL_T_LEFT := Vector2i(13, 19) # T with leg pointing right
const SOIL_T_RIGHT := Vector2i(13, 21) # T with leg pointing left

# Wet T-junction variants (not yet used by code; documented for future)
const WET_T_UP := Vector2i(11, 18)
const WET_T_DOWN := Vector2i(13, 18)
const WET_T_LEFT := Vector2i(13, 20)
const WET_T_RIGHT := Vector2i(13, 22)

# Cross (4-way intersection)
const SOIL_CROSS := Vector2i(13, 17) # 4-way path intersection

# Debug toggle for soil autotiling (set to true to enable verbose logging)
const DEBUG_SOIL_AUTOTILE := false

# Offsets to check when retiling soil (self + 4 cardinals)
const SOIL_NEIGHBOR_OFFSETS := [
	Vector2i(0, 0), # self
	Vector2i(0, -1), # up
	Vector2i(0, 1), # down
	Vector2i(-1, 0), # left
	Vector2i(1, 0) # right
]

# (Old tilling stages and edge/corner constants removed - using SoilShape system now)

@export var farmable_layer_path: NodePath
@export var crop_layer_path: NodePath
@export var farm_scene_path: NodePath

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
# SOIL AUTOTILING HELPERS
# ============================================================================

func _is_soil_cell(cell: Vector2i) -> bool:
	"""
	Check if a cell contains any soil tile (dry or wet).
	Returns true for all soil shapes and wet soil terrain, false for grass or other tiles.
	
	This function checks both:
	1. Terrain ID (for wet soil via TERRAIN_ID_WET_SOIL)
	2. Atlas coordinates (for dry soil shapes)
	
	This ensures that watering and planting don't break soil adjacency logic.
	"""
	if farmable_layer == null:
		return false
	
	# Check terrain ID first (handles wet soil)
	if farmable_layer.tile_set:
		var tile_data = farmable_layer.get_cell_tile_data(cell)
		if tile_data:
			var terrain_set = tile_data.get_terrain_set()
			if terrain_set == TERRAIN_SET_ID:
				var terrain_id = tile_data.get_terrain()
				if terrain_id == TERRAIN_ID_SOIL or terrain_id == TERRAIN_ID_WET_SOIL:
					return true
	
	# Check atlas coordinates for dry soil shapes
	var sid := farmable_layer.get_cell_source_id(cell)
	if sid != SOURCE_ID:
		return false
	
	var atlas := farmable_layer.get_cell_atlas_coords(cell)
	
	# Comprehensive set of all dry soil atlas coordinates
	var soil_atlas_coords: Array[Vector2i] = [
		# Singles/BlockCenter
		SOIL_SINGLE,
		SOIL_BLOCK_CENTER,
		# Middles
		SOIL_VERT_MIDDLE,
		SOIL_HORZ_MIDDLE,
		# Ends
		SOIL_VERT_END_UP,
		SOIL_VERT_END_DOWN,
		SOIL_HORZ_END_LEFT,
		SOIL_HORZ_END_RIGHT,
		# T-junctions
		SOIL_T_UP,
		SOIL_T_DOWN,
		SOIL_T_LEFT,
		SOIL_T_RIGHT,
		# Corners
		SOIL_CORNER_UP_RIGHT,
		SOIL_CORNER_UP_LEFT,
		SOIL_CORNER_DOWN_RIGHT,
		SOIL_CORNER_DOWN_LEFT,
		# Cross
		SOIL_CROSS
	]
	return atlas in soil_atlas_coords

func _compute_soil_shape(cell: Vector2i) -> int:
	"""
	Determine which SoilShape to use for this tile based on 4-way neighbors.
	
	Neighbors:
	  up    = (0, -1)
	  down  = (0,  1)
	  left  = (-1, 0)
	  right = (1,  0)
	
	Rules (checked in order by neighbor count):
	  1. 0 neighbors → SINGLE
	  2. 1 neighbor → END piece (VERT_END_UP, VERT_END_DOWN, HORZ_END_LEFT, HORZ_END_RIGHT)
	  3. 2 neighbors:
		 - Same axis (up+down or left+right) → VERT_MIDDLE or HORZ_MIDDLE
		 - Perpendicular axes (corners) → CORNER_* variants
	  4. 3 neighbors → T-junction (T_UP, T_DOWN, T_LEFT, T_RIGHT)
	  5. 4 neighbors:
		 - If all 4 diagonals are also soil → BLOCK_CENTER (solid field interior)
		 - Otherwise → CROSS (true 4-way path intersection)
	  6. Fallback → SINGLE with warning (should not happen in normal patterns)
	"""
	var has_up: bool = _is_soil_cell(cell + Vector2i(0, -1))
	var has_down: bool = _is_soil_cell(cell + Vector2i(0, 1))
	var has_left: bool = _is_soil_cell(cell + Vector2i(-1, 0))
	var has_right: bool = _is_soil_cell(cell + Vector2i(1, 0))
	
	var neighbor_count: int = 0
	if has_up:
		neighbor_count += 1
	if has_down:
		neighbor_count += 1
	if has_left:
		neighbor_count += 1
	if has_right:
		neighbor_count += 1
	
	# 1) 0 neighbors → SINGLE
	if neighbor_count == 0:
		return SoilShape.SINGLE
	
	# 2) 1 neighbor → END piece
	if neighbor_count == 1:
		if has_up and not has_down and not has_left and not has_right:
			# Only neighbor is above → this is the bottom end of a vertical segment
			return SoilShape.VERT_END_DOWN
		elif has_down and not has_up and not has_left and not has_right:
			# Only neighbor is below → this is the top end of a vertical segment
			return SoilShape.VERT_END_UP
		elif has_left and not has_up and not has_down and not has_right:
			# Only neighbor is left → this is the right end of a horizontal segment
			return SoilShape.HORZ_END_RIGHT
		elif has_right and not has_up and not has_down and not has_left:
			# Only neighbor is right → this is the left end of a horizontal segment
			return SoilShape.HORZ_END_LEFT
	
	# 3) 2 neighbors
	if neighbor_count == 2:
		# 3a) Straight vertical: up + down (no left, no right)
		# Path continues vertically through this tile
		if has_up and has_down and not has_left and not has_right:
			return SoilShape.VERT_MIDDLE
		
		# 3b) Straight horizontal: left + right (no up, no down)
		# Path continues horizontally through this tile
		if has_left and has_right and not has_up and not has_down:
			return SoilShape.HORZ_MIDDLE
		
		# 3c) Corners (perpendicular axes - exactly 2 neighbors on different axes)
		# Corner tiles show an L-shaped path with grass on the opposite diagonal
		# CORNER_UP_RIGHT: path goes up and right, grass on bottom-left
		if has_up and has_right and not has_down and not has_left:
			return SoilShape.CORNER_UP_RIGHT
		# CORNER_UP_LEFT: path goes up and left, grass on bottom-right
		elif has_up and has_left and not has_down and not has_right:
			return SoilShape.CORNER_UP_LEFT
		# CORNER_DOWN_RIGHT: path goes down and right, grass on top-left
		elif has_down and has_right and not has_up and not has_left:
			return SoilShape.CORNER_DOWN_RIGHT
		# CORNER_DOWN_LEFT: path goes down and left, grass on top-right
		elif has_down and has_left and not has_up and not has_right:
			return SoilShape.CORNER_DOWN_LEFT
	
	# 4) 3 neighbors → T-junctions
	if neighbor_count == 3:
		# Missing up → T_UP (horizontal bar with leg pointing down)
		if not has_up:
			return SoilShape.T_UP
		# Missing right → T_RIGHT (vertical bar with leg pointing left)
		elif not has_right:
			return SoilShape.T_RIGHT
		# Missing down → T_DOWN (horizontal bar with leg pointing up)
		elif not has_down:
			return SoilShape.T_DOWN
		# Missing left → T_LEFT (vertical bar with leg pointing right)
		elif not has_left:
			return SoilShape.T_LEFT
	
	# 5) 4 neighbors → CROSS or BLOCK_CENTER
	if neighbor_count == 4:
		# Check diagonals to distinguish path intersections from solid field interiors
		var has_up_left: bool = _is_soil_cell(cell + Vector2i(-1, -1))
		var has_up_right: bool = _is_soil_cell(cell + Vector2i(1, -1))
		var has_down_left: bool = _is_soil_cell(cell + Vector2i(-1, 1))
		var has_down_right: bool = _is_soil_cell(cell + Vector2i(1, 1))
		
		# If all four diagonals are also soil, this is an interior cell of a solid field
		if has_up_left and has_up_right and has_down_left and has_down_right:
			return SoilShape.BLOCK_CENTER
		else:
			# True 4-way path intersection (at least one diagonal is grass)
			return SoilShape.CROSS
	
	# 6) Fallback (should not happen in normal patterns)
	var pattern: String = ""
	if has_up:
		pattern += "U"
	if has_right:
		pattern += "R"
	if has_down:
		pattern += "D"
	if has_left:
		pattern += "L"
	if pattern == "":
		pattern = "none"
	push_warning("[SOIL] Unmatched neighbor pattern at %s: pattern=%s count=%d" % [cell, pattern, neighbor_count])
	return SoilShape.SINGLE

func _get_corner_atlas_for_shape(shape: SoilShape) -> Vector2i:
	"""
	Centralized helper to map corner SoilShape values to their atlas coordinates.
	This makes the SOIL_CORNER_* constants the single source of truth for corner mapping.
	"""
	match shape:
		SoilShape.CORNER_UP_LEFT:
			return SOIL_CORNER_UP_LEFT
		SoilShape.CORNER_UP_RIGHT:
			return SOIL_CORNER_UP_RIGHT
		SoilShape.CORNER_DOWN_LEFT:
			return SOIL_CORNER_DOWN_LEFT
		SoilShape.CORNER_DOWN_RIGHT:
			return SOIL_CORNER_DOWN_RIGHT
		_:
			push_warning("[SOIL] Requested corner atlas for non-corner shape: %s" % [SoilShape.keys()[shape]])
			return SOIL_SINGLE # safe fallback

func _soil_shape_to_atlas(shape: int) -> Vector2i:
	"""
	Map a SoilShape enum value to its exact atlas coordinates.
	
	This function provides a one-to-one mapping from SoilShape to SOIL_* constants.
	All shapes must be explicitly handled; the default case should only trigger
	for unexpected/debug scenarios.
	"""
	match shape:
		# Singles/BlockCenter
		SoilShape.SINGLE:
			return SOIL_SINGLE
		SoilShape.BLOCK_CENTER:
			return SOIL_BLOCK_CENTER
		
		# Middles (straight paths)
		SoilShape.VERT_MIDDLE:
			return SOIL_VERT_MIDDLE
		SoilShape.HORZ_MIDDLE:
			return SOIL_HORZ_MIDDLE
		
		# Ends (1 neighbor)
		SoilShape.VERT_END_UP:
			return SOIL_VERT_END_UP
		SoilShape.VERT_END_DOWN:
			return SOIL_VERT_END_DOWN
		SoilShape.HORZ_END_LEFT:
			return SOIL_HORZ_END_LEFT
		SoilShape.HORZ_END_RIGHT:
			return SOIL_HORZ_END_RIGHT
		
		# Corners (2 neighbors on perpendicular axes) - use centralized helper
		SoilShape.CORNER_UP_RIGHT:
			return _get_corner_atlas_for_shape(shape)
		SoilShape.CORNER_UP_LEFT:
			return _get_corner_atlas_for_shape(shape)
		SoilShape.CORNER_DOWN_RIGHT:
			return _get_corner_atlas_for_shape(shape)
		SoilShape.CORNER_DOWN_LEFT:
			return _get_corner_atlas_for_shape(shape)
		
		# T-junctions (3 neighbors)
		SoilShape.T_UP:
			return SOIL_T_UP
		SoilShape.T_RIGHT:
			return SOIL_T_RIGHT
		SoilShape.T_DOWN:
			return SOIL_T_DOWN
		SoilShape.T_LEFT:
			return SOIL_T_LEFT
		
		# Cross (4 neighbors, not a solid blob)
		SoilShape.CROSS:
			return SOIL_CROSS
		
		# Default case (should not happen in normal patterns)
		_:
			push_warning("[SOIL] Unknown SoilShape value: %d, defaulting to SINGLE" % shape)
			return SOIL_SINGLE

func _debug_dump_soil_tile(cell: Vector2i, shape: int, neighbors: String, atlas: Vector2i) -> void:
	"""
	Debug helper to log soil tile information.
	Used by _retile_soil_around() for debugging autotiling decisions.
	Enhanced logging for corner shapes to verify visual correctness.
	Only prints when DEBUG_SOIL_AUTOTILE is enabled.
	"""
	if not DEBUG_SOIL_AUTOTILE:
		return
	
	var shape_name: String = SoilShape.keys()[shape]
	
	# Enhanced logging for corner shapes to help verify visual correctness
	if shape == SoilShape.CORNER_UP_LEFT or shape == SoilShape.CORNER_UP_RIGHT or \
	   shape == SoilShape.CORNER_DOWN_LEFT or shape == SoilShape.CORNER_DOWN_RIGHT:
		var corner_desc: String = ""
		match shape:
			SoilShape.CORNER_UP_LEFT:
				corner_desc = "UP+LEFT (grass on bottom-right)"
			SoilShape.CORNER_UP_RIGHT:
				corner_desc = "UP+RIGHT (grass on bottom-left)"
			SoilShape.CORNER_DOWN_LEFT:
				corner_desc = "DOWN+LEFT (grass on top-right)"
			SoilShape.CORNER_DOWN_RIGHT:
				corner_desc = "DOWN+RIGHT (grass on top-left)"
		print("[SOIL CORNER] cell=%s pattern=%s shape=%s (%s) atlas=%s" % [cell, neighbors, shape_name, corner_desc, atlas])
	else:
		print("[SOIL] retile at %s: shape=%s atlas=%s neighbors=%s" % [cell, shape_name, atlas, neighbors])

func _get_neighbor_string(cell: Vector2i) -> String:
	"""
	Helper to build a neighbor pattern string (e.g., "URD" for up+right+down).
	Used for debugging and logging.
	"""
	var pattern: String = ""
	if _is_soil_cell(cell + Vector2i(0, -1)):
		pattern += "U"
	if _is_soil_cell(cell + Vector2i(1, 0)):
		pattern += "R"
	if _is_soil_cell(cell + Vector2i(0, 1)):
		pattern += "D"
	if _is_soil_cell(cell + Vector2i(-1, 0)):
		pattern += "L"
	if pattern == "":
		pattern = "none"
	return pattern

func _retile_soil_around(cell: Vector2i) -> void:
	"""
	Update soil tiles around the given cell (self + 4 cardinals).
	For each soil tile in the area, recompute its shape based on neighbors
	and update its visual accordingly.
	"""
	if farmable_layer == null:
		return
	
	for offset in SOIL_NEIGHBOR_OFFSETS:
		var c: Vector2i = cell + offset
		
		# Only retile if this cell is already soil
		if not _is_soil_cell(c):
			continue
		
		# Compute the appropriate shape for this cell
		var shape := _compute_soil_shape(c)
		var atlas := _soil_shape_to_atlas(shape)
		
		# Update the tile
		_set_farm_cell(c, atlas)
		
		# Debug logging
		var neighbors: String = _get_neighbor_string(c)
		_debug_dump_soil_tile(c, shape, neighbors, atlas)

# ============================================================================
# CORNER DIAGNOSTIC HELPERS
# ============================================================================

func debug_log_corner_for_cell(cell: Vector2i) -> void:
	"""
	Debug helper to diagnose corner mapping for a specific cell.
	Logs neighbor pattern, computed SoilShape, and assigned atlas coordinates.
	"""
	if farmable_layer == null:
		print("[SOIL CORNER DEBUG] Cannot diagnose: farmable_layer is null")
		return
	
	# 1) Compute neighbor flags using the same logic as _compute_soil_shape()
	var has_up: bool = _is_soil_cell(cell + Vector2i(0, -1))
	var has_down: bool = _is_soil_cell(cell + Vector2i(0, 1))
	var has_left: bool = _is_soil_cell(cell + Vector2i(-1, 0))
	var has_right: bool = _is_soil_cell(cell + Vector2i(1, 0))
	
	# 2) Call the existing helper to compute SoilShape
	var shape := _compute_soil_shape(cell)
	
	# 3) Determine atlas coords via _soil_shape_to_atlas()
	var atlas_coords := _soil_shape_to_atlas(shape)
	
	# 4) Build neighbor pattern string (sorted: U, R, D, L for consistency)
	var pattern: String = ""
	if has_up:
		pattern += "U"
	if has_right:
		pattern += "R"
	if has_down:
		pattern += "D"
	if has_left:
		pattern += "L"
	if pattern == "":
		pattern = "none"
	
	# 5) Print diagnostic message
	var shape_name: String = SoilShape.keys()[shape]
	
	if shape == SoilShape.CORNER_UP_LEFT or shape == SoilShape.CORNER_UP_RIGHT or \
	   shape == SoilShape.CORNER_DOWN_LEFT or shape == SoilShape.CORNER_DOWN_RIGHT:
		print("[SOIL CORNER DEBUG] cell=%s neighbors=%s shape=%s atlas=%s" % [cell, pattern, shape_name, atlas_coords])
	else:
		print("[SOIL CORNER DEBUG] cell=%s neighbors=%s shape=%s (not a corner) atlas=%s" % [cell, pattern, shape_name, atlas_coords])

func debug_log_corners_around_player() -> void:
	"""
	Debug helper to log all corner shapes in a region around the player.
	Scans a 7x7 area centered on the player's current tile position.
	"""
	if OS.is_debug_build() == false:
		return
	
	if farmable_layer == null:
		print("[SOIL CORNER DEBUG] Cannot scan: farmable_layer is null")
		return
	
	# Find player's current tile cell
	var player_node = get_tree().current_scene.get_node_or_null("Player")
	if player_node == null:
		print("[SOIL CORNER DEBUG] Cannot find player node")
		return
	
	var player_body = player_node.get_node_or_null("Player")
	if player_body == null:
		print("[SOIL CORNER DEBUG] Cannot find player CharacterBody2D")
		return
	
	var player_world_pos = player_body.global_position
	var player_local_pos = farmable_layer.to_local(player_world_pos)
	var player_cell = farmable_layer.local_to_map(player_local_pos)
	
	# Scan a 7x7 region around the player
	var scan_radius = 3
	print("[SOIL CORNER DEBUG] Scanning 7x7 region around player at cell %s" % player_cell)
	
	for y_offset in range(-scan_radius, scan_radius + 1):
		for x_offset in range(-scan_radius, scan_radius + 1):
			var cell = player_cell + Vector2i(x_offset, y_offset)
			
			# Only check cells that are soil
			if _is_soil_cell(cell):
				var shape := _compute_soil_shape(cell)
				# Only log if it's a corner shape
				if shape == SoilShape.CORNER_UP_LEFT or shape == SoilShape.CORNER_UP_RIGHT or \
				   shape == SoilShape.CORNER_DOWN_LEFT or shape == SoilShape.CORNER_DOWN_RIGHT:
					debug_log_corner_for_cell(cell)

# ============================================================================
# OLD HELPERS - Removed (replaced by SoilShape autotiling system)
# ============================================================================
# - _apply_single_soil_patch() - replaced by _set_farm_cell + _retile_soil_around
# - _get_tilled_stage() - no longer needed
# - _set_tilled_stage() - no longer needed  
# - _has_tilled_neighbor() - replaced by _is_soil_cell checks in _compute_soil_shape
# - _rebuild_dirt_cluster_around() - replaced by _retile_soil_around
# ============================================================================

# (Old _rebuild_dirt_cluster_around removed - replaced by simpler _retile_soil_around)

func create_crop_layer_if_missing() -> void:
	"""Create crop layer if it doesn't exist (only after farmable layer validation)"""
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

	# With terrain-based system, we can place tiles anywhere in the farmable layer
	# No need to check source_id - terrain system handles placement automatically
	if not farmable_layer:
		print("[FarmingManager] BLOCKED: Farmable layer is null")
		return

	var tile_state = "grass"
	if GameState:
		tile_state = GameState.get_tile_state(target_cell)
	
	var is_grass = (tile_state == "grass")
	var is_soil = (tile_state == "soil")
	var is_planted = (tile_state == "planted" or tile_state == "planted_tilled")
	var is_tilled = (tile_state == "tilled")
	
	if current_tool == "unknown":
		return
	
	if PlayerStatsManager and PlayerStatsManager.energy <= 0:
		return
	
	var energy_cost = 0
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
			print("[HOE] target cell: %s" % target_cell)
			
			# Check if this is a valid grass tile to hoe (re-check actual tile, not just GameState)
			var current_atlas := farmable_layer.get_cell_atlas_coords(target_cell)
			is_grass = (current_atlas == GRASS_CENTER) # Reuse existing is_grass variable
			var is_already_soil := _is_soil_cell(target_cell)
			
			if is_grass or is_already_soil:
				# Place initial soil tile (use SINGLE as starting point)
				_set_farm_cell(target_cell, SOIL_SINGLE)
				
				# Update GameState for save/load compatibility
				if GameState:
					GameState.update_tile_state(target_cell, "soil")
				
				# Retile this cell and its neighbors using adjacency-based autotiling
				# This handles: singles, straight paths (N-S/E-W), and 2×2 centers
				_retile_soil_around(target_cell)
				
				if DEBUG_SOIL_AUTOTILE:
					print("[HOE] Applied soil at ", target_cell, " and retiled neighbors")
			else:
				# Not a valid tile to hoe (rock, water, etc.)
				print("[HOE] Cannot hoe tile at ", target_cell, " - not grass or soil")
		"watering_can":
			if is_soil:
				# Soil -> wet soil
				_apply_terrain_to_cell(target_cell, TERRAIN_ID_WET_SOIL)
				if GameState and GameTimeManager:
					GameState.update_tile_state(target_cell, "tilled")
					GameState.set_tile_watered(target_cell, GameTimeManager.day)
					var current_day = GameTimeManager.day
					var absolute_day = GameTimeManager.get_absolute_day()
					print("[FarmingManager] Watered soil tile at %s (state: tilled, day: %d, absolute: %d)" % [target_cell, current_day, absolute_day])
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
							_apply_terrain_to_cell(target_cell, TERRAIN_ID_WET_SOIL)
							var current_stage = crop_data.get("current_stage", 0)
							var layer_to_use = crop_layer if crop_layer else farmable_layer
							if layer_to_use:
								layer_to_use.set_cell(target_cell, SOURCE_ID_CROP, Vector2i(current_stage, 0))
							print("[FarmingManager] Watered planted tile at %s (state: planted_tilled, stage %d)" % [target_cell, current_stage])
						else:
							GameState.update_tile_state(target_cell, "planted_tilled")
							if GameState and GameTimeManager:
								GameState.set_tile_watered(target_cell, GameTimeManager.day)
							_apply_terrain_to_cell(target_cell, TERRAIN_ID_WET_SOIL)
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
			# TODO(Dean): Pickaxe on soil tiles should reverse the shape logic:
			# - remove one arm of the path
			# - then re-run _retile_soil_around on this cell + neighbors
			# to keep paths visually correct when digging up tiles.
			if not is_grass:
				# Clear crop layer first
				if crop_layer:
					crop_layer.erase_cell(target_cell)
				# Revert to grass
				_apply_terrain_to_cell(target_cell, TERRAIN_ID_GRASS)
				if GameState:
					GameState.update_tile_state(target_cell, "grass")
					var crop_data_from_state = GameState.get_tile_data(target_cell)
					if crop_data_from_state is Dictionary and crop_data_from_state.has("crop_id"):
						GameState.update_tile_state(target_cell, "grass")
				print("[FarmingManager] Removed soil at %s - grass restored" % target_cell)
		"seed":
			print("[FarmingManager] Seed planting check - is_soil: %s, is_tilled: %s, is_planted: %s, tile_state: %s" % [is_soil, is_tilled, is_planted, tile_state])
			if (is_soil or is_tilled) and not is_planted:
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
								if tile_state == "tilled":
									_apply_terrain_to_cell(target_cell, TERRAIN_ID_WET_SOIL)
								else:
									_apply_terrain_to_cell(target_cell, TERRAIN_ID_SOIL)
								var layer_to_use = crop_layer if crop_layer else farmable_layer
								if layer_to_use:
									layer_to_use.set_cell(target_cell, SOURCE_ID_CROP, Vector2i(0, 0))
									print("[FarmingManager] Visual updated for tile %s: soil on Farmable, crop on %s (dry crop, stage 0)" % [target_cell, "Crops" if crop_layer else "Farmable"])
								GameState.update_tile_state(target_cell, "planted")
							else:
								_set_tile_terrain(target_cell, TERRAIN_ID_SOIL, "soil")
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
			elif not (is_soil or is_tilled):
				print("[FarmingManager] Cannot plant: tile must be soil or tilled (current state: %s)" % tile_state)

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
			_set_tile_terrain(tile_pos, TERRAIN_ID_SOIL, "soil")
			print("[FarmingManager] Reverted tilled tile at %s to soil (dry)" % tile_pos)
			reverted_count += 1
		elif tile_state_str == "planted_tilled":
			if tile_data is Dictionary:
				tile_data["state"] = "planted"
				tile_data["is_watered"] = false
				GameState.update_tile_crop_data(tile_pos, tile_data)
				_set_tile_terrain(tile_pos, TERRAIN_ID_SOIL, "soil")
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
				_set_tile_terrain(tile_pos, TERRAIN_ID_SOIL, "soil")
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
	"""Legacy wrapper - use _apply_terrain_to_cell directly instead"""
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
