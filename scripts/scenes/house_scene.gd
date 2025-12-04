extends Node2D # Assuming the root of house_scene is Node2D

var hud_instance: Node
var hud_scene_path = preload("res://scenes/ui/hud.tscn")

# Background music player
var house_music_player: AudioStreamPlayer = null

func _ready():
	# Restore chests for this scene
	if ChestManager:
		ChestManager.restore_chests_for_scene("House")
	
	# Restore droppables for this scene
	if DroppableFactory:
		DroppableFactory.restore_droppables_for_scene("House")
	
	# Setup background music - play Mowing-The-Lawn.mp3 (no loop)
	_setup_house_music()
	
	# Instantiate the player IMMEDIATELY for quick scene display
	var player_scene = preload("res://scenes/characters/player/player.tscn")
	var player_instance = player_scene.instantiate()
	add_child(player_instance)

	# Use spawn position from SceneManager if set (e.g., entering from outside), otherwise default to bed (waking up)
	if SceneManager and SceneManager.player_spawn_position != Vector2.ZERO:
		player_instance.global_position = SceneManager.player_spawn_position
		SceneManager.player_spawn_position = Vector2.ZERO # Reset after use
	else:
		# Default spawn: bed position (for waking up / new day)
		var bed_spawn = get_node_or_null("BedSpawnPoint")
		if bed_spawn:
			player_instance.global_position = bed_spawn.global_position
		else:
			print("Warning: BedSpawnPoint not found, using fallback position")
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
	if hud_scene_path:
		hud_instance = hud_scene_path.instantiate()
		add_child(hud_instance)
		# Link HUD singleton
		if HUD:
			HUD.set_hud_scene_instance(hud_instance)
		else:
			print("Warning: HUD singleton not found in house_scene.")
	else:
		print("Error: HUD scene not assigned in house_scene!")
	
	# Inventory setup - CRITICAL: Initialize pause menu and inventory UI
	if UiManager:
		UiManager.instantiate_inventory()
	else:
		print("Error: UiManager singleton not found.")

func _setup_house_music() -> void:
	"""Setup and play house background music (Mowing-The-Lawn.mp3, no loop)."""
	# Stop any existing music players (safety check)
	_stop_all_music()
	
	# Create AudioStreamPlayer node if it doesn't exist
	if house_music_player == null:
		house_music_player = AudioStreamPlayer.new()
		house_music_player.name = "HouseMusic"
		house_music_player.add_to_group("music") # Add to music group for easy management
		add_child(house_music_player)
	
	# Load the house music track
	var audio_stream = load("res://assets/audio/Mowing-The-Lawn.mp3")
	if audio_stream:
		# Ensure the stream doesn't loop
		if audio_stream is AudioStreamMP3:
			audio_stream.loop = false
		house_music_player.stream = audio_stream
		house_music_player.volume_db = 0.0
		# Use call_deferred to ensure node is in scene tree before playing
		call_deferred("_play_house_music")
	else:
		push_error("[HouseScene] Failed to load house music: Mowing-The-Lawn.mp3")

func _play_house_music() -> void:
	"""Play the house music (called deferred to ensure node is ready)."""
	if house_music_player and house_music_player.stream:
		house_music_player.stop() # Stop any existing playback
		house_music_player.play()
	else:
		push_error("[HouseScene] Cannot play house music - player or stream is null")

func _stop_all_music() -> void:
	"""Stop all music players in the scene tree (safety check)."""
	# Find and stop any existing AudioStreamPlayer nodes
	var audio_players = get_tree().get_nodes_in_group("music")
	for player in audio_players:
		if player is AudioStreamPlayer:
			player.stop()
	
	# Also check for common music player names
	var farm_music = get_node_or_null("FarmMusic")
	if farm_music and farm_music is AudioStreamPlayer:
		farm_music.stop()
	
	if house_music_player and house_music_player.playing:
		house_music_player.stop()
