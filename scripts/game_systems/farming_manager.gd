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
const ENERGY_COST_CHEST = 0 # Chest placement is free

# Atlas coordinate constants
const SOURCE_ID := 0
const FARM_TILE_ATLAS := Vector2i(12, 0) # Farmable garden tile (rubble/dirt)
const SOIL_DRY_ATLAS := Vector2i(5, 6) # Tilled dry soil
const SOIL_WET_ATLAS := Vector2i(5, 9) # Watered soil

# Crop source IDs and atlas coordinates
# Dry soil carrot stages: source_id = 1, atlas = (stage, 0) for stages 0-5
# Wet soil carrot stages: source_id = 2, atlas = (stage, 0) for stages 0-5
const CROP_SOURCE_DRY := 1
const CROP_SOURCE_WET := 2
const CARROT_MAX_STAGE := 5

# Debug flag for seed planting (set to false to disable debug logs)
const DEBUG_SEED_PLANTING := true

@export var farmable_layer_path: NodePath
@export var crop_layer_path: NodePath
@export var farm_scene_path: NodePath
@export var crop_layer: TileMapLayer # Crop layer for planting seeds

var farmable_layer: TileMapLayer
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
	
	# Try to get crop layer from path if not already set via export
	if not crop_layer and crop_layer_path:
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
	print("[FarmingManager] set_hud called with: ", hud_scene_instance)
	tool_switcher = hud_scene_instance.get_node("ToolSwitcher")
	print("[FarmingManager] set_hud: tool_switcher: ", tool_switcher)
	if tool_switcher:
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
			print("[FarmingManager] set_hud: Connected tool_changed signal")
		else:
			print("[FarmingManager] set_hud: tool_changed signal already connected")
	else:
		print("[FarmingManager] set_hud: ERROR - ToolSwitcher not found!")

func _on_tool_changed(slot_index: int, item_texture: Texture) -> void:
	print("[FarmingManager] _on_tool_changed called - slot_index: ", slot_index, " texture: ", item_texture)
	if item_texture:
		print("[FarmingManager] _on_tool_changed: Texture path: ", item_texture.resource_path if item_texture else "null")
		if tool_config:
			print("[FarmingManager] _on_tool_changed: tool_config exists: ", tool_config)
			if tool_config.has_method("get_tool_name"):
				current_tool = tool_config.get_tool_name(item_texture)
				print("[FarmingManager] _on_tool_changed: Tool name from config: ", current_tool)
			else:
				current_tool = "unknown"
				print("[FarmingManager] _on_tool_changed: tool_config has no get_tool_name method")
		else:
			current_tool = "unknown"
			print("[FarmingManager] _on_tool_changed: tool_config is null")
	else:
		current_tool = "unknown"
		print("[FarmingManager] _on_tool_changed: No texture, setting tool to 'unknown'")
	
	print("[FarmingManager] _on_tool_changed: Final current_tool: ", current_tool)

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

func interact_with_tile(target_pos: Vector2, player_pos: Vector2, override_tool: String = "", override_slot_index: int = -1) -> void:
	# Use override tool if provided, otherwise use current_tool
	var tool_to_use = override_tool if override_tool != "" else current_tool
	print("[FarmingManager] interact_with_tile called - current_tool: ", current_tool, " tool_to_use: ", tool_to_use, " override_tool: ", override_tool)
	
	if not farmable_layer:
		print("[FarmingManager] ERROR: farmable_layer is null")
		return
	
	if farmable_layer.tile_set == null:
		print("[FarmingManager] ERROR: farmable_layer.tile_set is null")
		return
	
	var target_local_pos = farmable_layer.to_local(target_pos)
	var target_cell = farmable_layer.local_to_map(target_local_pos)
	
	var player_local_pos = farmable_layer.to_local(player_pos)
	var player_cell = farmable_layer.local_to_map(player_local_pos)
	
	var cell_distance_x = abs(target_cell.x - player_cell.x)
	var cell_distance_y = abs(target_cell.y - player_cell.y)
	
	print("[FarmingManager] Target cell: ", target_cell, " Player cell: ", player_cell, " Distance: (", cell_distance_x, ", ", cell_distance_y, ")")
	
	if cell_distance_x == 0 and cell_distance_y == 0:
		print("[FarmingManager] Blocked: Clicked on same tile as player")
		return
	
	# Allow chest placement at slightly greater distance (2 cells) for better UX
	var max_distance = 2 if tool_to_use == "chest" else 1
	if cell_distance_x > max_distance or cell_distance_y > max_distance:
		print("[FarmingManager] Blocked: Tile too far away (max distance: ", max_distance, ")")
		return
	
	# Get energy cost
	var energy_cost := 0
	match tool_to_use:
		"hoe":
			energy_cost = ENERGY_COST_HOE
		"watering_can":
			energy_cost = ENERGY_COST_WATERING_CAN
		"pickaxe":
			energy_cost = ENERGY_COST_PICKAXE
		"seed":
			energy_cost = ENERGY_COST_SEED
		"chest":
			energy_cost = ENERGY_COST_CHEST
	
	print("[FarmingManager] Energy cost for ", tool_to_use, ": ", energy_cost)
	
	if PlayerStatsManager and energy_cost > 0:
		if not PlayerStatsManager.consume_energy(energy_cost):
			print("[FarmingManager] Blocked: Not enough energy")
			return
	
	# Execute tool action
	print("[FarmingManager] Executing tool action: ", tool_to_use)
	match tool_to_use:
		"hoe":
			_use_hoe(target_cell)
		"watering_can":
			_use_watering_can(target_cell)
		"pickaxe":
			_use_pickaxe(target_cell)
		"seed":
			_use_seed(target_cell)
		"chest":
			_use_chest(target_cell, target_pos, override_slot_index)
		_:
			print("[FarmingManager] WARNING: Unknown tool type: ", current_tool)

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
	Action: Replace with SOIL_WET_ATLAS, update crop visual to wet row if planted.
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
		
		# If tile has a crop, update crop visual to wet row
		# CRITICAL: Use single-cell set_cell() only - no bulk operations
		if tile_state == "planted" and crop_layer:
			var current_stage = tile_data.get("current_stage", 0)
			var max_stages = tile_data.get("growth_stages", 6)
			# Clamp stage to valid range (0 to max_stages-1)
			var stage_to_show = current_stage
			if stage_to_show < 0:
				stage_to_show = 0
			if stage_to_show >= max_stages - 1:
				stage_to_show = max_stages - 1
			# Ensure Y coordinate is always 0 (only X changes with stage)
			var atlas_coords := Vector2i(stage_to_show, 0)
			crop_layer.set_cell(cell, CROP_SOURCE_WET, atlas_coords)
	
	if GameTimeManager:
		GameState.set_tile_watered(cell, GameTimeManager.day)

func _use_pickaxe(cell: Vector2i) -> void:
	"""
	PICKAXE: Allowed if tile is soil OR has a crop OR has a chest.
	Action: Remove crop, replace tile with FARM_TILE_ATLAS, clear all tile state, OR remove chest
	"""
	# FIRST: Check for chest at this position
	var chest_manager = get_node_or_null("/root/ChestManager")
	if chest_manager:
		# Calculate tile center position
		var tile_center_pos: Vector2
		if farmable_layer:
			tile_center_pos = farmable_layer.map_to_local(cell) + Vector2(8, 8)
		else:
			tile_center_pos = Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
		
		# Check if there's a chest at this position
		var chest_at_pos = chest_manager.find_chest_at_position(tile_center_pos, 12.0)
		if chest_at_pos:
			print("[CHEST PICKAXE] Chest hit at cell=%s world_pos=%s" % [cell, tile_center_pos])
			
			# Get HUD for droppable spawning
			var hud = get_tree().root.get_node_or_null("Hud")
			if not hud:
				hud = get_tree().current_scene.get_node_or_null("Hud")
			
			# Attempt to remove chest and spawn drop
			var removal_success = chest_manager.remove_chest_and_spawn_drop(chest_at_pos, hud)
			
			if removal_success:
				print("[CHEST PICKAXE] Chest removed successfully")
			else:
				print("[CHEST PICKAXE] Chest removal blocked (not empty)")
			
			return # Chest handling done, don't process soil/crops
	
	# SECOND: Check for crops and soil (existing logic)
	# Check if there's a crop
	var has_crop = false
	if crop_layer and crop_layer.get_cell_source_id(cell) != -1:
		has_crop = true
	
	if not _is_soil(cell) and not has_crop:
		return
	
	# Remove crop if present
	if crop_layer and has_crop:
		crop_layer.erase_cell(cell)
	
	# Restore farm tile (whether it was soil or had a crop)
	farmable_layer.set_cell(cell, SOURCE_ID, FARM_TILE_ATLAS)
	
	# Clear all tile state
	if GameState:
		GameState.farm_state.erase(cell)

func _use_seed(cell: Vector2i) -> void:
	"""
	SEEDS: Allowed if tile is dry or wet soil, NOT already planted, within farmable area.
	Action: Place crop sprite on crop_layer using correct source_id based on soil wetness.
	"""
	if not GameState:
		return
	
	# Must be on soil (dry or wet), not on base rubble tile
	if not _is_soil(cell):
		return
	
	# Check if already planted
	if crop_layer and crop_layer.get_cell_source_id(cell) != -1:
		return
	
	# Check tile state - must be "soil" or "tilled"
	var tile_state = GameState.get_tile_state(cell)
	if tile_state != "soil" and tile_state != "tilled":
		return
	
	# Get tile data to check if watered (for determining crop visual)
	var tile_data = GameState.get_tile_data(cell)
	var is_watered = false
	if tile_data is Dictionary:
		is_watered = tile_data.get("is_watered", false)
	# Also check visual - if soil looks wet, treat as watered
	if farmable_layer:
		var atlas = farmable_layer.get_cell_atlas_coords(cell)
		if atlas == SOIL_WET_ATLAS:
			is_watered = true
	
	# Consume seed from inventory
	if not tool_switcher or not InventoryManager:
		return
	
	var current_slot_index = tool_switcher.get("current_hud_slot")
	if current_slot_index < 0:
		return
	
	var seed_count = InventoryManager.get_toolkit_item_count(current_slot_index)
	if seed_count <= 0:
		return
	
	# Decrement seed count
	var new_count = seed_count - 1
	var seed_texture = InventoryManager.get_toolkit_item(current_slot_index)
	if new_count > 0:
		InventoryManager.add_item_to_toolkit(current_slot_index, seed_texture, new_count)
	else:
		InventoryManager.remove_item_from_toolkit(current_slot_index)
	InventoryManager.sync_toolkit_ui()
	
	# Ensure crop layer exists
	if not crop_layer:
		_create_crop_layer()
	
	if not crop_layer:
		return
	
	# Determine crop source ID based on soil wetness
	var crop_source_id = CROP_SOURCE_DRY
	if is_watered:
		crop_source_id = CROP_SOURCE_WET
	
	# Stage 0 for newly planted seeds
	var stage := 0
	# CRITICAL: Y coordinate must always be 0 (only X changes with stage)
	var atlas_coords := Vector2i(stage, 0)
	
	# Place crop on crop layer (stage 0) - SINGLE CELL ONLY
	# This must be a single-cell operation, never a bulk operation
	crop_layer.set_cell(cell, crop_source_id, atlas_coords)
	
	# Update GameState
	var crop_data = {
		"state": "planted",
		"crop_id": "carrot",
		"growth_stages": 6,
		"days_per_stage": 1,
		"current_stage": 0,
		"days_watered_toward_next_stage": 0,
		"is_watered": is_watered,
		"last_watered_day": - 1,
		"last_watered_day_absolute": - 1
	}
	GameState.update_tile_crop_data(cell, crop_data)
	GameState.update_tile_state(cell, "planted")
	

func _use_chest(cell: Vector2i, world_pos: Vector2, override_slot_index: int = -1) -> void:
	"""
	CHEST: Place a chest at the target position.
	Allowed if: tile is farmable/soil, no existing chest at position, player has chest in toolkit.
	Action: Instantiate chest scene, consume chest from toolkit.
	"""
	print("[CHEST FARM] _use_chest called - slot:", override_slot_index, " cell:", cell, " world_pos:", world_pos)
	
	if override_slot_index < 0:
		print("[CHEST FARM] BLOCKED - Invalid slot index")
		return
	
	if not InventoryManager:
		print("[CHEST FARM] BLOCKED - InventoryManager is null")
		return
	
	var texture := InventoryManager.get_toolkit_item(override_slot_index)
	var count := InventoryManager.get_toolkit_item_count(override_slot_index)
	
	print("[CHEST FARM] Slot data - texture:", texture, " count:", count)
	
	if texture == null or count <= 0:
		print("[CHEST FARM] BLOCKED - No item in slot")
		return
	
	# Identify tool using ToolConfig
	var tool_name := ""
	var tool_config_resource = load("res://resources/data/tool_config.tres")
	if tool_config_resource and tool_config_resource.has_method("get_tool_name"):
		tool_name = tool_config_resource.get_tool_name(texture)
		print("[CHEST FARM] Tool name:", tool_name)
	
	if tool_name != "chest":
		print("[CHEST FARM] BLOCKED - Not a chest tool:", tool_name)
		return
	
	# Get ChestManager
	var chest_manager = get_node_or_null("/root/ChestManager")
	if not chest_manager:
		print("[CHEST FARM] BLOCKED - ChestManager is null")
		return
	
	if not farm_scene:
		print("[CHEST FARM] BLOCKED - farm_scene is null")
		return
	
	# Calculate tile center position
	var tile_center_pos: Vector2
	if farmable_layer:
		tile_center_pos = farmable_layer.map_to_local(cell) + Vector2(8, 8) # Center of 16x16 tile
	else:
		tile_center_pos = world_pos
	
	print("[CHEST FARM] Tile center position:", tile_center_pos)
	
	# Check if there's already a chest at this position
	var existing_chests = chest_manager.chest_registry
	for chest_id in existing_chests.keys():
		var chest_data = existing_chests[chest_id]
		var chest_node = chest_data.get("node")
		if chest_node and is_instance_valid(chest_node):
			var distance = chest_node.global_position.distance_to(tile_center_pos)
			if distance < 16.0:
				print("[CHEST FARM] BLOCKED - Chest already exists at position")
				return
	
	# Check if position is valid - CANNOT place on soil/farmable tiles
	# Only allow placement on grass (FARM_TILE_ATLAS) that is NOT soil or watered
	var is_soil = _is_soil(cell)
	
	# Check if tile is watered or has a crop
	var is_watered = false
	var has_crop = false
	if GameState and GameState.farm_state.has(cell):
		var tile_data = GameState.get_tile_data(cell)
		if tile_data:
			is_watered = tile_data.get("is_watered", false)
			has_crop = tile_data.get("tile_state") == "planted"
	
	if is_soil or is_watered or has_crop:
		print("[CHEST FARM] BLOCKED - Cannot place on soil/watered/planted tiles")
		return
	
	# Validate placement: allow on grass/empty ground, block on soil/water
	if farmable_layer:
		var source_id = farmable_layer.get_cell_source_id(cell)
		
		# If source_id == -1, there's no tile on farmable layer (regular grass/ground) - ALLOW
		if source_id == -1:
			print("[CHEST FARM] ALLOW placement at cell=%s reason=empty_ground (no farmable tile)" % [cell])
		else:
			# There IS a tile on farmable layer - check what it is
			var atlas_coords = farmable_layer.get_cell_atlas_coords(cell)
			
			# FARM_TILE_ATLAS (12, 0) is garden dirt - allow placement
			# SOIL_DRY_ATLAS and SOIL_WET_ATLAS are tilled soil - block (already checked above)
			if atlas_coords == FARM_TILE_ATLAS:
				print("[CHEST FARM] ALLOW placement at cell=%s reason=grass_tile" % [cell])
			elif atlas_coords == SOIL_DRY_ATLAS:
				print("[CHEST FARM] BLOCK placement at cell=%s reason=dry_soil" % [cell])
				return
			elif atlas_coords == SOIL_WET_ATLAS:
				print("[CHEST FARM] BLOCK placement at cell=%s reason=wet_soil" % [cell])
				return
			else:
				# Unknown tile type - allow for now (could be decorative)
				print("[CHEST FARM] ALLOW placement at cell=%s reason=unknown_tile (atlas=%s)" % [cell, atlas_coords])
	else:
		print("[CHEST FARM] BLOCK placement at cell=%s reason=no_farmable_layer" % [cell])
		return
	
	# Create chest at position
	print("[CHEST FARM] Attempting placement...")
	var chest = chest_manager.create_chest_at_position(tile_center_pos)
	if chest == null:
		print("[CHEST FARM] FAILED - ChestManager.create_chest_at_position returned null")
		return
	
	print("[CHEST FARM] Placement success")
	
	# Call async helper to consume chest and sync UI
	_consume_chest_and_sync_ui(override_slot_index)


func _consume_chest_and_sync_ui(slot_index: int) -> void:
	"""Async helper to consume chest from toolkit and sync UI with deferred frame."""
	# Log BEFORE decrement
	print("[CHEST INV][Farm] BEFORE decrement: slot=%d texture=%s count=%d" % [slot_index, str(InventoryManager.get_toolkit_item(slot_index)), InventoryManager.get_toolkit_item_count(slot_index)])
	
	# Consume one chest item from the toolkit slot
	InventoryManager.decrement_toolkit_item_count(slot_index, 1)
	
	# Deferred sync to ensure drag state is cleared
	await get_tree().process_frame
	InventoryManager.sync_toolkit_ui()
	
	# Log AFTER sync
	print("[CHEST INV][Farm] AFTER decrement: slot=%d texture=%s count=%d" % [slot_index, str(InventoryManager.get_toolkit_item(slot_index)), InventoryManager.get_toolkit_item_count(slot_index)])
	
	print("[CHEST FARM] Inventory updated")


func _create_crop_layer() -> void:
	"""Create crop layer if missing"""
	if not farm_scene:
		return
	
	if crop_layer:
		return
	
	# Try to get from path first
	if crop_layer_path:
		crop_layer = get_node_or_null(crop_layer_path) as TileMapLayer
		if crop_layer:
			return
	
	# Try to find by name in farm scene
	crop_layer = farm_scene.get_node_or_null("Crops") as TileMapLayer
	if crop_layer:
		return
	
	# Create new crop layer if none found
	# NOTE: Crop layer should use its own TileSet, not farmable_layer.tile_set
	# to avoid autotiling issues. The crop layer TileSet should be configured
	# in the scene or loaded separately.
	crop_layer = TileMapLayer.new()
	crop_layer.name = "Crops"
	# Only use farmable_layer.tile_set as fallback if crop layer has no TileSet
	# The scene should already have the correct TileSet assigned
	if farmable_layer and farmable_layer.tile_set:
		crop_layer.tile_set = farmable_layer.tile_set
	farm_scene.add_child(crop_layer)
	crop_layer.set_owner(farm_scene)
	crop_layer.z_index = 1

# ============================================================================
# MORNING RESET
# ============================================================================

func _on_day_changed(_new_day: int, _new_season: int, _new_year: int) -> void:
	if not GameState or not farmable_layer:
		return
	
	_advance_crop_growth()
	_revert_watered_states()
	GameState.reset_watering_states()

func _revert_watered_states() -> void:
	"""
	Revert watered tiles to dry soil.
	- If tile_state == "soil" and is_watered → revert to dry soil visual
	- If tile_state == "planted" and is_watered → revert SOIL visual to dry, keep crop intact
	"""
	if not GameState or not farmable_layer:
		return
	
	for tile_pos in GameState.farm_state.keys():
		var tile_data = GameState.get_tile_data(tile_pos)
		
		if not (tile_data is Dictionary):
			continue
		
		if not tile_data.get("is_watered", false):
			continue
		
		var tile_state = tile_data.get("state", "")
		
		# Case 1: Plain soil tile (not planted)
		if tile_state == "soil" or tile_state == "tilled":
			# Change visual to dry soil
			farmable_layer.set_cell(tile_pos, SOURCE_ID, SOIL_DRY_ATLAS)
			# Clear watered flag
			tile_data["is_watered"] = false
			GameState.update_tile_crop_data(tile_pos, tile_data)
			if tile_state == "tilled":
				GameState.update_tile_state(tile_pos, "soil")
		
		# Case 2: Planted tile
		elif tile_state == "planted" or tile_state == "planted_tilled":
			# Revert SOIL visual to dry (keep crop intact)
			farmable_layer.set_cell(tile_pos, SOURCE_ID, SOIL_DRY_ATLAS)
			# Clear watered flag
			tile_data["is_watered"] = false
			# Update state to "planted" (remove "tilled" suffix)
			tile_data["state"] = "planted"
			GameState.update_tile_crop_data(tile_pos, tile_data)
			GameState.update_tile_state(tile_pos, "planted")
			
			# Switch crop visual from wet row to dry row (same stage)
			# CRITICAL: Use single-cell set_cell() only - no bulk operations
			if crop_layer:
				var current_stage = tile_data.get("current_stage", 0)
				var max_stages = tile_data.get("growth_stages", 6)
				# Clamp stage to valid range (0 to max_stages-1)
				var stage_to_show = current_stage
				if stage_to_show < 0:
					stage_to_show = 0
				if stage_to_show >= max_stages - 1:
					stage_to_show = max_stages - 1
				# Ensure Y coordinate is always 0 (only X changes with stage)
				var atlas_coords := Vector2i(stage_to_show, 0)
				crop_layer.set_cell(tile_pos, CROP_SOURCE_DRY, atlas_coords)
			
			# DO NOT erase crop layer - crop stays intact
			# DO NOT reset to farm base tile

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
	"""Update crop visual on crop layer based on current stage and watered state"""
	if not crop_layer:
		_create_crop_layer()
	
	if not crop_layer:
		return
	
	# Determine which source ID to use based on watered state
	var crop_source_id = CROP_SOURCE_DRY
	if GameState:
		var tile_data = GameState.get_tile_data(tile_pos)
		if tile_data is Dictionary:
			if tile_data.get("is_watered", false):
				crop_source_id = CROP_SOURCE_WET
	
	# Calculate stage to show - clamp to valid range
	var stage_to_show = current_stage
	if stage_to_show < 0:
		stage_to_show = 0
	if stage_to_show >= max_stages - 1:
		stage_to_show = max_stages - 1
	
	# CRITICAL: Ensure Y coordinate is always 0 (only X changes with stage)
	# Use explicit Vector2i to avoid any coordinate confusion
	var atlas_coords := Vector2i(stage_to_show, 0)
	crop_layer.set_cell(tile_pos, crop_source_id, atlas_coords)

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
