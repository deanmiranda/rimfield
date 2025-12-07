extends Node2D # Assuming the root of house_scene is Node2D

var hud_instance: Node
var hud_scene_path = preload("res://scenes/ui/hud.tscn")

func _ready():
	# Restore chests for this scene
	if ChestManager:
		ChestManager.restore_chests_for_scene("House")
	
	# Restore droppables for this scene
	if DroppableFactory:
		DroppableFactory.restore_droppables_for_scene("House")
	
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
	
	# Inventory setup - CRITICAL: Initialize pause menu and inventory UI
	if UiManager:
		UiManager.instantiate_inventory()
	
	# Connect to DragManager world drop signal for chest placement
	if DragManager:
		if not DragManager.dropped_on_world.is_connected(_on_toolkit_world_drop):
			DragManager.dropped_on_world.connect(_on_toolkit_world_drop)
		
		# Connect to cursor-hold world drop signal
		if not DragManager.cursor_hold_dropped_on_world.is_connected(_on_cursor_hold_dropped_on_world):
			DragManager.cursor_hold_dropped_on_world.connect(_on_cursor_hold_dropped_on_world)


func _on_toolkit_world_drop(source_container: Node, source_slot: int, texture: Texture, count: int, mouse_pos: Vector2) -> void:
	"""Handle item dropped on world from drag (any item, or chest placement)"""
	if texture == null:
		return
	
	var tex_path = texture.resource_path
	
	# Special case: chest icon from toolkit → place chest
	if tex_path == "res://assets/icons/chest_icon.png":
		_handle_chest_placement(source_container, source_slot, texture, count, mouse_pos)
		return
	
	# General case: any other item → spawn as droppable
	_handle_item_world_drop(texture, count, mouse_pos, source_container, source_slot)


func _handle_chest_placement(source_container: Node, source_slot: int, texture: Texture, _count: int, mouse_pos: Vector2) -> void:
	"""Handle chest placement on world"""
	print("[HouseScene] Chest placement requested at (%s, %s)" % [mouse_pos.x, mouse_pos.y])
	
	# Convert screen mouse_pos to world position using MouseUtil
	var world_pos = mouse_pos
	if MouseUtil:
		world_pos = MouseUtil.get_world_mouse_pos_2d(self)
	else:
		# Fallback: use viewport
		var viewport = get_viewport()
		if viewport:
			var camera = viewport.get_camera_2d()
			if camera:
				var viewport_size = viewport.size
				var camera_pos = camera.global_position
				var mouse_screen = mouse_pos
				world_pos = camera_pos + (mouse_screen - viewport_size / 2.0) / camera.zoom
	
	# Get ChestManager
	var chest_manager = get_node_or_null("/root/ChestManager")
	if not chest_manager:
		print("[HouseScene] Blocked chest placement at (%s, %s) reason=no_chest_manager" % [world_pos.x, world_pos.y])
		return
	
	# Use shared placement helper
	var placement_success = chest_manager.try_place_chest("House", world_pos)
	if not placement_success:
		print("[HouseScene] Blocked chest placement at (%s, %s) reason=validation_failed" % [world_pos.x, world_pos.y])
		return
	
	# Remove 1 chest from toolkit slot
	if source_container and source_container.has_method("get_slot_data"):
		var slot_data = source_container.get_slot_data(source_slot)
		var current_count = slot_data.get("count", 0)
		if current_count > 1:
			# Decrement count by 1
			if source_container.has_method("set_slot_data"):
				source_container.set_slot_data(source_slot, texture, current_count - 1)
			else:
				# Fallback: remove and re-add with decremented count
				source_container.remove_item_from_slot(source_slot)
				source_container.add_item_to_slot(source_slot, texture, current_count - 1)
		else:
			# Only 1 item - remove completely
			source_container.remove_item_from_slot(source_slot)
	elif source_container and source_container.has_method("remove_item_from_slot"):
		# Fallback: just remove the slot
		source_container.remove_item_from_slot(source_slot)
	
	# CRITICAL: Clear drag state and preview after successful world placement
	if DragManager:
		DragManager.clear_drag_state()


func _handle_item_world_drop(texture: Texture, count: int, mouse_pos: Vector2, source_container: Node, source_slot: int) -> void:
	"""Handle any item dropped on world (spawn as droppable)"""
	# Convert screen mouse_pos to world position using MouseUtil
	var world_pos = mouse_pos
	if MouseUtil:
		world_pos = MouseUtil.get_world_mouse_pos_2d(self)
	else:
		# Fallback: use viewport
		var viewport = get_viewport()
		if viewport:
			var camera = viewport.get_camera_2d()
			if camera:
				var viewport_size = viewport.size
				var camera_pos = camera.global_position
				var mouse_screen = mouse_pos
				world_pos = camera_pos + (mouse_screen - viewport_size / 2.0) / camera.zoom
	
	# Snap to grid (16x16 tiles, center at +8)
	var snapped_pos = Vector2(floor(world_pos.x / 16.0) * 16.0 + 8, floor(world_pos.y / 16.0) * 16.0 + 8)
	
	# Spawn droppable item(s) using DroppableFactory
	if DroppableFactory and hud_instance:
		# Try to get item_id from texture
		var item_id = DroppableFactory.get_item_id_from_texture(texture)
		
		if item_id.is_empty():
			# No matching item_id - spawn generic droppable with texture via factory
			# This ensures proper registration for persistence
			if texture is Texture2D:
				DroppableFactory.spawn_generic_droppable_from_texture(texture, snapped_pos, hud_instance, count)
		else:
			# Use existing item_id - spawn via factory
			for i in range(count):
				var spawn_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4)) if count > 1 else Vector2.ZERO
				var droppable = DroppableFactory.spawn_droppable(item_id, snapped_pos + spawn_offset, hud_instance)
				if droppable:
					droppable.scale = Vector2(0.75, 0.75)
	
	# Remove items from source container BEFORE clearing drag state
	if source_container and is_instance_valid(source_container):
		if source_container.has_method("remove_item_from_slot"):
			source_container.remove_item_from_slot(source_slot)
			# Ensure UI is synced after removal
			if source_container.has_method("sync_slot_ui"):
				source_container.sync_slot_ui(source_slot)
	
	# Clear drag state AFTER removing items
	if DragManager:
		DragManager.clear_drag_state()


func _on_cursor_hold_dropped_on_world(texture: Texture, count: int, mouse_pos: Vector2) -> void:
	"""Handle cursor-hold items dropped on world"""
	if texture == null or count <= 0:
		return
	
	# Convert screen mouse_pos to world position using MouseUtil
	var world_pos = mouse_pos
	if MouseUtil:
		world_pos = MouseUtil.get_world_mouse_pos_2d(self)
	else:
		# Fallback: use viewport
		var viewport = get_viewport()
		if viewport:
			var camera = viewport.get_camera_2d()
			if camera:
				var viewport_size = viewport.size
				var camera_pos = camera.global_position
				var mouse_screen = mouse_pos
				world_pos = camera_pos + (mouse_screen - viewport_size / 2.0) / camera.zoom
	
	# Snap to grid (16x16 tiles, center at +8)
	var snapped_pos = Vector2(floor(world_pos.x / 16.0) * 16.0 + 8, floor(world_pos.y / 16.0) * 16.0 + 8)
	
	# Spawn droppable item(s) using DroppableFactory
	if DroppableFactory and hud_instance:
		# Try to get item_id from texture
		var item_id = DroppableFactory.get_item_id_from_texture(texture)
		
		if item_id.is_empty():
			# No matching item_id - spawn generic droppable with texture via factory
			# This ensures proper registration for persistence
			if texture is Texture2D:
				DroppableFactory.spawn_generic_droppable_from_texture(texture, snapped_pos, hud_instance, count)
		else:
			# Use existing item_id - spawn via factory
			for i in range(count):
				var spawn_offset = Vector2(randf_range(-4, 4), randf_range(-4, 4)) if count > 1 else Vector2.ZERO
				var droppable = DroppableFactory.spawn_droppable(item_id, snapped_pos + spawn_offset, hud_instance)
				if droppable:
					droppable.scale = Vector2(0.75, 0.75)
		
		# Consume from cursor-hold after successful spawn
		if DragManager:
			DragManager.consume_from_cursor_hold(count)
