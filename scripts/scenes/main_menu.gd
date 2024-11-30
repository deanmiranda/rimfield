extends Control

const LOAD_MENU = preload("res://scenes/ui/load_menu.tscn")  # Preload the load menu scene

@export var default_save_file: String = "save_slot_1.json"  # Default save file for "New Game"

func _on_new_game_pressed() -> void:
	GameState.new_game()
	GameState.save_game(default_save_file)  # Save initial game state
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

	var load_game_button = $VBoxContainer/ColorRect/LoadGame
	if load_game_button != null:
		if not load_game_button.is_connected("pressed", Callable(self, "_on_load_game_pressed")):
			load_game_button.connect("pressed", Callable(self, "_on_load_game_pressed"))
	else:
		print("Error: LoadGameButton not found.")
