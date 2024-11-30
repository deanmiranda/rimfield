extends Node2D  # Assuming the root of house_scene is Node2D

# Pause Menu specific properties
var pause_menu: Control
var paused = false

func _ready():
	# Pause menu setup
	var pause_menu_scene = load("res://scenes/ui/pause_menu.tscn")
	if not pause_menu_scene:
		print("Error: Failed to load PauseMenu scene.")
		return

	if pause_menu_scene is PackedScene:
		pause_menu = pause_menu_scene.instantiate()
		add_child(pause_menu)  # Add the pause menu to this scene
		pause_menu.visible = false
	else:
		print("Error: Loaded resource is not a PackedScene.")

func _input(event: InputEvent) -> void:
	# Handle ESC key input specifically in house_scene
	if event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()

func toggle_pause_menu():
	# Toggle the pause menu visibility in the gameplay scene
	if pause_menu.visible:
		pause_menu.hide()
		get_tree().paused = false  # Unpause the entire game
		paused = false
	else:
		pause_menu.show()
		get_tree().paused = true  # Pause the entire game, but leave UI active
		paused = true
