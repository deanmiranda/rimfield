extends Node

# Tracks the current active scene
var current_scene: String = "farm_scene"

# Tracks the state of farm tiles by position
var farm_state: Dictionary = {}

# Current save file being used (defaults to a single save file)
var current_save_file: String = "user://save_data.json"

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

# Saves the game state to the currently active save file
func save_game(file: String = "") -> void:
	if file != "":
		set_save_file(file)

	if current_save_file == "":
		print("Error: No save file path provided.")
		return

	var save_data = {
		"farm_state": farm_state,
		"current_scene": current_scene
	}

	var file_access = FileAccess.open(current_save_file, FileAccess.WRITE)
	if file_access == null:
		print("Error: Failed to open save file for writing:", current_save_file)
		return

	file_access.store_string(JSON.stringify(save_data))
	file_access.close()
	print("Game saved to:", current_save_file)

	# Manage saved files to ensure only the 5 most recent are kept
	manage_save_files()

# Manages save files, ensuring only 5 most recent saves are kept
func manage_save_files() -> void:
	var save_dir = DirAccess.open("user://")
	if save_dir == null:
		print("Error: Could not open save directory.")
		return

	# Gather all save files that match the "save_slot_" pattern
	var save_files = []
	save_dir.list_dir_begin()  # No arguments in Godot 4
	var file_name = save_dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_slot_") and file_name.ends_with(".json"):
			save_files.append(file_name)
		file_name = save_dir.get_next()
	save_dir.list_dir_end()

	# Sort save files by timestamp and keep only the 5 newest
	save_files.sort_custom(func(a, b):
		var timestamp_a = _extract_timestamp_from_filename(a)
		var timestamp_b = _extract_timestamp_from_filename(b)
		return int(timestamp_a - timestamp_b)
	)

	# Skip the most recently saved file, assuming it will be the one with the highest timestamp
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
	current_scene = "farm_scene"  # Reset to the starting scene
	farm_state.clear()  # Clear all tile states

	# Only manage save files if we’re saving—not when starting a new game
	print("New game initialized.")
