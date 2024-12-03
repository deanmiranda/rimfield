extends Control

const LOAD_MENU = preload("res://scenes/ui/load_menu.tscn")  # Preload the load menu scene

func _on_new_game_pressed() -> void:
	GameState.new_game()
	#GameState.save_game()  # Create a new save file with timestamp
	GameState.change_scene("farm_scene")  # Start the game on the farm scene

func _on_exit_pressed() -> void:
	get_tree().quit()  # Exit the game

# Add a new function for the Load Game button
func _on_load_game_pressed() -> void:
	if LOAD_MENU == null:
		print("Error: LOAD_MENU could not be preloaded.")
		return
	
	var load_instance = LOAD_MENU.instantiate()
	if load_instance:
		get_tree().root.add_child(load_instance)  # Add as a child of the root to overlay on top of everything
		print("Load scene added successfully.")
	else:
		print("Error: Could not instantiate LOAD_MENU.")

func _ready() -> void:
	# Ensure New Game, Exit, and Load Game buttons are properly connected
	var new_game_button = $CenterContainer/VBoxContainer/NewGame
	if new_game_button != null:
		if not new_game_button.is_connected("pressed", Callable(self, "_on_new_game_pressed")):
			new_game_button.connect("pressed", Callable(self, "_on_new_game_pressed"))
	else:
		print("Error: NewGame button not found.")

	var exit_button = $CenterContainer/VBoxContainer/Exit
	if exit_button != null:
		if not exit_button.is_connected("pressed", Callable(self, "_on_exit_pressed")):
			exit_button.connect("pressed", Callable(self, "_on_exit_pressed"))
	else:
		print("Error: Exit button not found.")

	var saved_games_button = $CenterContainer/VBoxContainer/SavedGames
	
	if saved_games_button != null:
		if not saved_games_button.is_connected("pressed", Callable(self, "_on_load_game_pressed")):
			saved_games_button.connect("pressed", Callable(self, "_on_load_game_pressed"))

		# Set the initial visibility based on saved games
		saved_games_button.visible = _has_saved_games()
	else:
		print("Error: LoadGame button not found.")

# Function to check if saved games exist
func _has_saved_games() -> bool:
	var save_dir = DirAccess.open("user://")
	if save_dir == null:
		print("Error: Could not open save directory.")
		return false

	save_dir.list_dir_begin()
	var file_name = save_dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_slot_") and file_name.ends_with(".json"):
			save_dir.list_dir_end()  # End the directory listing after finding the save
			return true  # Found a save file
		file_name = save_dir.get_next()
	save_dir.list_dir_end()

	return false  # No save files found
