extends Node2D

var health: int = 100
var inventory: Array = []
var spawn_position: Vector2 = Vector2.ZERO

func save_spawn_position(new_position: Vector2):
	spawn_position = new_position
