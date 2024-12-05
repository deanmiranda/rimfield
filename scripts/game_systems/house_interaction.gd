extends Area2D

const HOUSE_SCENE_PATH = "res://scenes/world/house_scene.tscn"
var interaction_label: Label
var player: Node = null  # Reference to the player
var player_in_zone: bool = false  # Tracks if the player is in the zone

func _ready() -> void:
	interaction_label = get_node("Label")
	interaction_label.visible = false

func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player using type or class name
	if body is CharacterBody2D and body.has_method("start_interaction"):
		interaction_label.visible = true
		player = body  # Store reference to the player
		player_in_zone = true  # Set player_in_zone to true
		# Notify the player
		player.start_interaction("house")

func _on_body_exited(body: Node2D) -> void:
	# Check if the body is the player
	if body == player:
		interaction_label.visible = false
		player_in_zone = false  # Set player_in_zone to false
		# Notify the player
		if player.has_method("stop_interaction"):
			player.stop_interaction()
		player = null  # Clear the player reference

func _process(_delta: float) -> void:
	# Ensure player is in zone and input is pressed
	if player_in_zone and Input.is_action_just_pressed("ui_interact"):
		SceneManager.change_scene(HOUSE_SCENE_PATH)
