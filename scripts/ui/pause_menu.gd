extends Control

#signal pause_request(paused: bool)

func _ready() -> void:
	self.visible = false
	
	# Make sure the feedback label is hidden initially
	var feedback_label = $MarginContainer/VBoxContainer/SaveFeedbackLabel
	if feedback_label:
		feedback_label.visible = false
		print("Feedback label set to invisible during _ready().")
	else:
		print("SaveFeedbackLabel not found in _ready().")

func _focus_on_resume() -> void:
	# This is just to make sure the resume button gets focus
	var resume_button = $MarginContainer/VBoxContainer/ResumeButton
	if resume_button:
		resume_button.grab_focus()
	else:
		print("ResumeButton not found!")

func _input(event: InputEvent) -> void:
	# This makes ESC toggle the pause menu
	if event.is_action_pressed("ui_cancel"):
		if !self.visible:
			_focus_on_resume()

func _on_resume_button_pressed() -> void:
	self.visible = false
	get_tree().paused = false  # Properly unpause the game using get_tree().paused

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_save_game_pressed() -> void:
	# Save to a dynamic slot based on current time
	var timestamp = Time.get_unix_time_from_system()
	var save_file_path = "user://save_slot_%s.json" % timestamp

	GameState.save_game(save_file_path)  # Save the game
	print("Game saved to:", save_file_path)

	# Provide feedback for saving
	var feedback_label = $MarginContainer/VBoxContainer/SaveFeedbackLabel
	if feedback_label:
		feedback_label.visible = true
		feedback_label.text = "Game Saving..."
		print("Feedback label set to visible, text set to 'Game Saving...'")
		
		# Force an immediate UI update
		await get_tree().process_frame  # Allow one frame to process to update the label

		# Validate save file and update feedback
		await get_tree().create_timer(0.2).timeout  # Small delay to ensure save file is registered
		if FileAccess.file_exists(save_file_path):
			feedback_label.text = "Game Saved!"
			print("Feedback label text updated to 'Game Saved!'")

			# Force an immediate UI update after changing the text
			await get_tree().process_frame  # Allow one frame to process to update the label

			# Hide feedback after a short delay
			await get_tree().create_timer(1.5).timeout
			feedback_label.visible = false
			print("Feedback hidden after 1.5 seconds.")
		else:
			print("Save file validation failed. File not found.")
	else:
		print("SaveFeedbackLabel not found!")
