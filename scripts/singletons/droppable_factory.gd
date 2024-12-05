extends Node

@export var droppable_items_path: String = "res://resources/droppable_items/"

var droppable_cache: Dictionary = {}

func get_droppable(item_id: String) -> Resource:
	if droppable_cache.has(item_id):
		return droppable_cache[item_id]

	var resource_path = droppable_items_path + item_id + ".tres"
	if ResourceLoader.exists(resource_path):
		var droppable = load(resource_path)
		droppable_cache[item_id] = droppable
		return droppable
	else:
		print("Droppable item not found: ", item_id)
		return null
