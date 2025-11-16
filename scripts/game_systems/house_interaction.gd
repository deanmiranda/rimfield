extends Area2D

const HOUSE_SCENE_PATH = "res://scenes/world/house_scene.tscn"
const HOUSE_SPAWN_POSITION = Vector2(-8, 54)  # Inside house, far from exit

var player: Node = null  # Reference to the player
var player_in_zone: bool = false  # Tracks if the player is in the zone
var is_transitioning: bool = false  # Prevent multiple transitions

# Use @onready instead of get_node() in _ready() (follows .cursor/rules/godot.md)
@onready var interaction_label: Label = $Label


func _ready() -> void:
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
		is_transitioning = false  # Reset transition flag
		# Notify the player
		if player.has_method("stop_interaction"):
			player.stop_interaction()
		player = null  # Clear the player reference


func _input(event: InputEvent) -> void:
	# Use _input() instead of _process() polling (follows .cursor/rules/godot.md)
	if player_in_zone and event.is_action_pressed("ui_interact") and not is_transitioning:
		is_transitioning = true
		SceneManager.change_scene(HOUSE_SCENE_PATH, HOUSE_SPAWN_POSITION)
		# Only handle input if viewport is available (may be null during scene transitions)
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()  # Prevent further processing
