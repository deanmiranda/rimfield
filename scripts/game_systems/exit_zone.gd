extends Area2D

const FARM_SCENE_PATH = "res://scenes/world/farm_scene.tscn"
const EXIT_SPAWN_POSITION = Vector2(-1, -28)  # Right outside house front door

var player: Node = null  # Reference to the player
var is_transitioning: bool = false  # Prevent multiple transitions


func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player (name is "Player" from player.tscn)
	if body is CharacterBody2D and body.name == "Player":
		player = body
		# Auto-transition when player enters doorway (no E press needed for exit)
		if not is_transitioning:
			is_transitioning = true
			# Small delay to ensure player fully entered the zone
			await get_tree().create_timer(0.1).timeout
			if player:  # Check player still exists
				SceneManager.change_scene(FARM_SCENE_PATH, EXIT_SPAWN_POSITION)


func _on_body_exited(body: Node2D) -> void:
	# Check if the body is the player
	if body == player:
		player = null
		is_transitioning = false
