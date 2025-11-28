### farming_manager.gd ###
extends Node

# Constants (follows .cursor/rules/godot.md script ordering: Signals → Constants → Exports → Vars)
const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2
const TILE_ID_PLANTED = 3
const TILE_ID_GROWN = 4 # Assuming "grown" is the next state after planting

# Energy costs for tool usage
const ENERGY_COST_HOE = 2
const ENERGY_COST_WATERING_CAN = 1
const ENERGY_COST_PICKAXE = 3
const ENERGY_COST_SEED = 1

@export var farmable_layer_path: NodePath
@export var crop_layer_path: NodePath # Separate layer for crops (optional, will be created if missing)
@export var farm_scene_path: NodePath # Reference the farm scene

var hud_instance: Node
var hud_path: Node
var farmable_layer: TileMapLayer
var crop_layer: TileMapLayer # Separate layer for crop sprites
var tool_switcher: Node
var current_tool: String = "hoe" # Default starting tool
var farm_scene: Node2D # Reference to farm scene for linking

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
	
	# Get crop layer via path if specified (will be created in set_farm_scene if needed)
	if crop_layer_path:
		crop_layer = get_node_or_null(crop_layer_path) as TileMapLayer
		if crop_layer:
			print("[FarmingManager] Crop layer found via path: %s" % crop_layer.name)
	
	# Note: Crop layer creation is deferred to set_farm_scene() to ensure farm_scene reference is available
	
	# Connect to GameTimeManager day_changed signal for crop growth
	if GameTimeManager:
		if not GameTimeManager.day_changed.is_connected(_on_day_changed):
			GameTimeManager.day_changed.connect(_on_day_changed)
			print("[FarmingManager] Connected to GameTimeManager.day_changed signal")
		else:
			print("[FarmingManager] Already connected to GameTimeManager.day_changed signal")
	else:
		print("[FarmingManager] Warning: GameTimeManager not found, cannot connect to day_changed signal")
	 
func set_farm_scene(scene: Node2D) -> void:
	"""Set reference to farm scene - called by farm_scene.gd on load
	CRITICAL: This must be called before crop layer operations"""
	farm_scene = scene
	print("[FarmingManager] Farm scene reference set: %s" % (scene.name if scene else "null"))
	
	# CRITICAL FIX: Create or find crop layer after farm_scene is set
	# This ensures we can add the layer to the scene if it doesn't exist
	if not crop_layer and farm_scene:
		# Try to find existing crop layer by name
		crop_layer = farm_scene.get_node_or_null("Crops") as TileMapLayer
		
		# If still not found, create it programmatically
		if not crop_layer:
			crop_layer = TileMapLayer.new()
			crop_layer.name = "Crops"
			# Use same TileSet as farmable layer for crop sprites (source 3)
			if farmable_layer and farmable_layer.tile_set:
				crop_layer.tile_set = farmable_layer.tile_set
			farm_scene.add_child(crop_layer)
			crop_layer.set_owner(farm_scene)
			# Set z_index higher than farmable layer so crops render on top
			crop_layer.z_index = 1
			print("[FarmingManager] Created crop layer programmatically in set_farm_scene: %s" % crop_layer.name)
		else:
			print("[FarmingManager] Found existing crop layer: %s" % crop_layer.name)

func set_hud(hud_scene_instance: Node) -> void:
	hud_path = hud_scene_instance
	tool_switcher = hud_scene_instance.get_node("ToolSwitcher")
	
	if tool_switcher:
		# Connect the tool_changed signal
		if not tool_switcher.is_connected("tool_changed", Callable(self, "_on_tool_changed")):
			tool_switcher.connect("tool_changed", Callable(self, "_on_tool_changed"))
		
		# Ensure a valid tool is set on load
		var _first_slot_tool = tool_switcher.get("current_tool")


# Use shared ToolConfig Resource instead of duplicated tool mapping (follows .cursor/rules/godot.md)
var tool_config: Resource = null
# Use shared GameConfig Resource for magic numbers (follows .cursor/rules/godot.md)
var game_config: Resource = null
var interaction_distance: float = 250.0 # Default (will be overridden by GameConfig) - allows up to ~15 cell interaction range

func _on_tool_changed(_slot_index: int, item_texture: Texture) -> void:
	"""Update current_tool based on tool texture - tools are identified by texture, not slot"""
	if item_texture:
		# Use shared ToolConfig to map texture to tool name
		if tool_config and tool_config.has_method("get_tool_name"):
			current_tool = tool_config.get_tool_name(item_texture)
		else:
			current_tool = "unknown"
	else:
		# Tool texture is null - clear the tool (no tool selected)
		current_tool = "unknown"

func interact_with_tile(target_pos: Vector2, player_pos: Vector2) -> void:
	if not farmable_layer:
		return
	
	# Debug logging: log farmable layer name and tool being used
	print("[FarmingManager] Interacting with tile using farmable_layer: %s, tool: %s" % [farmable_layer.name, current_tool])

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
	

	# Check if target is in the 3x3 grid around player (8 adjacent tiles ONLY, NOT center)
	# Character CANNOT use tools on the tile they're standing on
	# Character can only use tools on tiles directly adjacent (including diagonals)
	# This is cell-based distance, which works correctly with Camera2D since we're using
	# world coordinates converted to tilemap local coordinates
	var cell_distance_x = abs(target_cell.x - player_cell.x)
	var cell_distance_y = abs(target_cell.y - player_cell.y)
	
	
	# Prevent interaction with the tile the player is standing on
	if cell_distance_x == 0 and cell_distance_y == 0:
		return
	
	# Only allow interaction if target is within 1 tile distance (adjacent tiles only)
	# This means max distance of 1 cell in X and Y directions (including diagonals)
	# But NOT the center tile (already checked above)
	if cell_distance_x > 1 or cell_distance_y > 1:
		return

	# STRICT CHECK: Tile MUST exist in farmable layer (has a source_id set)
	# This is the PRIMARY check - if no source_id, the tile doesn't exist in this layer
	# Tools should NEVER work on tiles that don't exist in the farmable layer
	var source_id = farmable_layer.get_cell_source_id(target_cell)
	if source_id == -1:
		# No tile exists at this position in the farmable layer - NOT FARMABLE
		print("[FarmingManager] BLOCKED: Tile at %s has no source_id in farmable layer - tools cannot work here" % target_cell)
		return
	
	# Get tile data to verify it has farmable custom_data
	var tile_data = farmable_layer.get_cell_tile_data(target_cell)
	if not tile_data:
		# No tile data - this shouldn't happen if source_id exists, but check anyway
		print("[FarmingManager] BLOCKED: Tile at %s has source_id but no tile_data - skipping" % target_cell)
		return
	
	# CRITICAL FIX: STRICT FARMABILITY CHECK - Tile MUST have farmable custom_data flags
	# PRIMARY CHECK: custom_data flags (grass, dirt, tilled) - these are the ONLY tiles that should be farmable
	# This is the PRIMARY and MOST IMPORTANT check - if a tile doesn't have these flags, it's NOT farmable
	var is_farmable = false
	if tile_data.has_method("get_custom_data"):
		var grass_data = tile_data.get_custom_data("grass")
		var dirt_data = tile_data.get_custom_data("dirt")
		var tilled_data = tile_data.get_custom_data("tilled")
		is_farmable = (grass_data == true or dirt_data == true or tilled_data == true)
		if is_farmable:
			print("[FarmingManager] Tile at %s is farmable (has custom_data: grass=%s, dirt=%s, tilled=%s)" % [target_cell, grass_data, dirt_data, tilled_data])
	
	# SECONDARY CHECK: Only for tiles that are ALREADY in GameState with farmable states
	# This is ONLY for tiles that were previously farmable (planted tiles that lost custom_data)
	# CRITICAL: This should be RARE - most farmable tiles should have custom_data flags
	# This fallback is ONLY for tiles that were created by the farming system and are in farmable states
	if not is_farmable and GameState:
		var tile_state = GameState.get_tile_state(target_cell)
		# ONLY allow if tile is in a farmable state (soil, tilled, planted, planted_tilled)
		# AND it's NOT "grass" (grass should always have custom_data flag)
		# This ensures we don't allow interaction with non-farmable tiles that somehow got into GameState
		if tile_state == "soil" or tile_state == "tilled" or tile_state == "planted" or tile_state == "planted_tilled":
			# Additional validation: ensure this tile was created by farming system (has crop data or is in farmable state)
			var tile_data_from_state = GameState.get_tile_data(target_cell)
			if tile_data_from_state is Dictionary or tile_state != "grass":
				is_farmable = true
				print("[FarmingManager] Tile at %s is farmable based on GameState (state: %s) - previously farmable tile created by farming system" % [target_cell, tile_state])
	
	if not is_farmable:
		# This tile exists in farmable layer but is NOT farmable - BLOCK tool interaction
		# This prevents tools from working on tiles outside the designated farmable area
		var tile_state_from_game = GameState.get_tile_state(target_cell) if GameState else "N/A"
		print("[FarmingManager] BLOCKED: Tile at %s exists in farmable layer but is NOT farmable (no custom_data flags: grass/dirt/tilled, GameState state=%s) - tools cannot work here" % [target_cell, tile_state_from_game])
		return

	# Get the actual tile state from GameState (authoritative source)
	var tile_state = "grass"
	if GameState:
		tile_state = GameState.get_tile_state(target_cell)
	
	# Determine tile type from state string
	var is_grass = (tile_state == "grass")
	var is_soil = (tile_state == "soil")
	var is_planted = (tile_state == "planted" or tile_state == "planted_tilled")
	var is_tilled = (tile_state == "tilled")
	
	# Only perform tool actions if a valid tool is selected (not "unknown")
	# This ensures empty slots don't perform tool actions
	if current_tool == "unknown":
		return # No tool selected, don't perform any actions
	
	# Check energy before performing tool action
	if PlayerStatsManager and PlayerStatsManager.energy <= 0:
		return # No energy, cancel action
	
	# Determine energy cost based on tool type
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
			energy_cost = 0 # Unknown tool, no cost
	
	# Consume energy - if insufficient, cancel action
	if PlayerStatsManager and energy_cost > 0:
		if not PlayerStatsManager.consume_energy(energy_cost):
			return # Insufficient energy, cancel action
		# Debug logging for energy consumption
		print("[FarmingManager] Tool '%s' consumed %d energy (remaining: %d/%d)" % [current_tool, energy_cost, PlayerStatsManager.energy, PlayerStatsManager.max_energy])
	
	match current_tool:
		"hoe":
			# Shovel (hoe) only works on grass → converts to soil
			if is_grass:
				_set_tile_custom_state(target_cell, TILE_ID_DIRT, "soil")
		"watering_can":
			# Watering can works on soil AND planted tiles
			if is_soil:
				# Watering soil → converts to tilled
				# CRITICAL: Only update Farmable layer (soil state), NOT crop layer
				if farmable_layer:
					farmable_layer.set_cell(target_cell, TILE_ID_TILLED, Vector2i(0, 0), 0)
				# Track watering for potential future growth mechanics
				if GameState and GameTimeManager:
					# Update state to "tilled" (watered) and track watering day with absolute day
					GameState.update_tile_state(target_cell, "tilled")
					# CRITICAL FIX: set_tile_watered now handles absolute day calculation internally
					GameState.set_tile_watered(target_cell, GameTimeManager.day)
					var current_day = GameTimeManager.day
					var absolute_day = GameTimeManager.get_absolute_day()
					print("[FarmingManager] Watered soil tile at %s (state: tilled, day: %d, absolute: %d)" % [target_cell, current_day, absolute_day])
			elif is_planted:
				# Watering planted tile → converts to planted_tilled
				# Only water if not already watered (not already "planted_tilled")
				if tile_state == "planted":
					# Update state to planted_tilled but keep crop visual (TILE_ID_PLANTED with stage)
					if GameState:
						var crop_data = GameState.get_tile_data(target_cell)
						if crop_data is Dictionary:
							crop_data["state"] = "planted_tilled"
							# Track watering for crop growth - CRITICAL: Set last_watered_day to current day AND absolute day
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
							# CRITICAL FIX: Update soil visual on Farmable layer (soil -> tilled), keep crop on crop layer
							# When watering planted crops, the soil underneath should show as tilled
							if farmable_layer:
								# Update soil to tilled visual (darker/wet soil)
								farmable_layer.set_cell(target_cell, TILE_ID_TILLED, Vector2i(0, 0), 0)
							
							# Update crop visual on crop layer (or farmable if crop layer doesn't exist)
							var current_stage = crop_data.get("current_stage", 0)
							var layer_to_use = crop_layer if crop_layer else farmable_layer
							if layer_to_use:
								layer_to_use.set_cell(target_cell, TILE_ID_PLANTED, Vector2i(current_stage, 0), 0)
							print("[FarmingManager] Watered planted tile at %s (state: planted_tilled, last_watered_day: %d, absolute: %d, visual: crop stage %d on %s layer)" % [target_cell, crop_data.get("last_watered_day", -1), crop_data.get("last_watered_day_absolute", -1), current_stage, "Crops" if crop_layer else "Farmable"])
						else:
							# Fallback: Update state and track watering (shouldn't happen if crop_data exists)
							GameState.update_tile_state(target_cell, "planted_tilled")
							# Track watering for crop growth with absolute day
							if GameState and GameTimeManager:
								# CRITICAL FIX: set_tile_watered now handles absolute day calculation internally
								GameState.set_tile_watered(target_cell, GameTimeManager.day)
							# CRITICAL FIX: Update soil visual on farmable layer, crop on crop layer
							if farmable_layer:
								farmable_layer.set_cell(target_cell, TILE_ID_TILLED, Vector2i(0, 0), 0)
							var layer_to_use = crop_layer if crop_layer else farmable_layer
							if layer_to_use:
								layer_to_use.set_cell(target_cell, TILE_ID_PLANTED, Vector2i(0, 0), 0)
							print("[FarmingManager] Watered planted tile at %s (fallback path, state: planted_tilled)" % target_cell)
				elif tile_state == "planted_tilled":
					# Already watered, just update the watering day (don't change state or visual)
					# CRITICAL FIX: Update absolute day for proper tracking
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
			# Pickaxe resets any non-grass tile back to grass
			if not is_grass:
				# CRITICAL FIX: Clear crop layer first, then reset soil to grass
				# Clear crop from crop layer (or farmable if crop layer doesn't exist)
				var layer_to_clear = crop_layer if crop_layer else farmable_layer
				if layer_to_clear:
					layer_to_clear.erase_cell(target_cell)
				
				# Reset tile state and visual to grass on farmable layer
				_set_tile_custom_state(target_cell, TILE_ID_GRASS, "grass")
				# Clear any crop data from GameState
				if GameState:
					GameState.update_tile_state(target_cell, "grass")
					# Also remove crop data if it exists
					# Note: Using existing tile_data variable from function scope (line 167)
					var crop_data_from_state = GameState.get_tile_data(target_cell)
					if crop_data_from_state is Dictionary and crop_data_from_state.has("crop_id"):
						# Remove crop data, keep only state
						GameState.update_tile_state(target_cell, "grass")
		"seed":
			# Seeds can be planted on soil OR tilled (not grass, not already planted)
			print("[FarmingManager] Seed planting check - is_soil: %s, is_tilled: %s, is_planted: %s, tile_state: %s" % [is_soil, is_tilled, is_planted, tile_state])
			if (is_soil or is_tilled) and not is_planted:
				# Check if seed exists in current toolkit slot
				if tool_switcher and InventoryManager:
					var current_slot_index = tool_switcher.get("current_hud_slot")
					if current_slot_index >= 0:
						var seed_count = InventoryManager.get_toolkit_item_count(current_slot_index)
						print("[FarmingManager] Seed count in slot %d: %d" % [current_slot_index, seed_count])
						if seed_count > 0:
							# Decrement seed count
							var new_count = seed_count - 1
							var seed_texture = InventoryManager.get_toolkit_item(current_slot_index)
							if new_count > 0:
								InventoryManager.add_item_to_toolkit(current_slot_index, seed_texture, new_count)
							else:
								InventoryManager.remove_item_from_toolkit(current_slot_index)
							InventoryManager.sync_toolkit_ui()
							print("[FarmingManager] Seed consumed, planting at %s" % target_cell)
							# Plant the seed - IMPORTANT: Always set to "planted" (DRY), never "planted_tilled"
							# Seeds on dry soil stay dry, seeds on tilled soil also become dry when planted
							if GameState:
								# Initialize crop data FIRST (before setting visual)
								var crop_data = {
									"state": "planted", # ALWAYS dry when first planted
									"crop_id": "carrot", # Default crop type (can be determined from seed texture later)
									"growth_stages": 6, # 6 growth stages (0-5)
									"days_per_stage": 1, # Requires 1 watered day per stage
									"current_stage": 0, # Start at stage 0
									"days_watered_toward_next_stage": 0,
									"is_watered": false, # ALWAYS false when planting
									"last_watered_day": - 1 # ALWAYS -1 when planting
								}
								GameState.update_tile_crop_data(target_cell, crop_data)
								print("[FarmingManager] Crop data initialized for tile %s (state: planted, is_watered: false)" % target_cell)
								# CRITICAL FIX: Keep soil on Farmable layer, put crop on crop layer
								# Ensure soil state is preserved (soil or tilled, depending on previous state)
								var soil_state = "soil" # Default to soil
								if tile_state == "tilled":
									soil_state = "tilled"
									# Keep tilled visual on farmable layer
									if farmable_layer:
										farmable_layer.set_cell(target_cell, TILE_ID_TILLED, Vector2i(0, 0), 0)
								else:
									# Keep soil visual on farmable layer
									if farmable_layer:
										farmable_layer.set_cell(target_cell, TILE_ID_DIRT, Vector2i(0, 0), 0)
								
								# Put crop sprite on crop layer (or farmable layer if crop layer doesn't exist)
								var layer_to_use = crop_layer if crop_layer else farmable_layer
								if layer_to_use:
									layer_to_use.set_cell(target_cell, TILE_ID_PLANTED, Vector2i(0, 0), 0)
									print("[FarmingManager] Visual updated for tile %s: soil on %s, crop on %s (dry crop, stage 0)" % [target_cell, "Farmable", "Crops" if crop_layer else "Farmable"])
								# Also update the state string in GameState to ensure consistency
								GameState.update_tile_state(target_cell, "planted")
							else:
								# Fallback if GameState is null
								_set_tile_custom_state(target_cell, TILE_ID_PLANTED, "planted")
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
	# Fetch the correct emitter based on the state
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

func _set_tile_custom_state(cell: Vector2i, tile_id: int, _state: String) -> void:
	# Update the visual state on the FARMABLE layer only
	# In Godot 4, set_cell() automatically uses the custom_data from the TileSet source
	# set_cell(coords, source_id, atlas_coords, alternative_tile)
	# Verify the TileSet has the source_id before setting
	if not farmable_layer:
		print("[FarmingManager] Error: farmable_layer is null!")
		return
		
	var tile_set = farmable_layer.tile_set
	if not tile_set:
		print("[FarmingManager] Error: tile_set is null!")
		return
	
	# Check if the source_id exists in the TileSet
	var source_exists = tile_set.has_source(tile_id)
	if not source_exists:
		print("[FarmingManager] Error: Tile source %d does not exist in TileSet!" % tile_id)
		return
	
	# Ensure tile exists in farmable layer before setting
	var existing_tile_data = farmable_layer.get_cell_tile_data(cell)
	if not existing_tile_data:
		print("[FarmingManager] Warning: Attempting to set tile at %s but no tile exists in farmable layer" % cell)
		# Still try to set it, but log the warning
	
	# Set the visual on the farmable layer
	farmable_layer.set_cell(cell, tile_id, Vector2i(0, 0), 0)
	print("[FarmingManager] Set visual on farmable_layer '%s' at %s to tile_id %d (state: %s)" % [farmable_layer.name, cell, tile_id, _state])

	# Update the GameState for persistence
	if GameState:
		GameState.update_tile_state(cell, _state)
		print("[FarmingManager] Updated tile at %s to state '%s' in GameState" % [cell, _state])
	else:
		print("Error: GameState is null!")

	# Trigger the corresponding emitter for the updated state
	var emitter_scene = _get_emitter_scene(_state)
	if emitter_scene:
		_trigger_dust_at_tile(cell, emitter_scene)


func _water_tile(cell: Vector2i) -> void:
	"""Water a tilled or planted tile"""
	if not GameState or not GameTimeManager:
		return
	
	var current_day = GameTimeManager.day
	GameState.set_tile_watered(cell, current_day)
	
	# Visual feedback: could add water particle effect here
	print("[FarmingManager] Watered tile at %s on day %d" % [cell, current_day])


func _on_day_changed(new_day: int, _new_season: int, _new_year: int) -> void:
	"""Handle day advancement - reset watering states and advance crop growth"""
	print("[FarmingManager] _on_day_changed called - Day: %d, Season: %d, Year: %d" % [new_day, _new_season, _new_year])
	
	# Advance crop growth for all planted tiles (check if they were watered yesterday)
	_advance_crop_growth()
	
	# After growth logic, revert watered states to unwatered states
	# This makes watering last only one day
	if GameState:
		_revert_watered_states()
		# Reset all watering flags for new day
		GameState.reset_watering_states()
		print("[FarmingManager] Watered states reverted and reset for new day")
	else:
		print("[FarmingManager] Warning: GameState is null, cannot revert watered states")
	
	# TODO: On season change (e.g., summer 1), check if crops are out of season and destroy/wither them
	# This should iterate through all planted tiles and check if the crop's season matches the current season
	# If not, destroy the crop and reset the tile to "soil" state


func _advance_crop_growth() -> void:
	"""Advance growth for all crops that were watered yesterday"""
	if not GameState or not GameTimeManager:
		print("[FarmingManager] Cannot advance crop growth: GameState or GameTimeManager is null")
		return
	
	# CRITICAL FIX: Calculate previous day correctly, accounting for season rollover
	var current_day = GameTimeManager.day
	var current_season = GameTimeManager.season
	var current_year = GameTimeManager.year
	
	# Calculate previous day - if day is 1, previous day was 28 of previous season
	var previous_day = current_day - 1
	var previous_season = current_season
	var previous_year = current_year
	
	if previous_day < 1:
		previous_day = 28 # Last day of previous season
		previous_season -= 1
		if previous_season < 0:
			previous_season = 3 # Last season of previous year
			previous_year -= 1
	
	# Calculate absolute day number for comparison (days since game start)
	# This ensures we can compare across season boundaries
	var current_absolute_day = (current_year - 1) * 112 + current_season * 28 + current_day
	var previous_absolute_day = (previous_year - 1) * 112 + previous_season * 28 + previous_day
	
	print("[FarmingManager] Advancing crop growth - current: Day %d, Season %d, Year %d (absolute: %d), checking for crops watered on absolute day %d" % [current_day, current_season, current_year, current_absolute_day, previous_absolute_day])
	
	var crops_checked = 0
	var crops_advanced = 0
	
	for tile_pos in GameState.farm_state.keys():
		var crop_data = GameState.get_tile_data(tile_pos)
		if not (crop_data is Dictionary):
			continue
		
		# Check if tile has a crop (both "planted" and "planted_tilled" states have crops)
		var tile_state = crop_data.get("state", "")
		if not crop_data.has("crop_id") or (tile_state != "planted" and tile_state != "planted_tilled"):
			continue
		
		crops_checked += 1
		
		# Check if tile was watered yesterday
		# CRITICAL FIX: Use absolute day number for comparison to handle season rollover
		var last_watered_absolute = crop_data.get("last_watered_day_absolute", -1)
		var last_watered_day = crop_data.get("last_watered_day", -1) # Keep for backward compatibility
		
		# If we have absolute day, use it; otherwise calculate from day/season/year
		if last_watered_absolute == -1 and last_watered_day != -1:
			# Legacy: calculate absolute day from last_watered_day (assumes same season/year)
			# This is a fallback for old saves
			last_watered_absolute = (current_year - 1) * 112 + current_season * 28 + last_watered_day
		
		var was_watered_yesterday = (last_watered_absolute == previous_absolute_day)
		
		# Also check if state was "planted_tilled" (this indicates it was watered yesterday)
		# Note: We check this at the start of the new day, so "planted_tilled" means it was watered yesterday
		if tile_state == "planted_tilled":
			was_watered_yesterday = true
		
		print("[FarmingManager] Crop at %s: state=%s, last_watered_absolute=%d, previous_absolute_day=%d, was_watered_yesterday=%s" % [tile_pos, tile_state, last_watered_absolute, previous_absolute_day, was_watered_yesterday])
		
		if was_watered_yesterday:
			# Tile was watered yesterday - advance growth
			var current_stage = crop_data.get("current_stage", 0)
			var max_stages = crop_data.get("growth_stages", 6) # Default to 6 for carrots
			var days_per_stage = crop_data.get("days_per_stage", 1)
			var days_watered = crop_data.get("days_watered_toward_next_stage", 0)
			
			# Increment days watered
			days_watered += 1
			
			# Check if ready to advance to next stage
			# max_stages is 6, so stages are 0-5 (indices 0 through 5)
			if days_watered >= days_per_stage and current_stage < (max_stages - 1):
				current_stage += 1
				days_watered = 0
				crops_advanced += 1
				print("[FarmingManager] Crop at %s advanced to stage %d/%d" % [tile_pos, current_stage, max_stages - 1])
			else:
				print("[FarmingManager] Crop at %s: days_watered=%d, days_per_stage=%d, current_stage=%d, max_stages=%d (not ready to advance)" % [tile_pos, days_watered, days_per_stage, current_stage, max_stages])
			
			# Update tile data
			crop_data["current_stage"] = current_stage
			crop_data["days_watered_toward_next_stage"] = days_watered
			GameState.update_tile_crop_data(tile_pos, crop_data)
			
			# Update visual representation with atlas coordinates
			_update_crop_visual(tile_pos, current_stage, max_stages)
		else:
			# Tile was not watered - do not advance (but don't reset progress)
			print("[FarmingManager] Crop at %s was not watered yesterday (last_watered_absolute=%d, previous_absolute_day=%d) - no growth" % [tile_pos, last_watered_absolute, previous_absolute_day])
	
	print("[FarmingManager] Crop growth check complete: %d crops checked, %d crops advanced" % [crops_checked, crops_advanced])


func _revert_watered_states() -> void:
	"""Revert watered states back to unwatered states after growth logic runs"""
	# This makes watering last only one day
	# "tilled" → "soil"
	# "planted_tilled" → "planted"
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
		
		# Get the state string (either from simple string or dictionary)
		if not (tile_data is Dictionary):
			# Simple state string
			tile_state_str = tile_data if tile_data is String else "grass"
		else:
			# Dictionary with crop data - get state from dictionary
			tile_state_str = tile_data.get("state", "")
		
		# Check if this tile needs to be reverted
		if tile_state_str == "tilled":
			# Revert tilled → soil (dry)
			if not (tile_data is Dictionary):
				# Simple string state - update to "soil"
				GameState.update_tile_state(tile_pos, "soil")
			else:
				# Dictionary state - shouldn't happen for "tilled", but handle it
				tile_data["state"] = "soil"
				GameState.update_tile_crop_data(tile_pos, tile_data)
			if farmable_layer:
				farmable_layer.set_cell(tile_pos, TILE_ID_DIRT, Vector2i(0, 0), 0)
			print("[FarmingManager] Reverted tilled tile at %s to soil (dry)" % tile_pos)
			reverted_count += 1
		elif tile_state_str == "planted_tilled":
			# Revert planted_tilled → planted (dry)
			if tile_data is Dictionary:
				tile_data["state"] = "planted"
				tile_data["is_watered"] = false
				# Don't reset last_watered_day - we need it for growth checking
				GameState.update_tile_crop_data(tile_pos, tile_data)
				# CRITICAL FIX: Revert soil visual on Farmable layer (tilled -> soil), keep crop on crop layer
				# Update soil visual to dry (tilled -> soil)
				if farmable_layer:
					farmable_layer.set_cell(tile_pos, TILE_ID_DIRT, Vector2i(0, 0), 0)
				
				# Update crop visual on crop layer (or farmable if crop layer doesn't exist)
				var current_stage = tile_data.get("current_stage", 0)
				var max_stages = tile_data.get("growth_stages", 6)
				var layer_to_use = crop_layer if crop_layer else farmable_layer
				if layer_to_use:
					if current_stage >= max_stages - 1:
						# Fully grown - use TILE_ID_PLANTED with max stage
						layer_to_use.set_cell(tile_pos, TILE_ID_PLANTED, Vector2i(max_stages - 1, 0), 0)
					else:
						# Still growing - use TILE_ID_PLANTED with current stage
						layer_to_use.set_cell(tile_pos, TILE_ID_PLANTED, Vector2i(current_stage, 0), 0)
				print("[FarmingManager] Reverted planted_tilled tile at %s to planted (dry, stage %d, soil on Farmable, crop on %s)" % [tile_pos, current_stage, "Crops" if crop_layer else "Farmable"])
				reverted_count += 1
			else:
				# Fallback: simple string state (shouldn't happen, but handle it)
				GameState.update_tile_state(tile_pos, "planted")
				if farmable_layer:
					farmable_layer.set_cell(tile_pos, TILE_ID_PLANTED, Vector2i(0, 0), 0)
				print("[FarmingManager] Reverted planted_tilled tile at %s to planted (dry, fallback)" % tile_pos)
				reverted_count += 1
	
	print("[FarmingManager] Reverted %d watered tiles to dry state" % reverted_count)


func _update_crop_visual(tile_pos: Vector2i, current_stage: int, max_stages: int) -> void:
	"""Update the visual representation of a crop based on its growth stage
	CRITICAL: Only updates crop layer, NOT farmable layer (soil stays unchanged)"""
	var layer_to_use = crop_layer if crop_layer else farmable_layer
	if not layer_to_use:
		return
	
	# Use TILE_ID_PLANTED with atlas coordinates for different stages
	# Stages are 0-5 (horizontal: 0:0, 1:0, 2:0, 3:0, 4:0, 5:0)
	if current_stage >= max_stages - 1:
		# Crop is fully grown (stage 5) - use max stage atlas coordinate
		layer_to_use.set_cell(tile_pos, TILE_ID_PLANTED, Vector2i(max_stages - 1, 0), 0)
	else:
		# Crop is still growing - use current stage atlas coordinate
		layer_to_use.set_cell(tile_pos, TILE_ID_PLANTED, Vector2i(current_stage, 0), 0)
	
	print("[FarmingManager] Updated crop visual at %s: stage %d on %s layer" % [tile_pos, current_stage, "Crops" if crop_layer else "Farmable"])
