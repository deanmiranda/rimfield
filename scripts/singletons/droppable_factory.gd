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
func spawn_droppable(item_id: String, position: Vector2) -> Node2D:
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

	# Add the droppable to the current scene tree
	if not droppable_instance.get_parent():
		get_tree().current_scene.add_child(droppable_instance)
		print("Droppable spawned:", item_id, "at position:", position)
	else:
		print("Error: Droppable instance already added to a parent!")
	
	# Log the droppable's current parent
	if droppable_instance.get_parent():
		print("Droppable's current parent:", droppable_instance.get_parent().name)
	
	return droppable_instance

# Adds an item to the inventory (example logic, update based on your system)
func add_to_inventory(item_data: DroppableItem) -> void:
	if not item_data or not item_data.texture:
		print("Error: Invalid item_data or missing texture.")
		return

	# Example: Add the item to a specific slot (e.g., the first available slot)
	var slot_index = InventoryManager.get_first_empty_slot()
	if slot_index == -1:
		print("Inventory is full!")
		return

	# Add the item to the inventory
	var success = InventoryManager.add_item(slot_index, item_data.texture)
	if success:
		print("Item added to inventory:", item_data.item_id)
	else:
		print("Failed to add item to inventory.")
