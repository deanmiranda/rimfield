extends Control

@export var default_save_file: String = "save_slot_1.json"  # Default save file for "New Game"

func _on_new_game_pressed() -> void:
	GameState.new_game()
	GameState.save_game(default_save_file)  # Save initial game state
	GameState.change_scene("farm_scene")  # Start the game on the farm scene

func _on_exit_pressed() -> void:
	get_tree().quit()  # Exit the game

func _on_load_game_selected(index: int) -> void:
	var load_game_menu = $VBoxContainer/ColorRect/LoadGame
	var popup = load_game_menu.get_popup()
	var save_file = popup.get_item_text(index)

	if save_file:
		if GameState.load_game(save_file):
			print("Game loaded successfully from:", save_file)
			GameState.change_scene(GameState.current_scene)
		else:
			print("Failed to load save file:", save_file)

func _ready() -> void:
	# Ensure New Game and Exit buttons are properly connected
	if not $CenterContainer/VBoxContainer/NewGame.is_connected("pressed", Callable(self, "_on_new_game_pressed")):
		$CenterContainer/VBoxContainer/NewGame.connect("pressed", Callable(self, "_on_new_game_pressed"))
	if not $CenterContainer/VBoxContainer/Exit.is_connected("pressed", Callable(self, "_on_exit_pressed")):
		$CenterContainer/VBoxContainer/Exit.connect("pressed", Callable(self, "_on_exit_pressed"))

	# Load game button setup
	var load_game_menu = $VBoxContainer/ColorRect/LoadGame
	if load_game_menu == null or not (load_game_menu is MenuButton):
		return

	# Load game menu popup setup
	var popup = load_game_menu.get_popup()
	if popup == null:
		return
	popup.clear()

	# Check for save files
	var dir = DirAccess.open("user://")
	if dir == null:
		return

	# List all JSON save files in the user directory
	for file_name in dir.get_files():
		print("Found file:", file_name)
		if file_name.ends_with(".json"):
			popup.add_item(file_name)

	# Connect the dropdown signal
	if not popup.is_connected("id_pressed", Callable(self, "_on_load_game_selected")):
		popup.connect("id_pressed", Callable(self, "_on_load_game_selected"))
