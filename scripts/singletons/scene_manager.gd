extends Node

var current_scene: String = ""
var player_spawn_position: Vector2 = Vector2.ZERO
var paused = false

func _ready() -> void:
	# Removed global instantiation of pause menu from here
	pass

func change_scene(scene_path: String, spawn_position: Vector2 = Vector2.ZERO) -> void:
	current_scene = scene_path
	player_spawn_position = spawn_position

	get_tree().change_scene_to_file(scene_path)

	# Print for debugging
	#print("Scene changed to:", current_scene)

	# After changing the scene, handle pause state appropriately
	if current_scene.ends_with("main_menu.tscn"):
		get_tree().paused = false  # Ensure the tree is not paused on the main menu
	else:
		get_tree().paused = false  # Ensure the tree is not paused when switching to gameplay


func handle_pause_request(paused_state: bool):
	get_tree().paused = paused_state
	paused = paused_state
