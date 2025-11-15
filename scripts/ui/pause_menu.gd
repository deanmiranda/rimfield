extends Control

#signal pause_request(paused: bool)

func _ready() -> void:
	self.visible = false
	
	# Make sure the feedback label is hidden initially
	var feedback_label = $CenterContainer/VBoxContainer/SaveFeedbackLabel
	if feedback_label:
		feedback_label.visible = false


func _focus_on_resume() -> void:
	# This is just to make sure the resume button gets focus
	var resume_button = $CenterContainer/VBoxContainer/ResumeButton
	if resume_button:
		resume_button.grab_focus()
	else:
		print("ResumeButton not found!")

func _input(event: InputEvent) -> void:
	# Don't process ESC on main menu - only during gameplay
	var current_scene = get_tree().current_scene
	if current_scene:
		# Check both scene name and scene file path to be safe
		var scene_name = current_scene.name
		var scene_file = current_scene.scene_file_path
		if scene_name == "Main_Menu" or (scene_file and scene_file.ends_with("main_menu.tscn")):
			return
	
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

	# Provide feedback for saving
	var feedback_label = $CenterContainer/VBoxContainer/SaveFeedbackLabel
	if feedback_label:
		feedback_label.visible = true
		feedback_label.text = "Game Saving..."

		# Force an immediate UI update
		await get_tree().process_frame  # Allow one frame to process to update the label

		# Validate save file and update feedback
		await get_tree().create_timer(0.5).timeout  # Small delay to ensure save file is registered
		if FileAccess.file_exists(save_file_path):
			# Check the number of save files
			var save_dir = DirAccess.open("user://")
			var save_count = 0
			if save_dir:
				save_dir.list_dir_begin()
				var file_name = save_dir.get_next()
				while file_name != "":
					if file_name.begins_with("save_slot_") and file_name.ends_with(".json"):
						save_count += 1
					file_name = save_dir.get_next()
				save_dir.list_dir_end()
			
			# Set feedback text based on the save count
			if save_count > 4:
				feedback_label.text = "Game Saved! If you save again, older saves will be overwritten."
				
				# Force an immediate UI update after changing the text
				await get_tree().process_frame  # Allow one frame to process to update the label
				
				# Longer delay for the special warning message
				await get_tree().create_timer(2.0).timeout  # 2-second delay for longer message
				feedback_label.visible = false
			else:
				feedback_label.text = "Game Saved!"
				# Force an immediate UI update after changing the text
				await get_tree().process_frame  # Allow one frame to process to update the label

				# Shorter delay for the regular message
				await get_tree().create_timer(1.5).timeout
				feedback_label.visible = false
		else:
			print("Save file validation failed. File not found.")
	else:
		print("SaveFeedbackLabel not found!")

func _on_back_to_main_menu_pressed() -> void:
	# Unpause the game before switching to the main menu
	get_tree().paused = false
	
	# Assuming there's a SceneManager singleton that handles scene transitions
	if SceneManager:
		SceneManager.change_scene("res://scenes/ui/main_menu.tscn")
	else:
		# If there's no SceneManager, just change scene directly
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
