extends Control

signal pause_request(paused: bool)

func _ready() -> void:
	self.visible = false
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		emit_signal("pause_request", !self.visible)

func _on_resume_button_pressed() -> void:
	self.visible = false
	emit_signal("pause_request", false)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
