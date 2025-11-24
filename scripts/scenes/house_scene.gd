extends Node2D # Assuming the root of house_scene is Node2D

var hud_instance: Node
var hud_scene_path = preload("res://scenes/ui/hud.tscn")


func _ready():
	# Instantiate the player IMMEDIATELY for quick scene display
	var player_scene = preload("res://scenes/characters/player/player.tscn")
	var player_instance = player_scene.instantiate()
	add_child(player_instance)

	# Use spawn position from SceneManager if set, otherwise default to entrance (far from exit)
	if SceneManager and SceneManager.player_spawn_position != Vector2.ZERO:
		player_instance.global_position = SceneManager.player_spawn_position
		SceneManager.player_spawn_position = Vector2.ZERO # Reset after use
	else:
		# Default spawn: inside house, far from the exit doorway (exit is at y=86)
		player_instance.global_position = Vector2(-8, 54)

	# Force camera to snap to player position immediately (no smooth transition)
	# CRITICAL: Access PlayerCamera using two-step path to match actual player scene structure
	# Structure: player_instance (root Node2D "Player") -> "Player" (CharacterBody2D) -> "PlayerCamera" (Camera2D)
	var player_node = player_instance.get_node_or_null("Player")
	if player_node:
		var camera = player_node.get_node_or_null("PlayerCamera")
		if camera and camera is Camera2D:
			camera.reset_smoothing()

	# HUD setup - MUST load immediately for inventory/toolkit to work
	print("HouseScene: Loading HUD...")
	if hud_scene_path:
		hud_instance = hud_scene_path.instantiate()
		add_child(hud_instance)
		# Link HUD singleton
		if HUD:
			HUD.set_hud_scene_instance(hud_instance)
			print("HouseScene: HUD loaded and linked")
		else:
			print("Warning: HUD singleton not found in house_scene.")
	else:
		print("Error: HUD scene not assigned in house_scene!")
	
	# Inventory setup - CRITICAL: Initialize pause menu and inventory UI
	if UiManager:
		UiManager.instantiate_inventory()
	else:
		print("Error: UiManager singleton not found.")
