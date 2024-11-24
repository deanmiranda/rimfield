extends Node

var current_scene: String = "farm_scene"

func change_scene(new_scene: String):
	current_scene = new_scene
	get_tree().change_scene_to_file("res://scenes/world/%s.tscn" % new_scene)
