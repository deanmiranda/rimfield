extends Node2D

@export var tilemap_layer: NodePath # Reference the TileMapLayer node
@export var grass_emitter_scene: Resource
@export var tilled_emitter_scene: Resource
@export var dirt_emitter_scene: Resource
@export var cell_size: Vector2 = Vector2(16, 16) # Define the size of each cell manually or export for flexibility
@export var debug_disable_dust: bool = true # Toggle to disable dust emitter
@export var farming_manager_path: NodePath # farming_manager path

var hud_instance: Node
var hud_scene_path = preload("res://scenes/ui/hud.tscn")

# Reference to the inventory instance
var inventory_instance: Control = null

# Reference to FarmingManager (set during initialization)
var farming_manager: Node = null


func _ready() -> void:
	# Temporary test: Verify FarmingTerrain.tres loads
	var test_tileset = load("res://assets/tilesets/FarmingTerrain.tres")
	print("[TEST] FarmingTerrain load result: ", test_tileset)
	
	# Instantiate and position the player
	var player_scene = preload("res://scenes/characters/player/player.tscn")
	var player_instance = player_scene.instantiate()
	add_child(player_instance)

	# Use spawn position from SceneManager if set (e.g., exiting house)
	if SceneManager and SceneManager.player_spawn_position != Vector2.ZERO:
		player_instance.global_position = SceneManager.player_spawn_position
		SceneManager.player_spawn_position = Vector2.ZERO # Reset after use
	else:
		# Default: use PlayerSpawnPoint node
		var spawn_point = $PlayerSpawnPoint
		if not spawn_point:
			print("Error: PlayerSpawnPoint node not found!")
			return
		player_instance.global_position = spawn_point.global_position

	# Force camera to snap to player position immediately (no smooth transition)
	var player_node = player_instance.get_node_or_null("Player")
	if player_node:
		var camera = player_node.get_node_or_null("PlayerCamera")
		if camera and camera is Camera2D:
			camera.reset_smoothing()

	# Farming logic setup
	GameState.connect("game_loaded", Callable(self, "_on_game_loaded")) # Proper Callable usage

	# Inventory setup
	if UiManager:
		UiManager.instantiate_inventory()
	else:
		print("Error: UiManager singleton not found.")

	# Defer farming initialization to allow TileSet to load asynchronously
	call_deferred("_initialize_farming")
	
	# Instantiate and add the HUD (can happen immediately, linking happens in _initialize_farming)
	if hud_scene_path:
		hud_instance = hud_scene_path.instantiate()
		add_child(hud_instance)
	else:
		print("Error: HUD scene not assigned!")

	# Spawn droppables asynchronously to avoid scene load delay
	spawn_random_droppables_async(40)


func spawn_random_droppables_async(count: int) -> void:
	"""Spawn droppables over multiple frames to avoid blocking scene load"""
	if not hud_instance:
		print("Error: HUD instance is null! Droppables cannot be spawned.")
		return

	# Spawn in smaller batches (5 per frame) to spread load and reduce stutter
	var batch_size = 5
	var batches = ceili(float(count) / float(batch_size))

	for batch in range(batches):
		# Calculate how many to spawn in this batch
		var start_index = batch * batch_size
		var end_index = mini(start_index + batch_size, count)

		# Spawn this batch after waiting a frame
		await get_tree().process_frame

		for i in range(start_index, end_index):
			var droppable_name = _get_random_droppable_name()
			var random_position = _get_random_farm_position()
			DroppableFactory.spawn_droppable(droppable_name, random_position, hud_instance)


func spawn_random_droppables(count: int) -> void:
	"""Legacy synchronous spawn - kept for compatibility"""
	if not hud_instance:
		print("Error: HUD instance is null! Droppables cannot be spawned.")
		return

	for i in range(count):
		var droppable_name = _get_random_droppable_name()
		var random_position = _get_random_farm_position()
		DroppableFactory.spawn_droppable(droppable_name, random_position, hud_instance)


func _get_random_droppable_name() -> String:
	var droppable_names = ["carrot", "strawberry", "tomato"] # Add more droppable types
	return droppable_names[randi() % droppable_names.size()]


func _get_random_farm_position() -> Vector2:
	var farm_area = Rect2(Vector2(0, 0), Vector2(-400, 400)) # Define the bounds of your farm
	var random_x = randi() % int(farm_area.size.x) + farm_area.position.x
	var random_y = randi() % int(farm_area.size.y) + farm_area.position.y
	return Vector2(random_x, random_y)


func _initialize_farming() -> void:
	"""Deferred farming initialization - waits for TileSet to load"""
	# Link FarmingManager first
	link_farming_manager()
	if not farming_manager:
		return
	
	# Run diagnostic to extract TileSet structure (once only)
	if not has_meta("_debug_tileset_run"):
		set_meta("_debug_tileset_run", true)
		farming_manager.debug_farming_tileset()
	
	# Resolve farmable layer
	var farmable_layer := get_node_or_null(tilemap_layer) as TileMapLayer
	if farmable_layer == null:
		push_error("[FarmScene] Farmable TileMapLayer not found at path: %s" % tilemap_layer)
		return
	
	# Wait for TileSet to load (max 2 frames)
	var wait_frames = 0
	const MAX_WAIT_FRAMES = 2
	
	while farmable_layer.tile_set == null and wait_frames < MAX_WAIT_FRAMES:
		await get_tree().process_frame
		wait_frames += 1
		print("[FarmScene] Waiting for TileSet to load... (frame %d/%d)" % [wait_frames, MAX_WAIT_FRAMES])
	
	# Validate TileSet after waiting
	if farmable_layer.tile_set == null:
		push_error("[FarmScene] Farmable TileMapLayer TileSet still null after deferred load")
		return
	
	print("[FarmScene] Farmable layer validated: TileSet loaded (path: %s)" % farmable_layer.tile_set.resource_path)
	
	# Verification diagnostics
	print("[VERIFY] Farmable TileSet at runtime: ", farmable_layer.tile_set)
	if farmable_layer.tile_set:
		print("[VERIFY] Farmable TileSet path: ", farmable_layer.tile_set.resource_path)
	
	# Pass validated layer to FarmingManager
	farming_manager.set_farmable_layer(farmable_layer)
	
	# Initialize default terrain (auto-grass)
	initialize_default_terrain(farmable_layer)
	
	# Complete FarmingManager setup
	farming_manager.set_farm_scene_reference(self)
	farming_manager.resolve_layers()
	farming_manager.connect_signals()
	farming_manager.create_crop_layer_if_missing()
	
	# Load saved state (overwrites grass where needed)
	_load_farm_state()
	
	# Check for missed crop growth if we're loading into a new day
	if farming_manager and GameTimeManager:
		if farming_manager.has_method("_advance_crop_growth"):
			farming_manager._advance_crop_growth()
			# Also revert watered states if needed
			if farming_manager.has_method("_revert_watered_states") and GameState:
				farming_manager._revert_watered_states()
				GameState.reset_watering_states()
	
	# Link HUD to FarmingManager (after farming_manager is set)
	if hud_instance and farming_manager:
		if HUD:
			HUD.set_farming_manager(farming_manager) # Link FarmingManager to HUD
			HUD.set_hud_scene_instance(hud_instance) # Inject HUD scene instance to cache references (replaces /root/... paths)
			farming_manager.set_hud(hud_instance) # Link HUD to FarmingManager
		else:
			print("Error: hud_instance is not an instance of HUD script.")
	else:
		if not hud_instance:
			print("Error: HUD instance not created")
		if not farming_manager:
			print("Error: FarmingManager not linked")

func link_farming_manager() -> void:
	"""Get and validate FarmingManager reference"""
	farming_manager = get_node_or_null(farming_manager_path)
	if not farming_manager:
		push_error("[FarmScene] FarmingManager not found at path: %s" % farming_manager_path)
		return
	print("[FarmScene] FarmingManager linked: %s" % farming_manager.name)

func initialize_default_terrain(farmable_layer: TileMapLayer) -> void:
	"""Paint all used cells with grass terrain (only if no saved state)"""
	if farmable_layer == null:
		return
	
	if GameState and GameState.farm_state.size() > 0:
		print("[FarmScene] Saved farm state exists - skipping auto-grass")
		return
	
	if farming_manager == null:
		return
	
	var used_cells: Array[Vector2i] = farmable_layer.get_used_cells()
	print("[FarmScene] Auto-grass: initializing ", used_cells.size(), " cells")
	
	if used_cells.is_empty():
		return
	
	farming_manager.apply_terrain_to_cells(used_cells, farming_manager.TERRAIN_ID_GRASS)
	
	# Keep the GameState sync
	if GameState:
		for cell in used_cells:
			GameState.update_tile_state(cell, "grass")
	
	print("[FarmScene] Auto-grass initialized: %d cells painted" % used_cells.size())

func _on_game_loaded() -> void:
	_load_farm_state() # Apply loaded state when notified


func _load_farm_state() -> void:
	var farming_manager = get_node_or_null(farming_manager_path)
	if not farming_manager:
		print("Error: Farming Manager not found!")
		return

	var tilemap = get_node_or_null(tilemap_layer)
	if not tilemap:
		print("Error: TileMapLayer not found!")
		return
	
	# CRITICAL FIX: Get crop layer from FarmingManager (it creates/manages it)
	var crop_layer: TileMapLayer = null
	# Use get() to safely retrieve the property (has() doesn't work on Node objects)
	var crop_layer_property = farming_manager.get("crop_layer")
	if crop_layer_property != null:
		crop_layer = crop_layer_property as TileMapLayer
	else:
		# Fallback: try to find it by name
		crop_layer = get_node_or_null("Crops") as TileMapLayer
	
	# Debug logging: log tilemap layer name
	print("[FarmScene] Loading farm state using TileMapLayer: %s, crop_layer: %s" % [tilemap.name, crop_layer.name if crop_layer else "null"])
	print("[FarmScene] GameState.farm_state has %d tiles" % GameState.farm_state.size())

	for tile_position in GameState.farm_state.keys():
		# Ensure tile_position is Vector2i (legacy saves may have strings, but we now use Vector2i)
		if not (tile_position is Vector2i):
			print("Warning: Invalid tile position format (skipping):", tile_position)
			continue
		
		# With terrain-based system, we can place tiles anywhere in the farmable layer
		# No need to check custom_data - terrain system handles visuals
		
		# Get the state and set the tile
		var state = GameState.get_tile_state(tile_position)
		var crop_data = GameState.get_tile_data(tile_position)
		
		match state:
			"soil":
				# Use terrain-based system - Godot handles auto-tiling
				farming_manager._apply_terrain_to_cell(tile_position, farming_manager.TERRAIN_ID_SOIL)
				# Clear crop layer if it exists (no crop on soil-only tiles)
				if crop_layer:
					crop_layer.erase_cell(tile_position)
			"tilled":
				# Use terrain-based system - Godot handles auto-tiling
				farming_manager._apply_terrain_to_cell(tile_position, farming_manager.TERRAIN_ID_WET_SOIL)
				# Clear crop layer if it exists (no crop on tilled-only tiles)
				if crop_layer:
					crop_layer.erase_cell(tile_position)
			"planted":
				# Use terrain-based system for soil visual
				farming_manager._apply_terrain_to_cell(tile_position, farming_manager.TERRAIN_ID_SOIL)
				# Put crop on crop layer (or farmable if crop layer doesn't exist)
				var crop_layer_to_use = crop_layer if crop_layer else tilemap
				if crop_data is Dictionary:
					var current_stage = crop_data.get("current_stage", 0)
					var max_stages = crop_data.get("growth_stages", 6)
					if current_stage >= max_stages - 1:
						crop_layer_to_use.set_cell(tile_position, farming_manager.SOURCE_ID_CROP, Vector2i(max_stages - 1, 0))
					else:
						crop_layer_to_use.set_cell(tile_position, farming_manager.SOURCE_ID_CROP, Vector2i(current_stage, 0))
				else:
					# Fallback for old saves without crop data
					crop_layer_to_use.set_cell(tile_position, farming_manager.SOURCE_ID_CROP, Vector2i(0, 0))
			"planted_tilled":
				# Use terrain-based system for tilled soil visual
				farming_manager._apply_terrain_to_cell(tile_position, farming_manager.TERRAIN_ID_WET_SOIL)
				# Put crop on crop layer (or farmable if crop layer doesn't exist)
				var crop_layer_to_use = crop_layer if crop_layer else tilemap
				if crop_data is Dictionary:
					var current_stage = crop_data.get("current_stage", 0)
					var max_stages = crop_data.get("growth_stages", 6)
					if current_stage >= max_stages - 1:
						crop_layer_to_use.set_cell(tile_position, farming_manager.SOURCE_ID_CROP, Vector2i(max_stages - 1, 0))
					else:
						crop_layer_to_use.set_cell(tile_position, farming_manager.SOURCE_ID_CROP, Vector2i(current_stage, 0))
				else:
					# Fallback if no crop data, just show crop on crop layer
					crop_layer_to_use.set_cell(tile_position, farming_manager.SOURCE_ID_CROP, Vector2i(0, 0))
			"dirt":
				# Legacy support: "dirt" maps to "soil"
				farming_manager._apply_terrain_to_cell(tile_position, farming_manager.TERRAIN_ID_SOIL)
				# Update state to "soil" for consistency
				if GameState:
					GameState.update_tile_state(tile_position, "soil")


func trigger_dust(tile_position: Vector2, emitter_scene: Resource) -> void:
	var particle_emitter = emitter_scene.instantiate()
	add_child(particle_emitter)

	# Ensure particles render on top
	particle_emitter.z_index = 100
	particle_emitter.z_as_relative = true

	var tile_world_position = tile_position * cell_size + cell_size / 2
	particle_emitter.global_position = tile_world_position
	particle_emitter.emitting = true

	await get_tree().create_timer(particle_emitter.lifetime).timeout
	particle_emitter.queue_free()
