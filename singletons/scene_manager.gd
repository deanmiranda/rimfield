extends Node

var current_scene: String = ""
var player_spawn_position: Vector2 = Vector2.ZERO
var pause_menu: Control
var paused = false

func _ready() -> void:
	var pause_menu_scene = load("res://scenes/ui/pause_menu.tscn")
	if not pause_menu_scene:
		print("Error: Failed to load PauseMenu scene.")
		return

	if pause_menu_scene is PackedScene:
		pause_menu = pause_menu_scene.instantiate()
		get_tree().get_root().call_deferred("add_child", pause_menu)
		pause_menu.visible = false
	else:
		print("Error: Loaded resource is not a PackedScene.")

func change_scene(scene_path: String, spawn_position: Vector2 = Vector2.ZERO) -> void:
	current_scene = scene_path
	player_spawn_position = spawn_position

	get_tree().change_scene_to_file(scene_path)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()

func toggle_pause_menu():
	if pause_menu.visible:
		pause_menu.hide()
		get_tree().paused = false  # Unpause the entire game
		paused = false
	else:
		pause_menu.show()
		get_tree().paused = true  # Pause the entire game, but leave UI active
		paused = true

func handle_pause_request(paused_state: bool):
	get_tree().paused = paused_state
	paused = paused_state
