extends Node

# Stores the resource paths for available droppable items
var droppable_item_resources: Dictionary = {}

# Reverse lookup: texture -> item_id (for throw-to-world feature)
var texture_to_item_id: Dictionary = {}

# Preload the generic droppable scene
var droppable_scene: PackedScene = preload("res://scenes/droppable/droppable_generic.tscn")

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
