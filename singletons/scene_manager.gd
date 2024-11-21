extends Node

var current_scene: String = ""
var player_spawn_position: Vector2 = Vector2.ZERO  # Tracks where the player spawns

func change_scene(scene_path: String, spawn_position: Vector2 = Vector2.ZERO) -> void:
	current_scene = scene_path
	player_spawn_position = spawn_position
	get_tree().change_scene_to_file(scene_path)
