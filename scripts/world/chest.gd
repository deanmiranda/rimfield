extends Node2D

# Chest - Storage container that can be opened/closed and stores items

signal chest_opened(chest: Node)
signal chest_closed(chest: Node)

@export var open_sound: AudioStream
@export var close_sound: AudioStream

var chest_id: String = ""
var is_open: bool = false
var player_in_area: bool = false
var nearby_player: CharacterBody2D = null

# Chest frame atlas coordinates (source_id = 0, alt = 0)
const CHEST_CLOSED_ATLAS = Vector2i(8, 49)
const CHEST_HALF_OPEN_ATLAS = Vector2i(9, 49)
const CHEST_OPEN_ATLAS = Vector2i(10, 49)
const TILE_SIZE = 16

@onready var sprite: Sprite2D = $ChestSprite
@onready var interaction_area: Area2D = $InteractionArea
@onready var audio_player: AudioStreamPlayer2D = $AudioPlayer


func _ready() -> void:
	# Add to chest group for easy finding
	add_to_group("chest")
	
	# Register with ChestManager
	if ChestManager:
		var registered_id = ChestManager.register_chest(self)
		if registered_id != "":
			chest_id = registered_id
		else:
			# Registration was blocked (wrong scene) - remove this chest node
			# It shouldn't exist in this scene
			if get_parent():
				get_parent().remove_child(self)
			queue_free()
			return # Exit early - don't set up signals or sprites for a node that's being freed
	
	# Connect Area2D signals
	if interaction_area:
		if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
			interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		if not interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
			interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	
	# Connect chest_opened signal to UiManager
	if chest_opened.is_connected(_on_chest_opened):
		chest_opened.disconnect(_on_chest_opened)
	chest_opened.connect(_on_chest_opened)
	
	# Set initial sprite frame (closed) - ensure sprite is ready
	if sprite:
		# Wait a frame to ensure sprite is fully initialized
		await get_tree().process_frame
		_set_sprite_frame(CHEST_CLOSED_ATLAS)
	
	# Set up collision layer/mask
	_setup_collision()
	
	# AnimationPlayer removed from scene - we use manual animations (_play_open_animation, _play_close_animation)


func _on_chest_opened(chest: Node) -> void:
	"""Handle chest opened signal - open the chest UI."""
	if UiManager:
		UiManager.open_chest_ui(chest)


func _setup_collision() -> void:
	# Set collision layer to "Obstacles" (layer 2) so player can't walk through
	var static_body = get_node_or_null("StaticBody2D")
	if static_body:
		static_body.set_collision_layer_value(2, true) # Obstacles layer
		static_body.set_collision_mask_value(1, false) # Don't collide with default layer
		static_body.set_collision_mask_value(2, false) # Don't collide with obstacles


func _set_sprite_frame(atlas_coords: Vector2i) -> void:
	"""Set sprite region to the specified atlas coordinates."""
	if not sprite:
		return
	
	var tileset_texture = load("res://assets/tilesets/full version/tiles/tiles.png")
	if tileset_texture:
		sprite.texture = tileset_texture
		sprite.region_enabled = true
		sprite.region_rect = Rect2(atlas_coords.x * TILE_SIZE, atlas_coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)


func _on_interaction_area_body_entered(body: Node2D) -> void:
	"""Called when a body enters the interaction area."""
	if _is_player(body):
		player_in_area = true
		nearby_player = body as CharacterBody2D
		if body.has_method("start_interaction"):
			body.start_interaction("chest")


func _on_interaction_area_body_exited(body: Node2D) -> void:
	"""Called when a body exits the interaction area."""
	if _is_player(body):
		player_in_area = false
		nearby_player = null
		if body.has_method("stop_interaction"):
			body.stop_interaction()


func _is_player(body: Node2D) -> bool:
	"""Check if body is the player."""
	if body.is_in_group("player"):
		return true
	if body is CharacterBody2D and body.has_method("start_interaction"):
		return true
	return false


func _input(event: InputEvent) -> void:
	"""Handle input for opening/closing chest."""
	if not player_in_area or not nearby_player:
		return
	
	# CRITICAL: Don't process input if game is paused (chest UI or other menu is open)
	if get_tree().paused:
		return
	
	# CRITICAL: Don't process input if chest UI is already open
	if is_open:
		return
	
	# Right-click to open chest (ONLY when chest UI is closed)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Check if event already handled (prevent duplicate processing)
			if event.is_echo():
				return
			
			# Don't process if DragManager is active (right-click is being used for drag)
			if DragManager and DragManager.is_dragging:
				return
			
			# Get mouse position in world space
			var mouse_world_pos = get_global_mouse_position()
			var distance_to_chest = mouse_world_pos.distance_to(global_position)
			
			# Check if clicking near chest (within 32 pixels)
			if distance_to_chest < 32:
				open_chest()
				get_viewport().set_input_as_handled()


func _check_player_facing(player: CharacterBody2D) -> bool:
	"""Check if player is facing the chest. Returns true if player is facing chest."""
	if not player or not is_instance_valid(player):
		return false
	
	# Get player position and chest position
	var player_pos = player.global_position
	var chest_pos = global_position
	
	# Calculate direction from player to chest
	var to_chest = (chest_pos - player_pos).normalized()
	
	# Get player's facing direction from sprite or movement
	var player_facing = Vector2.ZERO
	if "direction" in player:
		player_facing = player.direction.normalized()
	elif "sprite" in player:
		var player_sprite = player.get("sprite")
		if player_sprite and player_sprite is AnimatedSprite2D:
			# Try to determine facing from animation name or flip
			# For now, use movement direction if available
			if "direction" in player:
				player_facing = player.direction.normalized()
	
	# If we can't determine facing direction, use direction to chest as approximation
	if player_facing.length() < 0.1:
		player_facing = to_chest
	
	# Check if player is facing towards chest (dot product > 0.5 means roughly facing)
	var dot_product = player_facing.dot(to_chest)
	return dot_product > 0.5


func open_chest() -> void:
	"""Open the chest - play animation and sound, emit signal."""
	if is_open:
		return
	
	is_open = true
	
	# Play open animation manually (frame sequence: 8 → 9 → 10)
	_play_open_animation()
	
	# Play open sound
	if audio_player and open_sound:
		audio_player.stream = open_sound
		audio_player.play()
	
	# Emit signal
	chest_opened.emit(self)


func close_chest() -> void:
	"""Close the chest - play animation and sound, emit signal."""
	if not is_open:
		return
	
	is_open = false
	
	# Play close animation manually (frame sequence: 10 → 9 → 8)
	_play_close_animation()
	
	# Play close sound
	if audio_player and close_sound:
		audio_player.stream = close_sound
		audio_player.play()
	
	# Emit signal
	chest_closed.emit(self)


func get_chest_id() -> String:
	"""Get the chest's unique ID."""
	return chest_id


func set_chest_id(id: String) -> void:
	"""Set the chest's unique ID."""
	chest_id = id


func on_inventory_restored() -> void:
	"""Called by ChestManager when inventory is restored from save."""
	# This can be used to update UI if chest UI is open
	pass


func update_chest_position(new_pos: Vector2) -> void:
	"""Update chest position and notify ChestManager."""
	global_position = new_pos
	if ChestManager and chest_id != "":
		var inventory = ChestManager.get_chest_inventory(chest_id)
		ChestManager.update_chest_inventory(chest_id, inventory)


func _play_open_animation() -> void:
	"""Play open animation manually."""
	# Frame 1: Half-open
	_set_sprite_frame(CHEST_HALF_OPEN_ATLAS)
	await get_tree().create_timer(0.15).timeout
	# Frame 2: Open
	_set_sprite_frame(CHEST_OPEN_ATLAS)


func _play_close_animation() -> void:
	"""Play close animation manually."""
	# Frame 1: Half-open
	_set_sprite_frame(CHEST_HALF_OPEN_ATLAS)
	await get_tree().create_timer(0.15).timeout
	# Frame 2: Closed
	_set_sprite_frame(CHEST_CLOSED_ATLAS)
