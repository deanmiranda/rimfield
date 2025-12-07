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
	
	# Restore chests for this scene
	if ChestManager:
		ChestManager.restore_chests_for_scene("Farm")
	
	# Restore droppables for this scene
	if DroppableFactory:
		DroppableFactory.restore_droppables_for_scene("Farm")
	
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

	# Defer farming initialization to allow TileSet to load asynchronously
	call_deferred("_initialize_farming")
	
	# Instantiate and add the HUD (can happen immediately, linking happens in _initialize_farming)
	if hud_scene_path:
		hud_instance = hud_scene_path.instantiate()
		add_child(hud_instance)

	# Spawn random droppables ONLY on Day 1 of new game (gate to prevent re-spawning)
	var is_day1 := false
	if GameTimeManager:
		is_day1 = GameTimeManager.day == 1 and GameTimeManager.season == 0 and GameTimeManager.year == 1
	
	if GameState:
		if is_day1 and not GameState.day1_farm_random_droppables_spawned:
			# Set flag BEFORE spawning to prevent double-spawn if _ready() triggers twice
			GameState.day1_farm_random_droppables_spawned = true
			spawn_random_droppables_async(80)
			
			# Spawn starter tools, chest, and seeds as droppables
			spawn_starter_items_async()
	
	# Connect to DragManager world drop signal for chest placement
	if DragManager:
		if not DragManager.dropped_on_world.is_connected(_on_toolkit_world_drop):
			DragManager.dropped_on_world.connect(_on_toolkit_world_drop)
		
		# Connect to cursor-hold world drop signal
		if not DragManager.cursor_hold_dropped_on_world.is_connected(_on_cursor_hold_dropped_on_world):
			DragManager.cursor_hold_dropped_on_world.connect(_on_cursor_hold_dropped_on_world)


func spawn_random_droppables_async(count: int) -> void:
	"""Spawn droppables over multiple frames to avoid blocking scene load"""
	if not hud_instance:
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


func spawn_starter_items_async() -> void:
	"""Spawn starter tools, chest, and seeds as droppables on Day 1"""
	if not hud_instance:
		return
	
	await get_tree().process_frame
	
	# Load tool textures
	var shovel_texture = load("res://assets/tiles/tools/shovel.png")
	var watering_can_texture = load("res://assets/tiles/tools/watering-can.png")
	var pickaxe_texture = load("res://assets/tiles/tools/pick-axe.png")
	var chest_texture = load("res://assets/icons/chest_icon.png")
	var seeds_texture = load("res://assets/tilesets/full version/tiles/FartSnipSeeds.png")
	
	# Spawn tools (one of each)
	if shovel_texture:
		var pos = _get_random_farm_position()
		DroppableFactory.spawn_generic_droppable_from_texture(shovel_texture, pos, hud_instance, 1)
	
	await get_tree().process_frame
	
	if watering_can_texture:
		var pos = _get_random_farm_position()
		DroppableFactory.spawn_generic_droppable_from_texture(watering_can_texture, pos, hud_instance, 1)
	
	await get_tree().process_frame
	
	if pickaxe_texture:
		var pos = _get_random_farm_position()
		DroppableFactory.spawn_generic_droppable_from_texture(pickaxe_texture, pos, hud_instance, 1)
	
	await get_tree().process_frame
	
	# Spawn chest (one)
	if chest_texture:
		var pos = _get_random_farm_position()
		DroppableFactory.spawn_generic_droppable_from_texture(chest_texture, pos, hud_instance, 1)
	
	await get_tree().process_frame
	
	# Spawn seeds (stack of 10)
	if seeds_texture:
		var pos = _get_random_farm_position()
		DroppableFactory.spawn_generic_droppable_from_texture(seeds_texture, pos, hud_instance, 10)
	

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
		return

	var tilemap = get_node_or_null(tilemap_layer)
	if not tilemap:
		return
	
	# Restore chests from save data
	_restore_chests()
	
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
				# No state or unknown state - leave it unchanged (non-farmable area)
				return


func _restore_chests() -> void:
	"""Restore chests from save data."""
	if not ChestManager:
		return
	
	# Get pending restore data from ChestManager
	var pending_data = ChestManager.get_pending_restore_data()
	if pending_data.size() == 0:
		return
	
	# Instantiate chests at their saved positions
	var chest_scene = preload("res://scenes/world/chest.tscn")
	if not chest_scene:
		push_error("FarmScene: Could not load chest scene")
		return
	
	for chest_data in pending_data:
		var chest_id = chest_data.get("chest_id", "")
		var position_data = chest_data.get("position", {"x": 0, "y": 0})
		var position = Vector2(position_data.get("x", 0), position_data.get("y", 0))
		
		# Instantiate chest
		var chest_instance = chest_scene.instantiate()
		if chest_instance:
			chest_instance.global_position = position
			# Set chest ID before registration so it matches save data
			if chest_instance.has_method("set_chest_id"):
				chest_instance.set_chest_id(chest_id)
			add_child(chest_instance)
			# Chest will register itself in _ready() and restore inventory


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

func _on_toolkit_world_drop(source_container: Node, source_slot: int, texture: Texture, count: int, mouse_pos: Vector2) -> void:
	"""Handle item dropped on world from drag (any item, or chest placement)"""
	if texture == null:
		return
	
	var tex_path = texture.resource_path
	
	# Special case: chest icon from toolkit → place chest
	if tex_path == "res://assets/icons/chest_icon.png":
		_handle_chest_placement(source_container, source_slot, texture, count, mouse_pos)
		return
	
	# General case: any other item → spawn as droppable
	_handle_item_world_drop(texture, count, mouse_pos, source_container, source_slot)


func _handle_chest_placement(source_container: Node, source_slot: int, texture: Texture, count: int, mouse_pos: Vector2) -> void:
	"""Handle chest placement on world"""
	
	# Convert screen mouse_pos to world position using MouseUtil
	var world_pos = mouse_pos
	if MouseUtil:
		world_pos = MouseUtil.get_world_mouse_pos_2d(self)
	else:
		# Fallback: use viewport
		var viewport = get_viewport()
		if viewport:
			var camera = viewport.get_camera_2d()
			if camera:
				var viewport_size = viewport.size
				var camera_pos = camera.global_position
				var mouse_screen = mouse_pos
				world_pos = camera_pos + (mouse_screen - viewport_size / 2.0) / camera.zoom
	
	# Snap to grid (16x16 tiles, center at +8)
	var snapped_pos = Vector2(floor(world_pos.x / 16.0) * 16.0 + 8, floor(world_pos.y / 16.0) * 16.0 + 8)
	
	# Get ChestManager
	var chest_manager = get_node_or_null("/root/ChestManager")
	if not chest_manager:
		return
	
	# Check if there's already a chest at this position
	var existing_chest = chest_manager.find_chest_at_position(snapped_pos, 16.0)
	if existing_chest:
		return
	
	# Check if position is valid using farming_manager if available
	if farming_manager:
		# Use farming_manager's validation logic
		var cell = Vector2i(floor(snapped_pos.x / 16.0), floor(snapped_pos.y / 16.0))
		if farming_manager.has_method("_is_soil"):
			var is_soil = farming_manager._is_soil(cell)
			if is_soil:
				return
		
		# Check if tile has crop or is watered
		if GameState and GameState.farm_state.has(cell):
			var tile_data = GameState.get_tile_data(cell)
			if tile_data:
				var is_watered = tile_data.get("is_watered", false)
				var has_crop = tile_data.get("tile_state") == "planted"
				if is_watered or has_crop:
					return
	
	# Create chest at position
	var chest = chest_manager.create_chest_at_position(snapped_pos)
	if chest == null:
		return
	
	# Remove 1 chest from toolkit slot
	if source_container and source_container.has_method("get_slot_data"):
		var slot_data = source_container.get_slot_data(source_slot)
		var current_count = slot_data.get("count", 0)
		if current_count > 1:
			# Decrement count by 1
			if source_container.has_method("set_slot_data"):
				source_container.set_slot_data(source_slot, texture, current_count - 1)
			else:
				# Fallback: remove and re-add with decremented count
				source_container.remove_item_from_slot(source_slot)
				source_container.add_item_to_slot(source_slot, texture, current_count - 1)
		else:
			# Only 1 item - remove completely
			source_container.remove_item_from_slot(source_slot)
	elif source_container and source_container.has_method("remove_item_from_slot"):
		# Fallback: just remove the slot
		source_container.remove_item_from_slot(source_slot)
	
	# CRITICAL: Clear drag state and preview after successful world placement
	if DragManager:
		DragManager.clear_drag_state()


func _handle_item_world_drop(texture: Texture, count: int, mouse_pos: Vector2, source_container: Node, source_slot: int) -> void:
	"""Handle any item dropped on world (spawn as droppable)"""
	# Convert screen mouse_pos to world position using MouseUtil
	var world_pos = mouse_pos
	if MouseUtil:
		world_pos = MouseUtil.get_world_mouse_pos_2d(self)
	else:
		# Fallback: use viewport
		var viewport = get_viewport()
		if viewport:
			var camera = viewport.get_camera_2d()
			if camera:
				var viewport_size = viewport.size
				var camera_pos = camera.global_position
				var mouse_screen = mouse_pos
				world_pos = camera_pos + (mouse_screen - viewport_size / 2.0) / camera.zoom
	
	# Snap to grid (16x16 tiles, center at +8)
	var snapped_pos = Vector2(floor(world_pos.x / 16.0) * 16.0 + 8, floor(world_pos.y / 16.0) * 16.0 + 8)
	
	# Spawn droppable item(s) using DroppableFactory
	if DroppableFactory and hud_instance:
		# Try to get item_id from texture
		var item_id = DroppableFactory.get_item_id_from_texture(texture)
		
		if item_id.is_empty():
			# No matching item_id - spawn generic droppable with texture via factory
			# This ensures proper registration for persistence
			if texture is Texture2D:
				DroppableFactory.spawn_generic_droppable_from_texture(texture, snapped_pos, hud_instance, count)
		else:
			# Use existing item_id - spawn via factory
			for i in range(count):
				var spawn_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4)) if count > 1 else Vector2.ZERO
				var droppable = DroppableFactory.spawn_droppable(item_id, snapped_pos + spawn_offset, hud_instance)
				if droppable:
					droppable.scale = Vector2(0.75, 0.75)
	
	# Remove items from source container BEFORE clearing drag state
	if source_container and is_instance_valid(source_container):
		if source_container.has_method("remove_item_from_slot"):
			source_container.remove_item_from_slot(source_slot)
			# Ensure UI is synced after removal
			if source_container.has_method("sync_slot_ui"):
				source_container.sync_slot_ui(source_slot)
	
	# Clear drag state AFTER removing items
	if DragManager:
		DragManager.clear_drag_state()


func _on_cursor_hold_dropped_on_world(texture: Texture, count: int, mouse_pos: Vector2) -> void:
	"""Handle cursor-hold items dropped on world"""
	if texture == null or count <= 0:
		return
	
	# Convert screen mouse_pos to world position using MouseUtil
	var world_pos = mouse_pos
	if MouseUtil:
		world_pos = MouseUtil.get_world_mouse_pos_2d(self)
	else:
		# Fallback: use viewport
		var viewport = get_viewport()
		if viewport:
			var camera = viewport.get_camera_2d()
			if camera:
				var viewport_size = viewport.size
				var camera_pos = camera.global_position
				var mouse_screen = mouse_pos
				world_pos = camera_pos + (mouse_screen - viewport_size / 2.0) / camera.zoom
	
	# Snap to grid (16x16 tiles, center at +8)
	var snapped_pos = Vector2(floor(world_pos.x / 16.0) * 16.0 + 8, floor(world_pos.y / 16.0) * 16.0 + 8)
	
	# Spawn droppable item(s) using DroppableFactory
	if DroppableFactory and hud_instance:
		# Try to get item_id from texture
		var item_id = DroppableFactory.get_item_id_from_texture(texture)
		
		if item_id.is_empty():
			# No matching item_id - spawn generic droppable with texture via factory
			# This ensures proper registration for persistence
			if texture is Texture2D:
				DroppableFactory.spawn_generic_droppable_from_texture(texture, snapped_pos, hud_instance, count)
		else:
			# Use existing item_id - spawn via factory
			for i in range(count):
				var spawn_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4)) if count > 1 else Vector2.ZERO
				var droppable = DroppableFactory.spawn_droppable(item_id, snapped_pos + spawn_offset, hud_instance)
				if droppable:
					droppable.scale = Vector2(0.75, 0.75)
		
		# Consume from cursor-hold after successful spawn
		if DragManager:
			DragManager.consume_from_cursor_hold(count)


func _unhandled_input(event: InputEvent) -> void:
	"""Handle world clicks for cursor-hold world drops"""
	if not DragManager or not DragManager.cursor_hold_active:
		return
	
	# Check for left/right mouse button press
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			# Check if mouse is over any UI Control
			var viewport = get_viewport()
			if viewport:
				var hovered_control = viewport.gui_get_hovered_control()
				
				# If no UI control is hovered, treat as world click
				if hovered_control == null:
					var is_right_click = (mb.button_index == MOUSE_BUTTON_RIGHT)
					if DragManager.try_world_click_drop(is_right_click):
						# Consume the event to prevent other handlers
						get_viewport().set_input_as_handled()
						return
