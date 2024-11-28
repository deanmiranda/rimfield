extends Control

@export var default_save_file: String = "save_slot_1.json"  # Default save file for "New Game"

func _on_new_game_pressed() -> void:
	# Start a new game by initializing the GameState, saving it, and switching to the farm scene.
	GameState.new_game()
	GameState.save_game(default_save_file)  # Save initial game state
	GameState.change_scene("farm_scene")  # Start the game on the farm scene

func _on_exit_pressed() -> void:
	# Exit the game when the exit button is pressed.
	get_tree().quit()

func _on_load_game_selected(index: int) -> void:
	# Use the filename directly from the popup
	var load_game_menu = $CenterContainer/MarginContainer/VBoxContainer/LoadGame
	var popup = load_game_menu.get_popup()
	var save_file = popup.get_item_text(index)

	if save_file:
		# Attempt to load the selected save file and switch scenes if successful.
		if GameState.load_game(save_file):
			print("Game loaded successfully from:", save_file)
			GameState.change_scene(GameState.current_scene)
		else:
			print("Failed to load save file:", save_file)

func _ready() -> void:
	if not $CenterContainer/VBoxContainer/NewGame.is_connected("pressed", Callable(self, "_on_new_game_pressed")):
		$CenterContainer/VBoxContainer/NewGame.connect("pressed", Callable(self, "_on_new_game_pressed"))
	if not $CenterContainer/VBoxContainer/Exit.is_connected("pressed", Callable(self, "_on_exit_pressed")):
		$CenterContainer/VBoxContainer/Exit.connect("pressed", Callable(self, "_on_exit_pressed"))

	# Load game button setup
	var load_game_menu = $CenterContainer/MarginContainer/VBoxContainer/LoadGame
	if load_game_menu == null or not (load_game_menu is MenuButton):
		print("Error: LoadGame not found or not a MenuButton!")
		return

	var popup = load_game_menu.get_popup()
	if popup == null:
		print("Error: Popup not found in LoadGame MenuButton!")
		return

	popup.clear()

	# Check for save files
	var dir = DirAccess.open("user://")
	if dir == null:
		print("Error: Unable to access user:// directory.")
		return

	print("Checking for save files in user:// directory...")

	# Updated to use `get_files()` instead of `next()` for Godot 4.x compatibility
	for file_name in dir.get_files():
		print("Found file:", file_name)
		if file_name.ends_with(".json"):
			popup.add_item(file_name)

	# Connect dropdown signal
	if not popup.is_connected("id_pressed", Callable(self, "_on_load_game_selected")):
		popup.connect("id_pressed", Callable(self, "_on_load_game_selected"))
	print("NewGame connected:", $CenterContainer/VBoxContainer/NewGame.is_connected("pressed", Callable(self, "_on_new_game_pressed")))
	print("Exit connected:", $CenterContainer/VBoxContainer/Exit.is_connected("pressed", Callable(self, "_on_exit_pressed")))

#func _input(event: InputEvent) -> void:
	## Handle 'Esc' key to refocus on Exit button
	#if event.is_action_pressed("ui_cancel"):
		#var exit_button = $CenterContainer/VBoxContainer/Exit
		#if exit_button:
			#exit_button.grab_focus()
			#print("Focus set to Exit button.")
