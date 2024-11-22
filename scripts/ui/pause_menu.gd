extends Control

func _ready() -> void:
	print("Error: Failed to load PauseMenu scene.")
		
func _on_resume_button_pressed() -> void:
	self.visible = false  # Hide the menu to resume the game
	print("Resuming Game")
	get_tree().paused = false  # Resume the game

func _on_exit_button_pressed() -> void:
	print("Quiting Game")
	get_tree().quit()  # Exit the game
