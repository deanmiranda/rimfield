extends Control

@export var default_save_file: String = "save_slot_1.json"  # Default save file for "New Game"

func _on_new_game_pressed() -> void:
	GameState.new_game()
	GameState.save_game(default_save_file)  # Save initial game state
	GameState.change_scene("farm_scene")  # Start the game on the farm scene

func _on_exit_pressed() -> void:
	get_tree().quit()  # Exit the game

func _on_load_game_selected(index: int) -> void:
	# Map index to save slot filenames
	var save_file = ""
	match index:
		0:
			save_file = "save_slot_1.json"
		1:
			save_file = "save_slot_2.json"
		2:
			save_file = "save_slot_3.json"
		3:
			save_file = "save_slot_4.json"
		_:
			save_file = null

	if save_file:
		if GameState.load_game(save_file):
			print("Game loaded successfully from:", save_file)
			GameState.change_scene(GameState.current_scene)  # Load into the saved scene
		else:
			print("Failed to load save file:", save_file)

func _ready() -> void:
	$CenterContainer/VBoxContainer/NewGame.connect("pressed", Callable(self, "_on_new_game_pressed"))
	$CenterContainer/VBoxContainer/LoadGame.get_popup().connect("id_pressed", Callable(self, "_on_load_game_selected"))
	$CenterContainer/VBoxContainer/Exit.connect("pressed", Callable(self, "_on_exit_pressed"))
