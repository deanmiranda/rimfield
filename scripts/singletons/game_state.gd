extends Node

# Tracks the current active scene
var current_scene: String = "farm_scene"

# Tracks the state of farm tiles by position
# Format: {Vector2i: String} for simple states ("grass", "soil", "tilled", "planted", "planted_tilled")
# OR {Vector2i: Dictionary} for tiles with crop data:
# {
#   "state": "planted",
#   "is_watered": bool,
#   "last_watered_day": int,
#   "crop_id": String (e.g., "seed_basic"),
#   "growth_stages": int,
#   "days_per_stage": int,
#   "current_stage": int,
#   "days_watered_toward_next_stage": int
# }
var farm_state: Dictionary = {}

# Crop data structure for planted tiles
# This extends farm_state with crop-specific information

# Current save file being used
var current_save_file: String = "" # No default save file to prevent initial save issues

# Day 1 spawn gate: prevents re-spawning farm random droppables across scene reloads
var day1_farm_random_droppables_spawned: bool = false

# Signal to notify when a game is loaded successfully
signal game_loaded


# Updates the state of a specific tile at a given position
func update_tile_state(position: Vector2i, state: String) -> void:
	# Ensure position is Vector2i (not string) for consistent key format
	var key: Vector2i = position
	
	# If tile already has crop data, preserve it and update state
	if farm_state.has(key) and farm_state[key] is Dictionary:
		var tile_data = farm_state[key] as Dictionary
		tile_data["state"] = state
		farm_state[key] = tile_data
	else:
		# Simple state update (no crop data)
		farm_state[key] = state


# Retrieves the state of a specific tile; defaults to "grass" if not set
func get_tile_state(position: Vector2i) -> String:
	var tile_data = farm_state.get(position, "grass")
	if tile_data is Dictionary:
		return tile_data.get("state", "grass")
	return tile_data if tile_data is String else "grass"


# Gets full tile data (including crop info) or returns simple state string
func get_tile_data(position: Vector2i) -> Variant:
	return farm_state.get(position, "grass")


# Updates tile with crop data
func update_tile_crop_data(position: Vector2i, crop_data: Dictionary) -> void:
	var key: Vector2i = position
	var existing_data = farm_state.get(key, {})
	
	if existing_data is Dictionary:
		# Merge with existing crop data
		for k in crop_data:
			existing_data[k] = crop_data[k]
		farm_state[key] = existing_data
	else:
		# Convert simple state to dictionary
		var new_data = {"state": existing_data if existing_data is String else "grass"}
		for k in crop_data:
			new_data[k] = crop_data[k]
		farm_state[key] = new_data


# Sets tile as watered
func set_tile_watered(position: Vector2i, day: int) -> void:
	var key: Vector2i = position
	var tile_data = farm_state.get(key, {})
	
	if not (tile_data is Dictionary):
		# Convert simple state to dictionary
		var old_state = tile_data if tile_data is String else "grass"
		tile_data = {"state": old_state}
	
	# Preserve existing state if it exists, otherwise keep current state
	# This ensures we don't overwrite the state that was set by update_tile_state
	if not tile_data.has("state"):
		tile_data["state"] = "grass" # Default fallback
	
	# CRITICAL FIX: Store both day and absolute day for proper tracking across season boundaries
	tile_data["is_watered"] = true
	# Note: 'day' parameter is now expected to be the absolute day (for consistency)
	# But we also store the regular day for backwards compatibility
	if GameTimeManager:
		tile_data["last_watered_day"] = GameTimeManager.day
		tile_data["last_watered_day_absolute"] = GameTimeManager.get_absolute_day()
	else:
		# Fallback if GameTimeManager not available
		tile_data["last_watered_day"] = day
		tile_data["last_watered_day_absolute"] = day
	farm_state[key] = tile_data


# Resets watering state for all tiles (called on new day)
func reset_watering_states() -> void:
	for key in farm_state.keys():
		var tile_data = farm_state[key]
		if tile_data is Dictionary:
			tile_data["is_watered"] = false
			farm_state[key] = tile_data


# Changes the active scene in the game
func change_scene(new_scene: String) -> void:
	current_scene = new_scene
	get_tree().change_scene_to_file("res://scenes/world/%s.tscn" % new_scene)


# Sets the save file path to use for saving and loading
func set_save_file(file: String) -> void:
	if file.begins_with("user://"):
		current_save_file = file
	else:
		current_save_file = "user://%s" % file


# Saves the game state to a new save file with a timestamp-based name
func save_game(file: String = "") -> void:
	if file != "":
		set_save_file(file)
	else:
		# Generate save file name using in-game date + system time for uniqueness
		# Format: save_slot_YEAR_SEASON_DAY_UNIXTIME.json
		# Using unix time ensures proper sorting and uniqueness
		if GameTimeManager:
			var game_day = GameTimeManager.day
			var game_season = GameTimeManager.season
			var game_year = GameTimeManager.year
			var unix_time = Time.get_unix_time_from_system()
			# Combine game date with unix timestamp for proper sorting
			var timestamp = "%d_%d_%d_%d" % [game_year, game_season, game_day, unix_time]
			current_save_file = "user://save_slot_%s.json" % timestamp
		else:
			# Fallback to system date + unix time if GameTimeManager not available
			var now = Time.get_datetime_dict_from_system()
			var unix_time = Time.get_unix_time_from_system()
			var timestamp = "%d%02d%02d_%d" % [now.year, now.month, now.day, unix_time]
			current_save_file = "user://save_slot_%s.json" % timestamp

	if current_save_file == "":
		return

	# Get toolkit and inventory from containers (NEW SYSTEM)
	var toolkit_items = []
	var inventory_items = []

	if InventoryManager:
		# Save toolkit from ToolkitContainer (NEW SYSTEM)
		if InventoryManager.toolkit_container:
			for i in range(InventoryManager.toolkit_container.slot_count):
				var slot_data = InventoryManager.toolkit_container.inventory_data.get(
					i, {"texture": null, "count": 0, "weight": 0.0}
				)
				if slot_data["texture"] and slot_data["count"] > 0:
					toolkit_items.append(
						{
							"slot_index": i,
							"texture_path": slot_data["texture"].resource_path,
							"count": int(slot_data["count"]),
							"weight": float(slot_data.get("weight", 0.0))
						}
					)
		else:
			# Fallback to legacy dict if container doesn't exist
			for i in range(InventoryManager.max_toolkit_slots):
				var slot_data = InventoryManager.toolkit_slots.get(
					i, {"texture": null, "count": 0, "weight": 0.0}
				)
				if slot_data["texture"] and slot_data["count"] > 0:
					toolkit_items.append(
						{
							"slot_index": i,
							"texture_path": slot_data["texture"].resource_path,
							"count": int(slot_data["count"]),
							"weight": float(slot_data.get("weight", 0.0))
						}
					)

		# Save inventory from PlayerInventoryContainer (NEW SYSTEM)
		if InventoryManager.player_inventory_container:
			for i in range(InventoryManager.player_inventory_container.slot_count):
				var slot_data = InventoryManager.player_inventory_container.inventory_data.get(
					i, {"texture": null, "count": 0, "weight": 0.0}
				)
				if slot_data["texture"] and slot_data["count"] > 0:
					inventory_items.append(
						{
							"slot_index": i,
							"texture_path": slot_data["texture"].resource_path,
							"count": int(slot_data["count"]),
							"weight": float(slot_data.get("weight", 0.0))
						}
					)
		else:
			# Fallback to legacy dict if container doesn't exist
			for i in range(InventoryManager.max_inventory_slots):
				var slot_data = InventoryManager.inventory_slots.get(
					i, {"texture": null, "count": 0, "weight": 0.0}
				)
				if slot_data["texture"] and slot_data["count"] > 0:
					inventory_items.append(
						{
							"slot_index": i,
							"texture_path": slot_data["texture"].resource_path,
							"count": int(slot_data["count"]),
							"weight": float(slot_data.get("weight", 0.0))
						}
					)

	# Convert farm_state to JSON-serializable format
	# Vector2i keys need to be converted to strings for JSON
	var serialized_farm_state = {}
	for key in farm_state.keys():
		var key_str = "%d,%d" % [key.x, key.y]
		var tile_data = farm_state[key]
		if tile_data is Dictionary:
			serialized_farm_state[key_str] = tile_data
		else:
			serialized_farm_state[key_str] = tile_data
	
	# Debug: Log how many tiles are being saved
	
	# Get player position from current scene
	# Player structure: scene root -> "Player" (Node2D) -> "Player" (CharacterBody2D)
	var player_position = Vector2.ZERO
	var current_scene_node = get_tree().current_scene
	if current_scene_node:
		var player_root = current_scene_node.get_node_or_null("Player")
		if player_root:
			var player_body = player_root.get_node_or_null("Player")
			if player_body:
				player_position = player_body.global_position
	
	# Get chest data from ChestManager
	var chest_data = []
	if ChestManager:
		chest_data = ChestManager.serialize_all_chests()
	
	# Get droppable data from DroppableFactory (house/farm only)
	var droppable_data = []
	if DroppableFactory:
		droppable_data = DroppableFactory.serialize_droppables()
	
	var save_data = {
		"farm_state": serialized_farm_state,
		"current_scene": current_scene,
		"player_position": {"x": player_position.x, "y": player_position.y},
		"toolkit_items": toolkit_items,
		"inventory_items": inventory_items,
		"chest_data": chest_data,
		"droppable_data": droppable_data,
		"day1_farm_random_droppables_spawned": day1_farm_random_droppables_spawned,
		"game_time": {
			"day": GameTimeManager.day if GameTimeManager else 1,
			"season": GameTimeManager.season if GameTimeManager else 0,
			"year": GameTimeManager.year if GameTimeManager else 1
		}
	}

	var file_access = FileAccess.open(current_save_file, FileAccess.WRITE)
	if file_access == null:
		return

	file_access.store_string(JSON.stringify(save_data))
	file_access.close()
	
	# Auto-manage save files: delete oldest saves, keeping only the most recent ones
	manage_save_files()


# Loads the game state from a specified save file
func load_game(file: String = "") -> bool:
	if file != "":
		set_save_file(file)

	if not FileAccess.file_exists(current_save_file):
		return false

	var file_access = FileAccess.open(current_save_file, FileAccess.READ)
	if file_access == null:
		return false

	var json = JSON.new()
	var parse_status = json.parse(file_access.get_as_text())
	file_access.close()

	if parse_status == OK:
		var save_data = json.data
		
		# Deserialize farm_state (convert string keys back to Vector2i)
		var loaded_farm_state = save_data.get("farm_state", {})
		if loaded_farm_state.size() > 0:
			print("[GameState] Sample farm_state keys: %s" % str(loaded_farm_state.keys().slice(0, 5)))
		
		farm_state.clear()
		for key_str in loaded_farm_state.keys():
			var key_parts = key_str.split(",")
			if key_parts.size() == 2:
				var key = Vector2i(int(key_parts[0]), int(key_parts[1]))
				farm_state[key] = loaded_farm_state[key_str]
			else:
				print("[GameState] Warning: Invalid key format in save file: %s" % key_str)
		
		# Debug: Log how many tiles were loaded
		
		current_scene = save_data.get("current_scene", "farm_scene")
		
		# Restore Day 1 spawn flag
		day1_farm_random_droppables_spawned = save_data.get("day1_farm_random_droppables_spawned", false)
		
		# Restore game time if present
		if save_data.has("game_time") and GameTimeManager:
			var time_data = save_data["game_time"]
			GameTimeManager.day = time_data.get("day", 1)
			GameTimeManager.season = time_data.get("season", 0)
			GameTimeManager.year = time_data.get("year", 1)
		
		# Restore player position if present
		if save_data.has("player_position") and SceneManager:
			var pos_data = save_data["player_position"]
			SceneManager.player_spawn_position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))
		

		# Restore toolkit and inventory to InventoryManager
		if InventoryManager:
			# CRITICAL: Clear legacy dicts completely to prevent mixed-key bug
			InventoryManager.toolkit_slots.clear()
			InventoryManager.inventory_slots.clear()
			
			# Initialize with empty slots (int keys only)
			for i in range(InventoryManager.max_toolkit_slots):
				InventoryManager.toolkit_slots[i] = {"texture": null, "count": 0, "weight": 0.0}
			for i in range(InventoryManager.max_inventory_slots):
				InventoryManager.inventory_slots[i] = {"texture": null, "count": 0, "weight": 0.0}

			# Load toolkit items
			if save_data.has("toolkit_items"):
				for item_data in save_data["toolkit_items"]:
					var slot_index = item_data.get("slot_index", -1)
					slot_index = int(slot_index)
					var texture_path = item_data.get("texture_path", "")
					var count = item_data.get("count", 1)
					var weight = item_data.get("weight", 0.0)

					if slot_index >= 0 and texture_path != "":
						var texture = load(texture_path)
						if texture:
							var float_key = float(slot_index)
							if InventoryManager.toolkit_slots.has(float_key):
								InventoryManager.toolkit_slots.erase(float_key)
							InventoryManager.toolkit_slots[slot_index] = {
								"texture": texture, "count": int(count), "weight": float(weight)
							}
						else:
							print("Warning: Could not load texture:", texture_path)

			# Load inventory items
			if save_data.has("inventory_items"):
				for item_data in save_data["inventory_items"]:
					var slot_index = item_data.get("slot_index", -1)
					slot_index = int(slot_index)
					var texture_path = item_data.get("texture_path", "")
					var count = item_data.get("count", 1)
					var weight = item_data.get("weight", 0.0)

					if slot_index >= 0 and texture_path != "":
						var texture = load(texture_path)
						if texture:
							var float_key = float(slot_index)
							if InventoryManager.inventory_slots.has(float_key):
								InventoryManager.inventory_slots.erase(float_key)
							InventoryManager.inventory_slots[slot_index] = {
								"texture": texture, "count": int(count), "weight": float(weight)
							}
						else:
							print("Warning: Could not load texture:", texture_path)
			
			# Force containers to re-migrate from legacy dicts after load
			# This ensures containers get the loaded data even if they already migrated during new_game()
			# Clear containers first, then force migration to restore saved state
			if InventoryManager.toolkit_container:
				# Clear container data before migration (restore from saved state)
				for i in range(InventoryManager.toolkit_container.slot_count):
					InventoryManager.toolkit_container.inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
				InventoryManager.toolkit_container._migrate_from_inventory_manager(true)
				InventoryManager.toolkit_container.sync_ui()
			if InventoryManager.player_inventory_container:
				# Clear container data before migration (restore from saved state)
				for i in range(InventoryManager.player_inventory_container.slot_count):
					InventoryManager.player_inventory_container.inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
				InventoryManager.player_inventory_container._migrate_from_inventory_manager(true)
				InventoryManager.player_inventory_container.sync_ui()
			
			# Sync UI after loading inventory
			InventoryManager.sync_inventory_ui()
			InventoryManager.sync_toolkit_ui()
		
		# Clear all node references from chest registry (invalidate old nodes before scene change)
		# This prevents stale chest nodes from triggering register_chest() in wrong scenes
		if ChestManager:
			for chest_id in ChestManager.chest_registry.keys():
				var chest_data = ChestManager.chest_registry[chest_id]
				var old_node = chest_data.get("node")
				if old_node and is_instance_valid(old_node):
					# Remove from scene if still attached
					if old_node.get_parent():
						old_node.get_parent().remove_child(old_node)
					old_node.queue_free()
				# Clear node reference
				ChestManager.chest_registry[chest_id]["node"] = null
		
		# Restore chest data
		if save_data.has("chest_data") and ChestManager:
			ChestManager.restore_chests_from_save(save_data["chest_data"])
		
		# Restore droppable data (house/farm only)
		if save_data.has("droppable_data") and DroppableFactory:
			DroppableFactory.restore_droppables_from_save(save_data["droppable_data"])

		emit_signal("game_loaded")

		# Always start in house scene after loading (save data is already applied)
		get_tree().paused = false # Unpause the game if paused
		
		# Stop intro music if it's playing (from main menu)
		_stop_intro_music()
		
		# Start background music if not already playing
		if MusicManager and not MusicManager.is_playing:
			MusicManager.start_music()
		
		SceneManager.start_in_house(false)

		return true
	else:
		return false


func manage_save_files() -> void:
	var save_dir = DirAccess.open("user://")
	if save_dir == null:
		return

	# Gather all save files that match the "save_slot_" pattern
	var save_files = []
	save_dir.list_dir_begin()
	var file_name = save_dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_slot_") and file_name.ends_with(".json"):
			save_files.append(file_name)
		file_name = save_dir.get_next()
	save_dir.list_dir_end()

	# Sort save files by modification time (oldest first) - FIFO
	# Get file modification times for proper sorting
	var save_files_with_time = []
	for save_file_name in save_files:
		var file_path = "user://" + save_file_name
		if FileAccess.file_exists(file_path):
			# Get modification time without opening the file
			var mod_time = FileAccess.get_modified_time(file_path)
			save_files_with_time.append({"name": save_file_name, "time": mod_time})
	
	# Sort by modification time (oldest first)
	save_files_with_time.sort_custom(
		func(a, b):
			return a.time < b.time
	)
	
	# Remove old saves, keeping only the 10 most recent (FIFO - First In First Out)
	const MAX_SAVE_FILES = 10
	
	while save_files_with_time.size() > MAX_SAVE_FILES:
		var oldest_save = save_files_with_time.pop_front()
		var oldest_file_name = oldest_save.name
		
		# Don't delete the current save file
		var current_file_name = current_save_file.replace("user://", "")
		if oldest_file_name == current_file_name:
			# Put it back at the end so we don't lose it
			save_files_with_time.append(oldest_save)
			continue

		var delete_dir = DirAccess.open("user://")
		if delete_dir:
			var delete_result = delete_dir.remove(oldest_file_name)
			if delete_result == OK:
				pass # Save file deleted successfully
			else:
				print("[GameState] Error: Failed to delete old save file: %s" % oldest_file_name)


# Helper function to stop intro music from main menu
func _stop_intro_music() -> void:
	"""Stop intro music if it's playing (from main menu scene)"""
	var main_menu = get_tree().current_scene
	if main_menu and main_menu.name == "Main_Menu":
		var intro_music = main_menu.get_node_or_null("IntroMusic")
		if intro_music and intro_music is AudioStreamPlayer:
			intro_music.stop()
			print("[GameState] Stopped intro music")


# Helper function to extract timestamp from save file name
func _extract_timestamp_from_filename(file_name: String) -> float:
	var components = file_name.split("_")
	if components.size() > 1:
		return components[-1].to_float() # Extract the last part and convert to float
	return 0.0


# Clears the current game state and prepares a fresh start
func new_game() -> void:
	# Reset to the starting scene (house)
	current_scene = "house_scene"

	# Clear all tile states
	farm_state.clear()
	
	# Reset Day 1 spawn flag
	day1_farm_random_droppables_spawned = false
	
	# Clear all chests
	if ChestManager:
		ChestManager.reset_all()
	
	# Clear all droppables
	if DroppableFactory:
		DroppableFactory.reset_all_droppables()
	
	# Clear toolkit and inventory (both legacy dicts and new container system)
	if InventoryManager:
		# Clear legacy dicts
		for i in range(InventoryManager.max_toolkit_slots):
			InventoryManager.toolkit_slots[i] = {"texture": null, "count": 0, "weight": 0.0}
		for i in range(InventoryManager.max_inventory_slots):
			InventoryManager.inventory_slots[i] = {"texture": null, "count": 0, "weight": 0.0}
		
		# Clear new container system (clear inventory_data dictionaries)
		if InventoryManager.toolkit_container:
			for i in range(InventoryManager.toolkit_container.slot_count):
				InventoryManager.toolkit_container.inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
			InventoryManager.toolkit_container.sync_ui()
		if InventoryManager.player_inventory_container:
			for i in range(InventoryManager.player_inventory_container.slot_count):
				InventoryManager.player_inventory_container.inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
			InventoryManager.player_inventory_container.sync_ui()
	
	# Tools/chest/seeds are now spawned as droppables on Day 1, not initialized in HUD
	# This ensures HUD is clear on new game
	
	# Stop intro music if it's playing (from main menu)
	_stop_intro_music()
	
	# Start background music
	if MusicManager:
		MusicManager.start_music()
