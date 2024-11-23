extends Control

#signal pause_request(paused: bool)

func _ready() -> void:
	self.visible = false

func _focus_on_resume() -> void:
	#this is just to make sure the resume button gets focus
	var resume_button = $MarginContainer/VBoxContainer/ResumeButton
	if resume_button:
		resume_button.grab_focus()
	else:
		print("ResumeButton not found!")

		
func _input(event: InputEvent) -> void:
	#this makes esc toggle the pause menu
	if event.is_action_pressed("ui_cancel"):
		#emit_signal("pause_request", !self.visible)
		if !self.visible:
			_focus_on_resume()

func _on_resume_button_pressed() -> void:
	self.visible = false
#	Might want to change this in the future if things get complicated, use pause_request signal
	Engine.time_scale = 1
	#emit_signal("pause_request", false)
	#closes the pause menu

func _on_exit_button_pressed() -> void:
	get_tree().quit()
