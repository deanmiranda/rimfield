extends Area2D

const FARM_SCENE_PATH = "res://scenes/world/farm.tscn"

var player_in_zone: bool = false  # Tracks if the player is in the zone

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "PlayerSpawn":  # Check type and name
		print("Ready to hit 'e' to interact")
		player_in_zone = true

func _process(_delta: float) -> void:
	if player_in_zone and Input.is_action_just_pressed("ui_interact"):  # Pressing E in the zone
		print("Exiting to farm...")
		SceneManager.change_scene(FARM_SCENE_PATH)  # Use the SceneManager to change scene
		
