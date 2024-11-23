extends Control
		
func _on_resume_button_pressed() -> void:
	self.visible = false  # Hide the menu to resume the game
	Engine.time_scale = 1
	print("Resuming Game")

func _on_exit_button_pressed() -> void:
	print("Quiting Game")
	get_tree().quit()  # Exit the game
