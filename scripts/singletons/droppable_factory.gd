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


func _on_droppable_removed(droppable: Node2D) -> void:
	"""Called when a droppable is removed from the scene (picked up or destroyed)."""
	if droppable in active_droppables:
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
			droppable_data.append({
				"item_id": data.get("item_id"),
				"position": {"x": data.get("position").x, "y": data.get("position").y},
				"scene_name": data.get("scene_name")
			})
	return droppable_data


func restore_droppables_from_save(droppable_data: Array) -> void:
	"""Restore droppables from save data."""
	pending_restore_droppables = droppable_data


func restore_droppables_for_scene(scene_name: String) -> void:
	"""Restore droppables for a specific scene."""
	var restored_count = 0
	for data in pending_restore_droppables:
		if data.get("scene_name") == scene_name:
			var item_id = data.get("item_id")
			var pos_data = data.get("position")
			var position = Vector2(pos_data.get("x"), pos_data.get("y"))
			
			# Get HUD reference
			var hud = get_tree().root.get_node_or_null("Hud")
			if not hud:
				hud = get_tree().current_scene.get_node_or_null("Hud")
			
			# Spawn the droppable
			spawn_droppable(item_id, position, hud)
			restored_count += 1
	


func reset_all_droppables() -> void:
	"""Clear all droppables (for new game)."""
	# Remove all active droppables from scene
	for droppable in active_droppables.keys():
		if is_instance_valid(droppable):
			droppable.queue_free()
	
	active_droppables.clear()
	pending_restore_droppables.clear()
