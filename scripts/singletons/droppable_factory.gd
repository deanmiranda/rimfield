extends Node

# Stores the resource paths for available droppable items
var droppable_item_resources: Dictionary = {}

# Reverse lookup: texture -> item_id (for throw-to-world feature)
var texture_to_item_id: Dictionary = {}

# Preload the generic droppable scene
var droppable_scene: PackedScene = preload("res://scenes/droppable/droppable_generic.tscn")

# Droppable persistence (for house/farm scenes only)
var active_droppables: Dictionary = {} # {droppable_node: {item_id, position, scene_name}}
var pending_restore_droppables: Array = [] # Data for droppables to be restored on scene load
var droppable_id_counter: int = 0 # Counter for unique droppable IDs

func _ready() -> void:
	# Load droppable item resources
	droppable_item_resources = {
		"carrot": load("res://resources/droppable_items/carrot.tres"),
		"strawberry": load("res://resources/droppable_items/strawberry.tres"),
		"tomato": load("res://resources/droppable_items/tomato.tres"),
		"chest": load("res://resources/droppable_items/chest.tres"),
	}
	
	# Build reverse lookup dictionary
	for item_id in droppable_item_resources.keys():
		var item_data = droppable_item_resources[item_id]
		if item_data and item_data.texture:
			texture_to_item_id[item_data.texture] = item_id

# Get item_id from texture (for throw-to-world)
func get_item_id_from_texture(texture: Texture) -> String:
	if texture and texture in texture_to_item_id:
		return texture_to_item_id[texture]
	
	return ""

# Spawns a droppable into the world
func spawn_droppable(item_id: String, spawn_position: Vector2, hud_instance: Node) -> Node2D:
	if not droppable_item_resources.has(item_id):
		return null

	# Instance the droppable scene
	var droppable_instance = droppable_scene.instantiate()
	if not droppable_instance:
		return null

	# Ensure the instance is not already parented (edge case safeguard)
	if droppable_instance.get_parent():
		droppable_instance.get_parent().remove_child(droppable_instance)

	# Set the item_data dynamically
	var item_data = droppable_item_resources[item_id]
	droppable_instance.item_data = item_data

	# Place the droppable at the desired position
	droppable_instance.global_position = spawn_position

	# Assign the HUD reference
	droppable_instance.hud = hud_instance

	# Add the droppable to the current scene tree
	get_tree().current_scene.add_child(droppable_instance)
	
	# Track for persistence (house/farm only)
	var scene_name = get_tree().current_scene.name
	if scene_name == "House" or scene_name == "Farm":
		# Assign unique ID to droppable
		droppable_id_counter += 1
		var droppable_id = "droppable_" + str(droppable_id_counter)
		droppable_instance.set_meta("droppable_id", droppable_id)
		
		active_droppables[droppable_instance] = {
			"item_id": item_id,
			"position": spawn_position,
			"scene_name": scene_name,
			"droppable_id": droppable_id
		}
		# Connect to tree_exiting to remove from tracking when picked up
		droppable_instance.tree_exiting.connect(_on_droppable_removed.bind(droppable_instance))

	return droppable_instance

# Spawn droppable from texture (for throw-to-world)
func spawn_droppable_from_texture(texture: Texture, spawn_position: Vector2, hud_instance: Node, velocity: Vector2 = Vector2.ZERO) -> Node2D:
	var item_id = get_item_id_from_texture(texture)
	if item_id.is_empty():
		return null
	
	var droppable = spawn_droppable(item_id, spawn_position, hud_instance)
	if droppable and velocity != Vector2.ZERO:
		# Add physics/velocity for bounce effect
		# Since droppable is Node2D with Area2D, we'll use a simple tween for bounce effect
		var tween = droppable.create_tween()
		var bounce_distance = velocity.length() * 0.1 # Convert velocity to distance
		var bounce_duration = 0.3
		tween.set_parallel(true)
		tween.tween_property(droppable, "global_position", droppable.global_position + velocity * bounce_distance, bounce_duration)
		tween.tween_property(droppable, "scale", Vector2(1.2, 1.2), bounce_duration * 0.5)
		tween.tween_property(droppable, "scale", Vector2(0.5, 0.5), bounce_duration).set_delay(bounce_duration * 0.5)
	
	return droppable


# Spawn generic droppable from texture (for unregistered items like seeds/tools)
# Returns array of spawned droppable instances
func spawn_generic_droppable_from_texture(texture: Texture2D, position: Vector2, hud_instance: Node, count: int = 1) -> Array:
	if not texture or not texture.resource_path:
		return []
	
	var spawned_instances: Array = []
	
	for i in range(count):
		# Instance the droppable scene
		var droppable_instance = droppable_scene.instantiate()
		if not droppable_instance:
			continue
		
		# Ensure the instance is not already parented (edge case safeguard)
		if droppable_instance.get_parent():
			droppable_instance.get_parent().remove_child(droppable_instance)
		
		# Create minimal item data resource using carrot.tres as template
		var item_data = preload("res://resources/droppable_items/carrot.tres").duplicate()
		item_data.texture = texture
		
		# Set the item_data
		droppable_instance.item_data = item_data
		
		# Calculate position with offset for multiple items
		var spawn_pos = position
		if count > 1:
			spawn_pos = position + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		
		# Place the droppable at the desired position
		droppable_instance.global_position = spawn_pos
		
		# Assign the HUD reference
		droppable_instance.hud = hud_instance
		
		# Set scale to match existing behavior
		droppable_instance.scale = Vector2(0.75, 0.75)
		
		# Add the droppable to the current scene tree
		get_tree().current_scene.add_child(droppable_instance)
		
		# Track for persistence (house/farm only)
		var scene_name = get_tree().current_scene.name
		if scene_name == "House" or scene_name == "Farm":
			# Assign unique ID to droppable
			droppable_id_counter += 1
			var droppable_id = "droppable_" + str(droppable_id_counter)
			droppable_instance.set_meta("droppable_id", droppable_id)
			
			# Generate stable pseudo item_id based on texture path hash
			var pseudo_item_id = "generic_" + str(texture.resource_path.hash())
			
			# Store tracking data with texture_path for restoration
			active_droppables[droppable_instance] = {
				"item_id": pseudo_item_id,
				"texture_path": texture.resource_path,
				"position": spawn_pos,
				"scene_name": scene_name,
				"droppable_id": droppable_id
			}
			# Connect to tree_exiting to remove from tracking when picked up
			droppable_instance.tree_exiting.connect(_on_droppable_removed.bind(droppable_instance))
		
		spawned_instances.append(droppable_instance)
	
	return spawned_instances


func _on_droppable_removed(droppable: Node2D) -> void:
	"""Called when a droppable is removed from the scene (picked up or destroyed)."""
	if droppable in active_droppables:
		var data = active_droppables[droppable]
		var scene_name = data.get("scene_name", "")
		
		# Before removing, serialize to pending_restore_droppables if it's a scene transition
		# (not a pickup - pickups should be removed permanently)
		# We detect scene transition by checking if the droppable is being freed due to scene change
		# vs being picked up (which would call unregister_droppable first)
		# For now, we'll preserve all droppables on scene transition by serializing them
		var save_entry = {
			"item_id": data.get("item_id"),
			"position": {"x": data.get("position").x, "y": data.get("position").y},
			"scene_name": scene_name
		}
		if data.has("texture_path"):
			save_entry["texture_path"] = data.get("texture_path")
		
		# Add to pending_restore_droppables if not already there (avoid duplicates)
		# Use position + item_id/texture_path for deduplication (not droppable_id, since restored items get new IDs)
		var already_exists = false
		var check_pos = save_entry["position"]
		var check_item = save_entry.get("texture_path", save_entry.get("item_id", ""))
		
		for existing in pending_restore_droppables:
			var existing_pos = existing.get("position", {})
			var existing_item = existing.get("texture_path", existing.get("item_id", ""))
			# Check if same position and same item (within 1 pixel tolerance for position)
			if abs(existing_pos.get("x", 0) - check_pos.get("x", 0)) < 1.0 and \
			   abs(existing_pos.get("y", 0) - check_pos.get("y", 0)) < 1.0 and \
			   existing_item == check_item:
				already_exists = true
				break
		
		if not already_exists:
			pending_restore_droppables.append(save_entry)
		
		active_droppables.erase(droppable)


func unregister_droppable(droppable_id: String) -> void:
	"""Manually unregister a droppable by its ID (called before pickup/removal)."""
	for droppable in active_droppables.keys():
		if is_instance_valid(droppable) and droppable.has_meta("droppable_id"):
			if droppable.get_meta("droppable_id") == droppable_id:
				active_droppables.erase(droppable)
				return


func serialize_droppables() -> Array:
	"""Save all active droppables to an array for persistence."""
	var droppable_data = []
	for droppable in active_droppables.keys():
		if is_instance_valid(droppable):
			var data = active_droppables[droppable]
			var save_entry = {
				"item_id": data.get("item_id"),
				"position": {"x": data.get("position").x, "y": data.get("position").y},
				"scene_name": data.get("scene_name")
			}
			# Include texture_path for generic items (unregistered items like seeds/tools)
			if data.has("texture_path"):
				save_entry["texture_path"] = data.get("texture_path")
			droppable_data.append(save_entry)
	return droppable_data


func restore_droppables_from_save(droppable_data: Array) -> void:
	"""Restore droppables from save data."""
	pending_restore_droppables = droppable_data


func restore_droppables_for_scene(scene_name: String) -> void:
	"""Restore droppables for a specific scene."""
	var to_restore: Array = []
	var to_keep: Array = []
	
	# Collect all droppables for this scene and separate them from others
	for data in pending_restore_droppables:
		if data.get("scene_name") == scene_name:
			to_restore.append(data)
		else:
			to_keep.append(data)
	
	# Replace pending_restore_droppables with only entries for other scenes
	# (this prevents duplicates when restoring the same scene multiple times)
	pending_restore_droppables = to_keep
	
	# Get HUD reference
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		hud = get_tree().current_scene.get_node_or_null("Hud")
	
	# Restore each droppable
	for data in to_restore:
		var pos_data = data.get("position")
		var position = Vector2(pos_data.get("x"), pos_data.get("y"))
		
		# Check if this is a generic item (has texture_path)
		if data.has("texture_path"):
			# Restore generic droppable with texture
			var texture = load(data.get("texture_path"))
			if texture:
				spawn_generic_droppable_from_texture(texture, position, hud, 1)
		else:
			# Restore registered item using item_id
			var item_id = data.get("item_id")
			spawn_droppable(item_id, position, hud)
	

func reset_all_droppables() -> void:
	"""Clear all droppables (for new game)."""
	# Remove all active droppables from scene
	for droppable in active_droppables.keys():
		if is_instance_valid(droppable):
			droppable.queue_free()
	
	active_droppables.clear()
	pending_restore_droppables.clear()
