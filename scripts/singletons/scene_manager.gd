extends Node

var current_scene: String = ""
var player_spawn_position: Vector2 = Vector2.ZERO
var paused = false


func _ready() -> void:
	# Removed global instantiation of pause menu from here
	pass


func change_scene(scene_path: String, spawn_position: Vector2 = Vector2.ZERO) -> void:
	"""Change scene with fade transition effect"""
	current_scene = scene_path
	player_spawn_position = spawn_position

	# Start fade to black
	if TransitionManager:
		await TransitionManager.fade_to_black(0.25)

	# Change the scene while screen is black
	get_tree().change_scene_to_file(scene_path)

	# Wait multiple frames for scene to fully load and initialize
	for i in range(3):
		await get_tree().process_frame

	# After changing the scene, handle pause state appropriately
	if current_scene.ends_with("main_menu.tscn"):
		get_tree().paused = false # Ensure the tree is not paused on the main menu
	else:
		get_tree().paused = false # Ensure the tree is not paused when switching to gameplay

	# Fade back from black after scene is ready
	if TransitionManager:
		await TransitionManager.fade_from_black(0.25)


func handle_pause_request(paused_state: bool):
	get_tree().paused = paused_state
	paused = paused_state
