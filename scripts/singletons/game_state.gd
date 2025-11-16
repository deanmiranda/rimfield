extends Node

# Tracks the current active scene
var current_scene: String = "farm_scene"

# Tracks the state of farm tiles by position
var farm_state: Dictionary = {}

# Current save file being used
var current_save_file: String = ""  # No default save file to prevent initial save issues

# Signal to notify when a game is loaded successfully
signal game_loaded


# Updates the state of a specific tile at a given position
func update_tile_state(position: Vector2i, state: String) -> void:
	farm_state[position] = state


# Retrieves the state of a specific tile; defaults to "grass" if not set
func get_tile_state(position: Vector2i) -> String:
	return farm_state.get(position, "grass")


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
		# Generate a human-readable and unique timestamp for the save file name
		var now = Time.get_datetime_dict_from_system()
		var timestamp = "%d%02d%02d_%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute]
		current_save_file = "user://save_slot_%s.json" % timestamp

	if current_save_file == "":
		print("Error: No save file path provided.")
		return

	# Get toolkit and inventory from InventoryManager
	var toolkit_items = []
	var inventory_items = []

	if InventoryManager:
		# Save toolkit slots with stack counts and weight
		for i in range(InventoryManager.max_toolkit_slots):
			var slot_data = InventoryManager.toolkit_slots.get(
				i, {"texture": null, "count": 0, "weight": 0.0}
			)
			if slot_data["texture"] and slot_data["count"] > 0:
				toolkit_items.append(
					{
						"slot_index": i,
						"texture_path": slot_data["texture"].resource_path,
						"count": slot_data["count"],
						"weight": slot_data.get("weight", 0.0)  # Include weight in save
					}
				)

		# Save inventory slots with stack counts and weight
		for i in range(InventoryManager.max_inventory_slots):
			var slot_data = InventoryManager.inventory_slots.get(
				i, {"texture": null, "count": 0, "weight": 0.0}
			)
			if slot_data["texture"] and slot_data["count"] > 0:
				inventory_items.append(
					{
						"slot_index": i,
						"texture_path": slot_data["texture"].resource_path,
						"count": slot_data["count"],
						"weight": slot_data.get("weight", 0.0)  # Include weight in save
					}
				)

	var save_data = {
		"farm_state": farm_state,
		"current_scene": current_scene,
		"toolkit_items": toolkit_items,
		"inventory_items": inventory_items
	}

	var file_access = FileAccess.open(current_save_file, FileAccess.WRITE)
	if file_access == null:
		print("Error: Failed to open save file for writing:", current_save_file)
		return

	file_access.store_string(JSON.stringify(save_data))
	file_access.close()
	print("Game saved to:", current_save_file)


# Loads the game state from a specified save file
func load_game(file: String = "") -> bool:
	if file != "":
		set_save_file(file)

	if not FileAccess.file_exists(current_save_file):
		print("Error: Save file does not exist:", current_save_file)
		return false

	var file_access = FileAccess.open(current_save_file, FileAccess.READ)
	if file_access == null:
		print("Error: Failed to open save file for reading:", current_save_file)
		return false

	var json = JSON.new()
	var parse_status = json.parse(file_access.get_as_text())
	file_access.close()

	if parse_status == OK:
		var save_data = json.data
		farm_state = save_data.get("farm_state", {})
		current_scene = save_data.get("current_scene", "farm_scene")
		print("Game loaded successfully from:", current_save_file)

		# Restore toolkit and inventory to InventoryManager
		if InventoryManager:
			# Clear existing data
			for i in range(InventoryManager.max_toolkit_slots):
				InventoryManager.toolkit_slots[i] = {"texture": null, "count": 0, "weight": 0.0}
			for i in range(InventoryManager.max_inventory_slots):
				InventoryManager.inventory_slots[i] = {"texture": null, "count": 0, "weight": 0.0}

			# Load toolkit items
			if save_data.has("toolkit_items"):
				for item_data in save_data["toolkit_items"]:
					var slot_index = item_data.get("slot_index", -1)
					var texture_path = item_data.get("texture_path", "")
					var count = item_data.get("count", 1)
					var weight = item_data.get("weight", 0.0)  # Load weight if present, default to 0.0

					if slot_index >= 0 and texture_path != "":
						var texture = load(texture_path)
						if texture:
							InventoryManager.toolkit_slots[slot_index] = {
								"texture": texture, "count": count, "weight": weight
							}
						else:
							print("Warning: Could not load texture:", texture_path)

			# Load inventory items
			if save_data.has("inventory_items"):
				for item_data in save_data["inventory_items"]:
					var slot_index = item_data.get("slot_index", -1)
					var texture_path = item_data.get("texture_path", "")
					var count = item_data.get("count", 1)
					var weight = item_data.get("weight", 0.0)  # Load weight if present, default to 0.0

					if slot_index >= 0 and texture_path != "":
						var texture = load(texture_path)
						if texture:
							InventoryManager.inventory_slots[slot_index] = {
								"texture": texture, "count": count, "weight": weight
							}
						else:
							print("Warning: Could not load texture:", texture_path)

			print(
				"Loaded ",
				save_data.get("toolkit_items", []).size(),
				" toolkit items and ",
				save_data.get("inventory_items", []).size(),
				" inventory items."
			)

		emit_signal("game_loaded")

		# Explicitly change to the loaded scene after loading
		get_tree().paused = false  # Unpause the game if paused
		change_scene(current_scene)

		return true
	else:
		print("Error parsing save file: Error Code", parse_status)
		return false


func manage_save_files() -> void:
	var save_dir = DirAccess.open("user://")
	if save_dir == null:
		print("Error: Could not open save directory.")
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

	# Sort save files by timestamp and keep only the 5 newest
	save_files.sort_custom(
		func(a, b):
			var timestamp_a = _extract_timestamp_from_filename(a)
			var timestamp_b = _extract_timestamp_from_filename(b)
			return int(timestamp_a - timestamp_b)
	)

	# Remove old saves, keeping only the 5 most recent
	while save_files.size() > 5:
		var oldest_save = save_files.pop_front()
		if oldest_save == current_save_file.replace("user://", ""):
			print("Skipping current save file:", oldest_save)
			continue

		var delete_dir = DirAccess.open("user://")
		if delete_dir:
			var delete_result = delete_dir.remove(oldest_save)
			if delete_result == OK:
				print("Deleted old save file:", oldest_save)
			else:
				print("Error: Failed to delete old save file:", oldest_save)


# Helper function to extract timestamp from save file name
func _extract_timestamp_from_filename(file_name: String) -> float:
	var components = file_name.split("_")
	if components.size() > 1:
		return components[-1].to_float()  # Extract the last part and convert to float
	return 0.0


# Clears the current game state and prepares a fresh start
func new_game() -> void:
	# Reset to the starting scene
	current_scene = "farm_scene"

	# Clear all tile states
	farm_state.clear()
