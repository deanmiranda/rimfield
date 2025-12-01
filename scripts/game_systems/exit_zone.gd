extends Area2D

const FARM_SCENE_PATH = "res://scenes/world/farm_scene.tscn"
const EXIT_SPAWN_POSITION = Vector2(-1, -28) # Right outside house front door

var player: Node = null # Reference to the player
var is_transitioning: bool = false # Prevent multiple transitions
var spawn_protection_time: float = 0.5 # Time in seconds to ignore triggers after scene load
var spawn_protection_active: bool = true # Flag to prevent immediate transitions on spawn


func _ready() -> void:
	# Enable spawn protection to prevent immediate transitions when player spawns
	spawn_protection_active = true
	# Disable spawn protection after the protection period
	await get_tree().create_timer(spawn_protection_time).timeout
	spawn_protection_active = false


func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player (name is "Player" from player.tscn)
	if body is CharacterBody2D and body.name == "Player":
		player = body
		# Ignore triggers during spawn protection period (prevents immediate transition on spawn)
		if spawn_protection_active:
			return
		
		# Auto-transition when player enters doorway (no E press needed for exit)
		if not is_transitioning:
			is_transitioning = true
			# Small delay to ensure player fully entered the zone
			await get_tree().create_timer(0.1).timeout
			# CRITICAL: Don't check player reference here - after scene change it will be stale
			# The scene transition will create a new player instance in the new scene
			# CRITICAL: await the async change_scene to ensure fade transition completes
			await SceneManager.change_scene(FARM_SCENE_PATH, EXIT_SPAWN_POSITION)
			# CRITICAL: Reset is_transitioning after transition completes
			# This ensures the flag is reset even if player exits during transition
			is_transitioning = false


func _on_body_exited(body: Node2D) -> void:
	# Check if the body is the player
	if body == player:
		player = null
		# CRITICAL: Don't reset is_transitioning here if a transition is in progress
		# The flag will be reset after the transition completes in _on_body_entered
		# This prevents race conditions where player exits during async transition
