extends Area2D

const HOUSE_SCENE_PATH = "res://scenes/world/house.tscn"

func _on_HouseInteractionZone_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.name == "Player":  # Check type and name
		GameState.change_scene("house")
