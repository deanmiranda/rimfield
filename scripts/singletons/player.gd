extends Node2D

var health: int = 100
var inventory: Array = []  # Tracks items in inventory
var spawn_position: Vector2 = Vector2.ZERO

func save_spawn_position(new_position: Vector2):
	spawn_position = new_position

func add_to_inventory(item: String):
	if not inventory.has(item):
		inventory.append(item)

func remove_from_inventory(item: String):
	inventory.erase(item)
