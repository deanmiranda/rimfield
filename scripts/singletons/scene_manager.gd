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


func start_in_house(_from_new_game: bool = true) -> void:
	"""Central function to start the player in the house scene.
	
	Args:
		_from_new_game: True if starting a new game, False if loading a save.
		For now, both cases use bed spawn (default). Save data is applied
		after scene load by the save system.
	"""
	# Clear any existing spawn position override so house scene uses bed spawn
	player_spawn_position = Vector2.ZERO
	
	# Wait for scene tree to be fully ready before changing scenes
	# This prevents timing issues when called from button presses
	await get_tree().process_frame
	
	var house_scene_path = "res://scenes/world/house_scene.tscn"
	
	# Verify scene file exists before attempting to load
	if not ResourceLoader.exists(house_scene_path):
		print("Error: House scene file not found at: ", house_scene_path)
		return
	
	# Change to house scene (will use bed spawn by default)
	await change_scene(house_scene_path, Vector2.ZERO)
