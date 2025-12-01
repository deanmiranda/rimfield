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

# Background music player
var farm_music_player: AudioStreamPlayer = null


func _ready() -> void:
	# Temporary test: Verify FarmingTerrain.tres loads
	var test_tileset = load("res://assets/tilesets/FarmingTerrain.tres")
	
	# Setup background music - randomly select one of three farm tracks
	# Call immediately - _setup_farm_music will handle async operations
	_setup_farm_music()
	
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
	
	# Validate TileSet after waiting
	if farmable_layer.tile_set == null:
		push_error("[FarmScene] Farmable TileMapLayer TileSet still null after deferred load")
		return
	
	
	# Pass validated layer to FarmingManager
	farming_manager.set_farmable_layer(farmable_layer)
	
	# Complete FarmingManager setup
	farming_manager.set_farm_scene(self)
	farming_manager.connect_signals()
	
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

# Auto-grass initialization removed - farmable area is defined by painted tiles only

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
	for tile_position in GameState.farm_state.keys():
		# Ensure tile_position is Vector2i (legacy saves may have strings, but we now use Vector2i)
		if not (tile_position is Vector2i):
			continue
		
		# With terrain-based system, we can place tiles anywhere in the farmable layer
		# No need to check custom_data - terrain system handles visuals
		
		# Get the state and set the tile
		var state = GameState.get_tile_state(tile_position)
		var crop_data = GameState.get_tile_data(tile_position)
		
		match state:
			"soil":
				# Draw dry soil atlas
				farming_manager.set_dry_soil_visual(tile_position)
				# Clear crop layer if it exists
				if crop_layer:
					crop_layer.erase_cell(tile_position)
			"tilled":
				# Draw wet soil atlas (legacy "tilled" state)
				farming_manager.set_wet_soil_visual(tile_position)
				# Clear crop layer if it exists
				if crop_layer:
					crop_layer.erase_cell(tile_position)
			"planted":
				# Draw soil visual (dry or wet) depending on is_watered
				var is_watered = false
				if crop_data is Dictionary:
					is_watered = crop_data.get("is_watered", false)
				
				if is_watered:
					farming_manager.set_wet_soil_visual(tile_position)
				else:
					farming_manager.set_dry_soil_visual(tile_position)
				
				# Recreate crop from GameState on crop layer
				var crop_layer_to_use = crop_layer if crop_layer else tilemap
				var crop_source_id = farming_manager.CROP_SOURCE_DRY
				if is_watered:
					crop_source_id = farming_manager.CROP_SOURCE_WET
				
				# CRITICAL: Use single-cell set_cell() only - no bulk operations
				if crop_data is Dictionary:
					var current_stage = crop_data.get("current_stage", 0)
					var max_stages = crop_data.get("growth_stages", 6)
					# Clamp stage to valid range (0 to max_stages-1)
					var stage_to_show = current_stage
					if stage_to_show < 0:
						stage_to_show = 0
					if stage_to_show >= max_stages - 1:
						stage_to_show = max_stages - 1
					# Ensure Y coordinate is always 0 (only X changes with stage)
					var atlas_coords := Vector2i(stage_to_show, 0)
					crop_layer_to_use.set_cell(tile_position, crop_source_id, atlas_coords)
				else:
					# Default to stage 0
					crop_layer_to_use.set_cell(tile_position, crop_source_id, Vector2i(0, 0))
			"planted_tilled":
				# Draw wet soil visual
				farming_manager.set_wet_soil_visual(tile_position)
				# Recreate crop from GameState on crop layer (wet row)
				var crop_layer_to_use = crop_layer if crop_layer else tilemap
				# CRITICAL: Use single-cell set_cell() only - no bulk operations
				if crop_data is Dictionary:
					var current_stage = crop_data.get("current_stage", 0)
					var max_stages = crop_data.get("growth_stages", 6)
					# Clamp stage to valid range (0 to max_stages-1)
					var stage_to_show = current_stage
					if stage_to_show < 0:
						stage_to_show = 0
					if stage_to_show >= max_stages - 1:
						stage_to_show = max_stages - 1
					# Ensure Y coordinate is always 0 (only X changes with stage)
					var atlas_coords := Vector2i(stage_to_show, 0)
					crop_layer_to_use.set_cell(tile_position, farming_manager.CROP_SOURCE_WET, atlas_coords)
				else:
					# Default to stage 0
					crop_layer_to_use.set_cell(tile_position, farming_manager.CROP_SOURCE_WET, Vector2i(0, 0))
			"dirt":
				# Legacy support: "dirt" maps to "soil"
				farming_manager.set_dry_soil_visual(tile_position)
				if GameState:
					GameState.update_tile_state(tile_position, "soil")
			_:
				# No state or unknown state - check if farmable layer has farm tile
				# If not, leave it unchanged (non-farmable area)
				# If yes, leave it as farm tile (already correct)
				pass


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

func _setup_farm_music() -> void:
	"""Setup and play random farm background music (no loop)."""
	# Aggressively stop ALL audio players first
	_stop_all_music()
	
	# Create AudioStreamPlayer node if it doesn't exist
	if farm_music_player == null:
		farm_music_player = AudioStreamPlayer.new()
		farm_music_player.name = "FarmMusic"
		farm_music_player.add_to_group("music") # Add to music group for easy management
		add_child(farm_music_player)
	
	# List of available farm music tracks
	var farm_tracks: Array[String] = [
		"res://assets/audio/Farm-1.mp3",
		"res://assets/audio/Farm-2.mp3",
		"res://assets/audio/Farm-3.mp3"
	]
	
	# Randomly select one track
	var random_index = randi() % farm_tracks.size()
	var selected_track = farm_tracks[random_index]
	
	# Load the selected track
	var audio_stream = load(selected_track)
	if audio_stream == null:
		push_error("[FarmScene] CRITICAL: Failed to load farm music file: %s" % selected_track)
		push_error("[FarmScene] File exists check: %s" % ResourceLoader.exists(selected_track))
		return
	
	
	# Ensure the stream doesn't loop
	if audio_stream is AudioStreamMP3:
		audio_stream.loop = false
	
	# Set the stream and volume
	farm_music_player.stream = audio_stream
	farm_music_player.volume_db = 0.0
	
	
	# Wait a frame to ensure everything is set up, then play
	call_deferred("_play_farm_music", selected_track)

func _play_farm_music(track_path: String) -> void:
	"""Play the farm music (called deferred to ensure node is ready)."""
	if farm_music_player == null:
		push_error("[FarmScene] Cannot play farm music - player is null")
		return
	
	if farm_music_player.stream == null:
		push_error("[FarmScene] Cannot play farm music - stream is null")
		return
	
	# Stop any existing playback
	farm_music_player.stop()
	
	# Ensure we're in the scene tree
	if not is_inside_tree():
		push_error("[FarmScene] Cannot play farm music - not in scene tree")
		return
	
	# Play the music
	farm_music_player.play()

func _stop_all_music() -> void:
	"""Stop all music players in the scene tree (safety check)."""
	# Stop all AudioStreamPlayer nodes in the entire scene tree
	var all_nodes = get_tree().get_nodes_in_group("")
	var music_nodes = []
	
	# Find all AudioStreamPlayer nodes recursively
	_find_audio_players_recursive(self, music_nodes)
	
	# Also check the scene tree
	if is_inside_tree():
		var audio_players = get_tree().get_nodes_in_group("music")
		for player in audio_players:
			if player is AudioStreamPlayer and not player in music_nodes:
				music_nodes.append(player)
	
	# Stop all found music players
	for player in music_nodes:
		if player is AudioStreamPlayer:
			player.stop()
	
	# Explicitly stop farm music player if it exists
	if farm_music_player and farm_music_player.playing:
		farm_music_player.stop()

func _find_audio_players_recursive(node: Node, result: Array) -> void:
	"""Recursively find all AudioStreamPlayer nodes."""
	if node is AudioStreamPlayer:
		result.append(node)
	
	for child in node.get_children():
		_find_audio_players_recursive(child, result)
