extends Area2D

const HOUSE_SCENE_PATH = "res://scenes/world/house_scene.tscn"
const HOUSE_SPAWN_POSITION = Vector2(-8, 54) # Door spawn position inside house (matches DoorSpawnPoint marker)

var player: Node = null # Reference to the player
var player_in_zone: bool = false # Tracks if the player is in the zone
var is_transitioning: bool = false # Prevent multiple transitions


func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player using type or class name
	if body is CharacterBody2D and body.has_method("start_interaction"):
		player = body # Store reference to the player
		player_in_zone = true # Set player_in_zone to true
		# Notify the player
		player.start_interaction("house")


func _on_body_exited(body: Node2D) -> void:
	# Check if the body is the player
	if body == player:
		player_in_zone = false # Set player_in_zone to false
		is_transitioning = false # Reset transition flag
		# Notify the player
		if player.has_method("stop_interaction"):
			player.stop_interaction()
		player = null # Clear the player reference


func _input(event: InputEvent) -> void:
	# Use _input() instead of _process() polling (follows .cursor/rules/godot.md)
	if player_in_zone and event.is_action_pressed("ui_interact") and not is_transitioning:
		is_transitioning = true
		# CRITICAL: Mark input as handled BEFORE scene change to prevent other handlers from processing it
		# After the scene changes, this node no longer exists, so we must handle it now
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled() # Prevent further processing
		# CRITICAL: await the async change_scene to ensure fade transition completes
		await SceneManager.change_scene(HOUSE_SCENE_PATH, HOUSE_SPAWN_POSITION)
