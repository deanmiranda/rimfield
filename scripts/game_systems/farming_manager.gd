### farming_manager.gd ###
extends Node

# ======================================================================
# CLEAN STARDEW-STYLE FARMING SYSTEM
# No autotiling, no terrain peering, no shape computation
# ======================================================================

# Energy costs for tool usage
const ENERGY_COST_HOE = 2
const ENERGY_COST_WATERING_CAN = 1
const ENERGY_COST_PICKAXE = 3
const ENERGY_COST_SEED = 1

# Source ID for crop tiles
const SOURCE_ID_CROP = 3

# Atlas coordinate constants
const SOURCE_ID := 0
const FARM_TILE_ATLAS := Vector2i(12, 0) # Farmable garden tile (rubble/dirt)
const SOIL_DRY_ATLAS := Vector2i(5, 6) # Tilled dry soil
const SOIL_WET_ATLAS := Vector2i(5, 9) # Watered soil

@export var farmable_layer_path: NodePath
@export var crop_layer_path: NodePath
@export var farm_scene_path: NodePath

var farmable_layer: TileMapLayer
var crop_layer: TileMapLayer
var tool_switcher: Node
var current_tool: String = "hoe"
var farm_scene: Node2D
var tool_config: Resource = null
var game_config: Resource = null
var interaction_distance: float = 250.0

func _ready() -> void:
	tool_config = load("res://resources/data/tool_config.tres")
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		interaction_distance = game_config.interaction_distance
	
	if crop_layer_path:
		crop_layer = get_node_or_null(crop_layer_path) as TileMapLayer

func set_farmable_layer(layer: TileMapLayer) -> void:
	"""Set farmable layer from FarmScene"""
	farmable_layer = layer

func set_farm_scene(scene: Node2D) -> void:
	farm_scene = scene

func connect_signals() -> void:
	"""Connect FarmingManager to required signals"""
	if GameTimeManager:
		if not GameTimeManager.day_changed.is_connected(_on_day_changed):
			GameTimeManager.day_changed.connect(_on_day_changed)

func set_hud(hud_scene_instance: Node) -> void:
	tool_switcher = hud_scene_instance.get_node("ToolSwitcher")
	if tool_switcher:
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))

func _on_tool_changed(_slot_index: int, item_texture: Texture) -> void:
	if item_texture:
		if tool_config and tool_config.has_method("get_tool_name"):
			current_tool = tool_config.get_tool_name(item_texture)
		else:
			current_tool = "unknown"
	else:
		current_tool = "unknown"

# ============================================================================
# FARMABLE AREA CHECKING
# ============================================================================

func is_farmable(cell: Vector2i) -> bool:
	"""
	Check if a cell is farmable (painted tile at FARM_TILE_ATLAS).
	Only tiles painted with (12,0) in farmable_layer are farmable.
	"""
	if farmable_layer == null:
		return false
	
	var src := farmable_layer.get_cell_source_id(cell)
	if src != SOURCE_ID:
		return false
	
	return farmable_layer.get_cell_atlas_coords(cell) == FARM_TILE_ATLAS

func _is_soil(cell: Vector2i) -> bool:
	"""Check if cell is dry or wet soil"""
	if farmable_layer == null:
		return false
	
	var atlas := farmable_layer.get_cell_atlas_coords(cell)
	return atlas == SOIL_DRY_ATLAS or atlas == SOIL_WET_ATLAS

# ============================================================================
# TOOL INTERACTIONS
# ============================================================================

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		return
	
	if farmable_layer.tile_set == null:
		return
	
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
	
	# Get energy cost
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
	
	if PlayerStatsManager and energy_cost > 0:
		if not PlayerStatsManager.consume_energy(energy_cost):
			return
	
	# Execute tool action
	match current_tool:
		"hoe":
			_use_hoe(target_cell)
		"watering_can":
			_use_watering_can(target_cell)
		"pickaxe":
			_use_pickaxe(target_cell)
		"seed":
			_use_seed(target_cell)

func _use_hoe(cell: Vector2i) -> void:
	"""
	HOE: Allowed if tile is farmable OR already soil.
	When hoeing farmable tile: Replace with SOIL_DRY_ATLAS, state = "soil", is_watered = false
	When hoeing already-soil tile: No change
	"""
	if not is_farmable(cell) and not _is_soil(cell):
		return
	
	# If already soil, do nothing
	if _is_soil(cell):
		return
	
	# Replace farmable tile with dry soil
	farmable_layer.set_cell(cell, SOURCE_ID, SOIL_DRY_ATLAS)
	
	if GameState:
		GameState.update_tile_state(cell, "soil")
		var tile_data = GameState.get_tile_data(cell)
		if tile_data is Dictionary:
			tile_data["is_watered"] = false
			GameState.update_tile_crop_data(cell, tile_data)

func _use_watering_can(cell: Vector2i) -> void:
	"""
	WATERING CAN: Allowed if tile state is "soil" or "planted".
	Action: Replace with SOIL_WET_ATLAS, tile_data["is_watered"] = true
	"""
	if not GameState:
		return
	
	var tile_state = GameState.get_tile_state(cell)
	if tile_state != "soil" and tile_state != "planted":
		return
	
	# Replace with wet soil visual
	farmable_layer.set_cell(cell, SOURCE_ID, SOIL_WET_ATLAS)
	
	# Update GameState
	var tile_data = GameState.get_tile_data(cell)
	if tile_data is Dictionary:
		tile_data["is_watered"] = true
		if GameTimeManager:
			tile_data["last_watered_day"] = GameTimeManager.day
			var current_season = GameTimeManager.season
			var current_year = GameTimeManager.year
			var absolute_day = (current_year - 1) * 112 + current_season * 28 + GameTimeManager.day
			tile_data["last_watered_day_absolute"] = absolute_day
		GameState.update_tile_crop_data(cell, tile_data)
	
	if GameTimeManager:
		GameState.set_tile_watered(cell, GameTimeManager.day)

func _use_pickaxe(cell: Vector2i) -> void:
	"""
	PICKAXE: Allowed if tile is soil OR has a crop.
	Action: Remove crop, replace tile with FARM_TILE_ATLAS, clear all tile state
	"""
	if not _is_soil(cell):
		# Check if there's a crop
		if crop_layer and crop_layer.get_cell_source_id(cell) == SOURCE_ID_CROP:
			# Remove crop only
			crop_layer.erase_cell(cell)
			if GameState:
				GameState.farm_state.erase(cell)
		return
	
	# Remove crop if present
	if crop_layer:
		crop_layer.erase_cell(cell)
	
	# Restore farm tile
	farmable_layer.set_cell(cell, SOURCE_ID, FARM_TILE_ATLAS)
	
	# Clear all tile state
	if GameState:
		GameState.farm_state.erase(cell)

func _use_seed(cell: Vector2i) -> void:
	"""
	SEEDS: Allowed if tile state == "soil".
	Action: Leave soil unchanged, place crop sprite on crop_layer, state = "planted"
	"""
	if not GameState:
		return
	
	var tile_state = GameState.get_tile_state(cell)
	if tile_state != "soil":
		return
	
	# Check if already planted
	if crop_layer and crop_layer.get_cell_source_id(cell) == SOURCE_ID_CROP:
		return
	
	# Consume seed from inventory
	if tool_switcher and InventoryManager:
		var current_slot_index = tool_switcher.get("current_hud_slot")
		if current_slot_index >= 0:
			var seed_count = InventoryManager.get_toolkit_item_count(current_slot_index)
			if seed_count > 0:
				var new_count = seed_count - 1
				var seed_texture = InventoryManager.get_toolkit_item(current_slot_index)
				if new_count > 0:
					InventoryManager.add_item_to_toolkit(current_slot_index, seed_texture, new_count)
				else:
					InventoryManager.remove_item_from_toolkit(current_slot_index)
				InventoryManager.sync_toolkit_ui()
			else:
				return
		else:
			return
	else:
		return
	
	# Place crop on crop layer
	if not crop_layer:
		_create_crop_layer()
	
	if crop_layer:
		crop_layer.set_cell(cell, SOURCE_ID_CROP, Vector2i(0, 0))
	
	# Update GameState
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
	GameState.update_tile_crop_data(cell, crop_data)
	GameState.update_tile_state(cell, "planted")

func _create_crop_layer() -> void:
	"""Create crop layer if missing"""
	if not farm_scene or not farmable_layer:
		return
	
	if crop_layer:
		return
	
	crop_layer = farm_scene.get_node_or_null("Crops") as TileMapLayer
	if not crop_layer:
		crop_layer = TileMapLayer.new()
		crop_layer.name = "Crops"
		crop_layer.tile_set = farmable_layer.tile_set
		farm_scene.add_child(crop_layer)
		crop_layer.set_owner(farm_scene)
		crop_layer.z_index = 1

# ============================================================================
# MORNING RESET
# ============================================================================

func _on_day_changed(new_day: int, _new_season: int, _new_year: int) -> void:
	if not GameState or not farmable_layer:
		return
	
	_advance_crop_growth()
	_revert_watered_states()
	GameState.reset_watering_states()

func _revert_watered_states() -> void:
	"""Revert all watered tiles to dry soil"""
	if not GameState or not farmable_layer:
		return
	
	for tile_pos in GameState.farm_state.keys():
		var tile_data = GameState.get_tile_data(tile_pos)
		
		if tile_data is Dictionary:
			if tile_data.get("is_watered", false):
				# Change visual to dry soil
				farmable_layer.set_cell(tile_pos, SOURCE_ID, SOIL_DRY_ATLAS)
				# Clear watered flag
				tile_data["is_watered"] = false
				GameState.update_tile_crop_data(tile_pos, tile_data)
				
				# Update state if needed
				var tile_state = tile_data.get("state", "")
				if tile_state == "planted_tilled":
					tile_data["state"] = "planted"
					GameState.update_tile_crop_data(tile_pos, tile_data)
					GameState.update_tile_state(tile_pos, "planted")

func _advance_crop_growth() -> void:
	"""Advance crop growth for watered crops"""
	if not GameState or not GameTimeManager:
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
	
	var previous_absolute_day = (previous_year - 1) * 112 + previous_season * 28 + previous_day
	
	for tile_pos in GameState.farm_state.keys():
		var crop_data = GameState.get_tile_data(tile_pos)
		if not (crop_data is Dictionary):
			continue
		
		var tile_state = crop_data.get("state", "")
		if tile_state != "planted" and tile_state != "planted_tilled":
			continue
		
		if not crop_data.has("crop_id"):
			continue
		
		var last_watered_absolute = crop_data.get("last_watered_day_absolute", -1)
		if last_watered_absolute == -1:
			var last_watered_day = crop_data.get("last_watered_day", -1)
			if last_watered_day != -1:
				last_watered_absolute = (current_year - 1) * 112 + current_season * 28 + last_watered_day
		
		var was_watered_yesterday = (last_watered_absolute == previous_absolute_day)
		
		if tile_state == "planted_tilled":
			was_watered_yesterday = true
		
		if was_watered_yesterday:
			var current_stage = crop_data.get("current_stage", 0)
			var max_stages = crop_data.get("growth_stages", 6)
			var days_per_stage = crop_data.get("days_per_stage", 1)
			var days_watered = crop_data.get("days_watered_toward_next_stage", 0)
			
			days_watered += 1
			
			if days_watered >= days_per_stage and current_stage < (max_stages - 1):
				current_stage += 1
				days_watered = 0
			
			crop_data["current_stage"] = current_stage
			crop_data["days_watered_toward_next_stage"] = days_watered
			GameState.update_tile_crop_data(tile_pos, crop_data)
			
			_update_crop_visual(tile_pos, current_stage, max_stages)

func _update_crop_visual(tile_pos: Vector2i, current_stage: int, max_stages: int) -> void:
	"""Update crop visual on crop layer"""
	if not crop_layer:
		_create_crop_layer()
	
	if not crop_layer:
		return
	
	if current_stage >= max_stages - 1:
		crop_layer.set_cell(tile_pos, SOURCE_ID_CROP, Vector2i(max_stages - 1, 0))
	else:
		crop_layer.set_cell(tile_pos, SOURCE_ID_CROP, Vector2i(current_stage, 0))

# ============================================================================
# SAVE/LOAD HELPERS (for FarmScene)
# ============================================================================

func set_dry_soil_visual(cell: Vector2i) -> void:
	"""Public helper for save/load: set dry soil visual"""
	if farmable_layer:
		farmable_layer.set_cell(cell, SOURCE_ID, SOIL_DRY_ATLAS)

func set_wet_soil_visual(cell: Vector2i) -> void:
	"""Public helper for save/load: set wet soil visual"""
	if farmable_layer:
		farmable_layer.set_cell(cell, SOURCE_ID, SOIL_WET_ATLAS)

func restore_farm_tile(cell: Vector2i) -> void:
	"""Public helper for save/load: restore farm tile"""
	if farmable_layer:
		farmable_layer.set_cell(cell, SOURCE_ID, FARM_TILE_ATLAS)
