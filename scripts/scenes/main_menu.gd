extends Control

const LOAD_MENU = preload("res://scenes/ui/load_menu.tscn") # Preload the load menu scene

func _on_new_game_pressed() -> void:
	# Stop intro music before starting game
	_stop_intro_music()
	
	GameState.new_game()
	#GameState.save_game()  # Create a new save file with timestamp
	SceneManager.start_in_house(true) # Start the game in the house scene


func _stop_intro_music() -> void:
	"""Stop the intro music player"""
	var intro_music = get_node_or_null("IntroMusic")
	if intro_music and intro_music is AudioStreamPlayer:
		intro_music.stop()

func _on_exit_pressed() -> void:
	get_tree().quit() # Exit the game

# Add a new function for the Load Game button
func _on_load_game_pressed() -> void:
	if LOAD_MENU == null:
		return
	
	var load_instance = LOAD_MENU.instantiate()
	if load_instance:
		get_tree().root.add_child(load_instance) # Add as a child of the root to overlay on top of everything

func _ready() -> void:
	# Ensure New Game, Exit, and Load Game buttons are properly connected
	var new_game_button = $CenterContainer/VBoxContainer/NewGame
	if new_game_button != null:
		if not new_game_button.is_connected("pressed", Callable(self, "_on_new_game_pressed")):
			new_game_button.connect("pressed", Callable(self, "_on_new_game_pressed"))

	var exit_button = $CenterContainer/VBoxContainer/Exit
	if exit_button != null:
		if not exit_button.is_connected("pressed", Callable(self, "_on_exit_pressed")):
			exit_button.connect("pressed", Callable(self, "_on_exit_pressed"))

	var saved_games_button = $CenterContainer/VBoxContainer/SavedGames
	
	if saved_games_button != null:
		if not saved_games_button.is_connected("pressed", Callable(self, "_on_load_game_pressed")):
			saved_games_button.connect("pressed", Callable(self, "_on_load_game_pressed"))

		# Set the initial visibility based on saved games
		saved_games_button.visible = _has_saved_games()

# Function to check if saved games exist
func _has_saved_games() -> bool:
	var save_dir = DirAccess.open("user://")
	if save_dir == null:
		return false

	save_dir.list_dir_begin()
	var file_name = save_dir.get_next()
	while file_name != "":
		if file_name.begins_with("save_slot_") and file_name.ends_with(".json"):
			save_dir.list_dir_end() # End the directory listing after finding the save
			return true # Found a save file
		file_name = save_dir.get_next()
	save_dir.list_dir_end()

	return false # No save files found
