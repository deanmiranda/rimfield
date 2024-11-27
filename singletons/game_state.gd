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


func save_game() -> void:
	var save_data = {
		"farm_state": farm_state
	}
	var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))  # Use JSON.print() to convert Dictionary to JSON
	file.close()
	print("Game saved!")
signal game_loaded

func load_game():
	if FileAccess.file_exists("user://save_data.json"):
		var file = FileAccess.open("user://save_data.json", FileAccess.READ)
		var json = JSON.new()
		var parse_status = json.parse(file.get_as_text())
		file.close()

		if parse_status == OK:
			var save_data = json.data
			farm_state.clear()
			for key in save_data.get("farm_state", {}).keys():
				var position = Vector2i(key.split(",")[0].to_int(), key.split(",")[1].to_int())
				farm_state[position] = save_data["farm_state"][key]
			print("Game loaded successfully!")

			emit_signal("game_loaded")
		else:
			print("Error parsing save file: Error Code", parse_status)
	else:
		print("No save file found. Starting fresh.")
