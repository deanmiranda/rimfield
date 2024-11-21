extends Area2D

const HOUSE_SCENE_PATH = "res://scenes/world/house.tscn"

var player_in_zone: bool = false  # Tracks if the player is in the zone

func _on_body_exited(_body: Node2D) -> void:
	print("body exited")
	pass # Replace with function body.

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "PlayerSpawn":  # Check type and name
		print("Player entered interaction zone")
		player_in_zone = true
		
func _process(_delta: float) -> void:
	if player_in_zone and Input.is_action_just_pressed("ui_interact"):  # Pressing E in the zone
		print("Interacting with house!")
		SceneManager.change_scene(HOUSE_SCENE_PATH)  # Use the SceneManager to change scene
		
