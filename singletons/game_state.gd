extends Node

var current_scene: String = "farm_scene"
var farm_state: Dictionary = {}  # Tracks tile states by position

func update_tile_state(position: Vector2i, state: String):
	# Save the tile state
	farm_state[position] = state

func get_tile_state(position: Vector2i) -> String:
	# Return the state for the given position or "empty" by default
	return farm_state.get(position, "empty")

func change_scene(new_scene: String):
	current_scene = new_scene
	get_tree().change_scene_to_file("res://scenes/world/%s.tscn" % new_scene)

#func save_game():
	#var save_data = {
		#"farm_state": farm_state
	#}
	#var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	#file.store_string(to_json(save_data))
	#file.close()
#
#func load_game():
	#if FileAccess.file_exists("user://save_data.json"):
		#var file = FileAccess.open("user://save_data.json", FileAccess.READ)
		#var save_data = parse_json(file.get_as_text())
		#farm_state = save_data.get("farm_state", {})
		#file.close()
