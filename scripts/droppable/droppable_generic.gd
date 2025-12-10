# droppable_generic.gd
extends Node2D

@export var item_data: Resource # Reference to the DroppableItem resource

# Signal removed - pickup is handled directly via pickup_item() method
# signal picked_up(item_data: Resource)  # Signal to emit when picked up

var player: Node = null # Reference to the player
var hud: Node = null # Reference to the HUD

# Slide animation state
var is_sliding: bool = false
var slide_speed: float = 200.0 # Pixels per second
var slide_duration: float = 0.5
var slide_elapsed: float = 0.0

# Pickup cancellation - track distance from ITEM, not from where player started
const MAX_PICKUP_DISTANCE: float = 48.0 # 3 tiles - if player is farther from item, cancel pickup

# Pickup state - prevent duplicate pickups while animating
var is_being_picked_up: bool = false

# Tween references for proper cleanup
var shake_tween: Tween = null
var visual_tween: Tween = null

# Reparenting helpers (to avoid physics query errors)
var original_parent: Node = null
var original_z_index: int = 10


func _ready() -> void:
	# Ensure item_data is set
	if not item_data:
		queue_free()
		return

	# Set the texture of the Sprite2D
	var sprite = $Sprite2D
	if sprite and item_data.texture:
		sprite.texture = item_data.texture
	
	# Disable process by default (only enabled during slide)
	set_process(false)


func _process(delta: float) -> void:
	"""Track player position in real-time during pickup animation (shake + slide)."""
	# Only run if we're in pickup mode (either shake or slide phase)
	if not is_being_picked_up or not player:
		return
	
	# Get current player position
	var player_pos: Vector2
	if player is Node2D:
		# Try to find CharacterBody2D child for accurate position
		var character_body = null
		for child in player.get_children():
			if child is CharacterBody2D:
				character_body = child
				break
		
		if character_body:
			player_pos = character_body.global_position
		else:
			player_pos = player.global_position
	else:
		return
	
	# Check if player is too far from the ITEM (48px = 3 tiles)
	var distance_from_item = global_position.distance_to(player_pos)
	if distance_from_item > MAX_PICKUP_DISTANCE:
		# Player ran away - cancel the pickup animation
		_cancel_pickup()
		return
	
	# If we're in slide phase, move the item towards player
	if is_sliding:
		# Move towards player
		var direction = (player_pos - global_position).normalized()
		var distance = distance_from_item
		
		# Use easing: start slow, speed up as we approach
		slide_elapsed += delta
		var progress = min(slide_elapsed / slide_duration, 1.0)
		var ease_factor = ease(progress, -2.0) # Ease in (accelerate)
		
		# Move towards player
		var move_speed = slide_speed * (1.0 + ease_factor * 2.0) # Speed increases over time
		var move_distance = move_speed * delta
		
		if distance > 2.0: # Don't overshoot
			global_position += direction * min(move_distance, distance)
		
		# Check if animation duration completed - add to inventory and remove
		if slide_elapsed >= slide_duration:
			is_sliding = false
			set_process(false)
			_remove_droppable() # Add to inventory and remove from scene
	# else: shake phase - just monitor distance, no movement needed


func _on_body_entered(body: Node2D) -> void:
	# Mark as nearby candidate only - no auto-pickup
	# The player's interaction manager will handle pickup on E press
	if body is CharacterBody2D and body.name == "Player":
		# Signal that this item is nearby (player will track it)
		pass


func _on_body_exited(body: Node2D) -> void:
	# Don't cancel on body exit - the 8px interaction area is too small
	# Distance-based cancellation (48px) happens in _process() instead
	pass


func pickup_item() -> void:
	# Called automatically when player walks near item
	# Prevent duplicate pickup attempts while already animating
	if is_being_picked_up:
		return
	
	if not hud or not item_data or not item_data.texture:
		return
	
	# CHECK if we have space (without adding yet)
	# First check if toolkit has space or existing stack
	var can_add_to_toolkit = false
	for i in range(InventoryManager.max_toolkit_slots):
		var slot_data = InventoryManager.toolkit_slots.get(i, {"texture": null, "count": 0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			can_add_to_toolkit = true # Empty slot
			break
		elif slot_data["texture"] == item_data.texture:
			can_add_to_toolkit = true # Can stack
			break
	
	# If toolkit full, check main inventory
	var can_add_to_inventory = false
	if not can_add_to_toolkit:
		for i in range(InventoryManager.max_inventory_slots):
			var slot_data = InventoryManager.inventory_slots.get(i, {"texture": null, "count": 0})
			if slot_data["texture"] == null or slot_data["count"] == 0:
				can_add_to_inventory = true # Empty slot
				break
			elif slot_data["texture"] == item_data.texture and slot_data["count"] < InventoryManager.MAX_INVENTORY_STACK:
				can_add_to_inventory = true # Can stack
				break
	
	# If no space anywhere, shake and return
	if not can_add_to_toolkit and not can_add_to_inventory:
		_shake_item()
		return
	
	# Space available - mark as being picked up and start animation
	is_being_picked_up = true
	set_process(true) # Enable distance checking throughout entire animation
	_slide_to_player_and_remove()


func _shake_item() -> void:
	"""Shake animation when inventory is full."""
	var tween = create_tween()
	var original_pos = global_position
	tween.set_loops(3)
	tween.tween_property(self, "global_position", original_pos + Vector2(2, 0), 0.05)
	tween.tween_property(self, "global_position", original_pos + Vector2(-2, 0), 0.05)
	tween.tween_callback(func(): global_position = original_pos)


func _get_player_node() -> Node:
	"""Robust player lookup with multiple fallback strategies."""
	# Strategy A: Group lookup (fastest, most reliable)
	var p = get_tree().get_first_node_in_group("player")
	if p and is_instance_valid(p):
		return p
	
	# Strategy B: WorldActors lookup (for Farm scene)
	var scene = get_tree().current_scene
	if scene:
		var world_actors = scene.get_node_or_null("WorldActors")
		if world_actors:
			for child in world_actors.get_children():
				if child.name == "Player":
					return child
	
	# Strategy C: Direct scene lookup (fallback)
	if scene:
		var player_root = scene.get_node_or_null("Player")
		if player_root:
			# Try to find CharacterBody2D child
			for child in player_root.get_children():
				if child is CharacterBody2D:
					return child
			# Return root if no CharacterBody2D found
			return player_root
	
	return null


func _slide_to_player_and_remove() -> void:
	"""Subtle shake, then slide item towards player with fade/shrink effect, then remove."""
	# Find the player using robust lookup
	player = _get_player_node()
	
	if not player:
		# No player found - just remove immediately
		_remove_droppable()
		return
	
	# Store original position for shake
	var original_pos = global_position
	
	# Create a single tween with sequential phases
	shake_tween = create_tween()
	
	# PHASE 1: Subtle shake for 0.3 seconds (anticipation - gives player time to run away)
	# Reduced from 5 shakes to 3 shakes = 0.3 seconds total
	for i in range(3): # 3 shakes = 0.3 seconds total
		shake_tween.tween_property(self, "global_position", original_pos + Vector2(1, 0), 0.05)
		shake_tween.tween_property(self, "global_position", original_pos + Vector2(-1, 0), 0.05)
	
	# Return to original position before sliding
	shake_tween.tween_property(self, "global_position", original_pos, 0.05)
	
	# PHASE 2: Start tracking slide with real-time player position
	shake_tween.tween_callback(func():
		# Enable sliding mode - _process already running, just switch to slide mode
		is_sliding = true
		slide_elapsed = 0.0
		
		# Start shrink and fade tween (visual only - removal handled by _process)
		visual_tween = create_tween()
		visual_tween.set_parallel(true)
		visual_tween.set_ease(Tween.EASE_IN)
		visual_tween.set_trans(Tween.TRANS_QUAD)
		
		# Shrink and fade out
		visual_tween.tween_property(self, "scale", Vector2(0.2, 0.2), slide_duration)
		visual_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), slide_duration)
		
		# Callback when visual tween finishes
		visual_tween.finished.connect(func():
			pass
		)
		
		# Note: _remove_droppable() is called from _process when slide_elapsed >= slide_duration
	)


func _cancel_pickup() -> void:
	"""Cancel the pickup animation if player runs away."""
	# Stop sliding
	is_sliding = false
	set_process(false)
	
	# Kill only OUR tweens (not all tweens in the scene)
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		shake_tween = null
	
	if visual_tween and visual_tween.is_valid():
		visual_tween.kill()
		visual_tween = null
	
	# Reset visual properties
	scale = Vector2(0.5, 0.5) # Original scale from the scene
	modulate = Color(1, 1, 1, 1) # Full opacity
	
	# Reset state - allow pickup to be attempted again
	player = null
	slide_elapsed = 0.0
	is_being_picked_up = false


func _deferred_reparent_and_remove() -> void:
	"""Reparent to scene root then remove. Called deferred at the very end to avoid physics errors."""
	if not is_instance_valid(self):
		return
	
	# Store original parent if not already stored
	if not original_parent:
		original_parent = get_parent()
		original_z_index = z_index
	
	# Reparent if needed (only if not already at scene root)
	if original_parent and original_parent != get_tree().current_scene:
		var stored_global_pos = global_position
		
		# Remove from current parent
		original_parent.remove_child(self)
		# Add to scene root
		get_tree().current_scene.add_child(self)
		
		# Restore global position
		global_position = stored_global_pos
		# Restore z_index
		z_index = original_z_index
	
	queue_free()


func _remove_droppable() -> void:
	"""Add item to inventory and remove the droppable from the scene."""
	# Add to inventory NOW (animation completed successfully)
	if item_data and item_data.texture:
		# Try adding to toolkit (toolbelt) with auto-stacking first
		var remaining = InventoryManager.add_item_to_toolkit_auto_stack(item_data.texture, 1)

		if remaining > 0:
			# Try adding to inventory as overflow
			remaining = InventoryManager.add_item_auto_stack(item_data.texture, remaining)

		# Log chest pickups for debugging
		if item_data.item_id == "chest":
			var chest_slot = -1
			var chest_count = 0
			# Find which slot has the chest
			for i in range(InventoryManager.max_toolkit_slots):
				var slot_texture = InventoryManager.get_toolkit_item(i)
				if slot_texture == item_data.texture:
					chest_slot = i
					chest_count = InventoryManager.get_toolkit_item_count(i)
					break
	
	# CRITICAL: Call unregister BEFORE queue_free to ensure proper cleanup
	if DroppableFactory and has_meta("droppable_id"):
		var droppable_id = get_meta("droppable_id")
		if DroppableFactory.has_method("unregister_droppable"):
			DroppableFactory.unregister_droppable(droppable_id)
	
	# Reparent to scene root right before removal to avoid physics query errors
	# This is done deferred and only at the very end, keeping all animations intact
	call_deferred("_deferred_reparent_and_remove")
