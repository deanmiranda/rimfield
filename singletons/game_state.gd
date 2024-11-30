extends Node

# Tracks the current active scene
var current_scene: String = "farm_scene"

# Tracks the state of farm tiles by position
var farm_state: Dictionary = {}

# Current save file being used (defaults to a single save file)
var current_save_file: String = "user://save_data.json"  # Corrected to include user:// only once

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
		current_save_file = file  # Use as is if already prefixed correctly
	else:
		current_save_file = "user://%s" % file  # Prefix if needed

# Saves the game state to the currently active save file
func save_game(file: String = "") -> void:
	if file != "":
		set_save_file(file)  # Dynamically update the save file path

	# Ensure current_save_file is valid
	if current_save_file == "":
		print("Error: No save file path provided.")
		return

	# Prepare save data
	var save_data = {
		"farm_state": farm_state,
		"current_scene": current_scene
	}

	# Attempt to open the file for writing
	var file_access = FileAccess.open(current_save_file, FileAccess.WRITE)
	if file_access == null:
		print("Error: Failed to open save file for writing:", current_save_file)
		return

	# Save the data to the file
	file_access.store_string(JSON.stringify(save_data))
	file_access.close()
	print("Game saved to:", current_save_file)

# Loads the game state from the currently active save file
func load_game(file: String = "") -> bool:
	if file != "":
		set_save_file(file)  # Dynamically update the save file path
	if FileAccess.file_exists(current_save_file):
		var file_access = FileAccess.open(current_save_file, FileAccess.READ)
		var json = JSON.new()
		var parse_status = json.parse(file_access.get_as_text())
		file_access.close()

		if parse_status == OK:
			var save_data = json.data
			farm_state.clear()
			for key in save_data.get("farm_state", {}).keys():
				var position = Vector2i(key.split(",")[0].to_int(), key.split(",")[1].to_int())
				farm_state[position] = save_data["farm_state"][key]
			current_scene = save_data.get("current_scene", "farm_scene")
			print("Game loaded successfully from:", current_save_file)
			emit_signal("game_loaded")
			return true
		else:
			print("Error parsing save file: Error Code", parse_status)
			return false
	else:
		print("No save file found at:", current_save_file)
		return false

# Clears the current game state and prepares a fresh start
func new_game() -> void:
	current_scene = "farm_scene"  # Reset to the starting scene
	farm_state.clear()  # Clear all tile states
	print("New game initialized.")
