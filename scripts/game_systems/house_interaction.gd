extends Area2D

const HOUSE_SCENE_PATH = "res://scenes/world/house.tscn"

var interaction_label: Label  # Declare the variable
var player_in_zone: bool = false  # Tracks if the player is in the zone

func _ready() -> void:
	interaction_label = get_node("Label")  # Safely fetch the node in _ready()
	interaction_label.visible = false  # Start hidden

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "PlayerSpawn":  # Check type and name
		interaction_label.visible = true  # Show the Label when player enters
		player_in_zone = true

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "PlayerSpawn":  # Check type and name
		interaction_label.visible = false  # Hide the Label when player exits
		player_in_zone = false

func _process(_delta: float) -> void:
	if player_in_zone and Input.is_action_just_pressed("ui_interact"):  # Pressing E in the zone
		SceneManager.change_scene(HOUSE_SCENE_PATH)  # Use SceneManager to change scene
