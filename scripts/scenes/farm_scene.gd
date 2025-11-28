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


func _ready() -> void:
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

	# Get FarmingManager reference - CRITICAL: Must be set before any farming operations
	var farming_manager = get_node_or_null(farming_manager_path)
	if not farming_manager:
		print("Error: FarmingManager not found at path: %s" % farming_manager_path)
		return
	
	# CRITICAL FIX: Set FarmingManager reference immediately so it's available for all operations
	# This ensures no "FarmingManager not linked" errors AND crop layer is created
	if farming_manager.has_method("set_farm_scene"):
		farming_manager.set_farm_scene(self)
	
	# CRITICAL FIX: Load farm state AFTER set_farm_scene() so crop layer exists
	_load_farm_state()
	
	# Ensure FarmingManager is connected to day_changed signal and check for missed crop growth
	if farming_manager and GameTimeManager:
		# Reconnect to day_changed signal (in case scene was reloaded)
		if not GameTimeManager.day_changed.is_connected(farming_manager._on_day_changed):
			GameTimeManager.day_changed.connect(farming_manager._on_day_changed)
			print("[FarmScene] Connected FarmingManager to day_changed signal")
		
		# Check for crop growth if we're loading into a new day (in case we missed the signal)
		# This ensures crops grow even if FarmingManager wasn't in scene when day changed
		if farming_manager.has_method("_advance_crop_growth"):
			farming_manager._advance_crop_growth()
			# Also revert watered states if needed
			if farming_manager.has_method("_revert_watered_states") and GameState:
				farming_manager._revert_watered_states()
				GameState.reset_watering_states()
	
	# Instantiate and add the HUD
	if hud_scene_path:
		hud_instance = hud_scene_path.instantiate()
		add_child(hud_instance)
		# Pass HUD instance to the farming manager
		if farming_manager and hud_instance:
			if HUD:
				HUD.set_farming_manager(farming_manager) # Link FarmingManager to HUD
				HUD.set_hud_scene_instance(hud_instance) # Inject HUD scene instance to cache references (replaces /root/... paths)
				farming_manager.set_hud(hud_instance) # Link HUD to FarmingManager
			else:
				print("Error: hud_instance is not an instance of HUD script.")
		else:
			print("Error: Could not link FarmingManager and HUD.")
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
		
		# Validate tile exists in tilemap before loading state
		var tile_data = tilemap.get_cell_tile_data(tile_position)
		if not tile_data:
			# Skip tiles that don't exist in tilemap (may have been removed or are out of bounds)
			continue
		
		# Add farmability check - tile must have grass, dirt, or tilled custom_data
		var is_grass = tile_data.get_custom_data("grass") == true
		var is_dirt = tile_data.get_custom_data("dirt") == true
		var is_tilled = tile_data.get_custom_data("tilled") == true
		if not (is_grass or is_dirt or is_tilled):
			# Tile is not farmable - skip loading state
			print("Warning: Skipping non-farmable tile at %s" % tile_position)
			continue
		
		# Get the state and set the tile
		var state = GameState.get_tile_state(tile_position)
		var crop_data = GameState.get_tile_data(tile_position)
		
		match state:
			"soil":
				# CRITICAL FIX: Soil state goes on Farmable layer only
				tilemap.set_cell(tile_position, farming_manager.TILE_ID_DIRT, Vector2i(0, 0))
				# Clear crop layer if it exists (no crop on soil-only tiles)
				if crop_layer:
					crop_layer.erase_cell(tile_position)
			"tilled":
				# CRITICAL FIX: Tilled state goes on Farmable layer only
				tilemap.set_cell(tile_position, farming_manager.TILE_ID_TILLED, Vector2i(0, 0))
				# Clear crop layer if it exists (no crop on tilled-only tiles)
				if crop_layer:
					crop_layer.erase_cell(tile_position)
			"planted":
				# CRITICAL FIX: Soil stays on Farmable layer, crop goes on crop layer
				# Keep soil visual on farmable layer (soil, not tilled - it's dry)
				tilemap.set_cell(tile_position, farming_manager.TILE_ID_DIRT, Vector2i(0, 0))
				# Put crop on crop layer (or farmable if crop layer doesn't exist)
				var crop_layer_to_use = crop_layer if crop_layer else tilemap
				if crop_data is Dictionary:
					var current_stage = crop_data.get("current_stage", 0)
					var max_stages = crop_data.get("growth_stages", 6)
					if current_stage >= max_stages - 1:
						crop_layer_to_use.set_cell(tile_position, farming_manager.TILE_ID_PLANTED, Vector2i(max_stages - 1, 0), 0)
					else:
						crop_layer_to_use.set_cell(tile_position, farming_manager.TILE_ID_PLANTED, Vector2i(current_stage, 0), 0)
				else:
					# Fallback for old saves without crop data
					crop_layer_to_use.set_cell(tile_position, farming_manager.TILE_ID_PLANTED, Vector2i(0, 0), 0)
			"planted_tilled":
				# CRITICAL FIX: Tilled soil on Farmable layer, crop on crop layer
				# Soil shows as tilled (watered) on farmable layer
				tilemap.set_cell(tile_position, farming_manager.TILE_ID_TILLED, Vector2i(0, 0))
				# Put crop on crop layer (or farmable if crop layer doesn't exist)
				var crop_layer_to_use = crop_layer if crop_layer else tilemap
				if crop_data is Dictionary:
					var current_stage = crop_data.get("current_stage", 0)
					var max_stages = crop_data.get("growth_stages", 6)
					if current_stage >= max_stages - 1:
						crop_layer_to_use.set_cell(tile_position, farming_manager.TILE_ID_PLANTED, Vector2i(max_stages - 1, 0), 0)
					else:
						crop_layer_to_use.set_cell(tile_position, farming_manager.TILE_ID_PLANTED, Vector2i(current_stage, 0), 0)
				else:
					# Fallback if no crop data, just show crop on crop layer
					crop_layer_to_use.set_cell(tile_position, farming_manager.TILE_ID_PLANTED, Vector2i(0, 0), 0)
			"dirt":
				# Legacy support: "dirt" maps to "soil" (TILE_ID_DIRT)
				tilemap.set_cell(tile_position, farming_manager.TILE_ID_DIRT, Vector2i(0, 0))
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
