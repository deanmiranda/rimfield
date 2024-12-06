extends Node

# Stores the resource paths for available droppable items
var droppable_item_resources: Dictionary = {
	"carrot": preload("res://resources/droppable_items/carrot.tres"),
	"strawberry": preload("res://resources/droppable_items/strawberry.tres"),
	"tomato": preload("res://resources/droppable_items/tomato.tres"),
}

# Preload the generic droppable scene
var droppable_scene: PackedScene = preload("res://scenes/droppable/droppable_generic.tscn")

# Spawns a droppable into the world
func spawn_droppable(item_id: String, position: Vector2, hud_instance: Node) -> Node2D:
	if not droppable_item_resources.has(item_id):
		print("Error: Item ID not found in droppable_item_resources:", item_id)
		return null

	# Instance the droppable scene
	var droppable_instance = droppable_scene.instantiate()
	if not droppable_instance:
		print("Error: Failed to instantiate droppable scene!")
		return null

	# Ensure the instance is not already parented (edge case safeguard)
	if droppable_instance.get_parent():
		print("Warning: Droppable instance already has a parent. Removing from parent.")
		droppable_instance.get_parent().remove_child(droppable_instance)

	# Set the item_data dynamically
	var item_data = droppable_item_resources[item_id]
	droppable_instance.item_data = item_data

	# Place the droppable at the desired position
	droppable_instance.global_position = position

	# Assign the HUD reference
	droppable_instance.hud = hud_instance

	# Add the droppable to the current scene tree
	get_tree().current_scene.add_child(droppable_instance)

	# Log the droppable's current parent
	if droppable_instance.get_parent():
		print("Droppable's current parent:", droppable_instance.get_parent().name)

	return droppable_instance
