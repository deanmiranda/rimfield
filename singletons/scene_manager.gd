extends Node

var current_scene: String = ""
var player_spawn_position: Vector2 = Vector2.ZERO  # Tracks where the player spawns
var pause_menu: Control  # Declare the PauseMenu variable

func _ready() -> void:
	# Load the PauseMenu scene
	var pause_menu_scene = load("res://scenes/ui/pause_menu.tscn")
	if not pause_menu_scene:
		print("Error: Failed to load PauseMenu scene.")
		return

	# Ensure the loaded resource is a PackedScene
	if pause_menu_scene is PackedScene:
		pause_menu = pause_menu_scene.instantiate()  # Use 'instantiate()' in Godot 4
		get_tree().get_root().call_deferred("add_child", pause_menu)  # Use deferred to avoid setup conflict
		#pause_menu.visible = false  # Ensure it's hidden by default
		print("PauseMenu added to scene:", pause_menu)
	else:
		print("Error: Loaded resource is not a PackedScene.")

func change_scene(scene_path: String, spawn_position: Vector2 = Vector2.ZERO) -> void:
	current_scene = scene_path
	player_spawn_position = spawn_position
	get_tree().change_scene_to_file(scene_path)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		pause_menu.visible = !pause_menu.visible
		print("PauseMenu visibility toggled:", pause_menu.visible)
		get_tree().paused = pause_menu.visible  # Pause/unpause the game
