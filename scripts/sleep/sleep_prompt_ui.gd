extends Control

## SleepPromptUI - Sleep confirmation dialog
##
## Displays a confirmation prompt when player wants to sleep.
## Handles E (cancel) and ESC (cancel) input, plus clickable buttons.

# Signals
signal sleep_confirmed
signal sleep_cancelled

# Button references
@onready var yes_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/YesButton
@onready var no_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/NoButton


func _ready() -> void:
	"""Initialize sleep prompt UI"""
	visible = false
	set_process_unhandled_input(true)
	
	# Connect button signals
	if yes_button:
		if not yes_button.pressed.is_connected(_on_yes_pressed):
			yes_button.pressed.connect(_on_yes_pressed)
	if no_button:
		if not no_button.pressed.is_connected(_on_no_pressed):
			no_button.pressed.connect(_on_no_pressed)


func show_prompt() -> void:
	"""Show the sleep confirmation prompt"""
	visible = true
	
	# Set focus mode to allow focus
	set_focus_mode(Control.FOCUS_ALL)
	
	# Enable all input processing at highest priority
	set_process_input(true)
	set_process_unhandled_key_input(true)
	set_process_unhandled_input(true)
	
	# Stop mouse events from passing through
	set_mouse_filter(Control.MOUSE_FILTER_STOP)
	
	# Grab focus to become exclusive input target
	grab_focus()
	
	# Mark input as handled to prevent other nodes from processing
	get_viewport().set_input_as_handled()
	

func hide_prompt() -> void:
	"""Hide the sleep confirmation prompt"""
	visible = false
	
	# Release focus
	release_focus()
	
	# Disable all input processing
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	
	# Allow mouse events to pass through
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	

func _input(event: InputEvent) -> void:
	"""Handle input at highest priority - fires before _unhandled_input()"""
	
	if not visible:
		return
	
	# Handle E key (ui_interact) - cancel sleep
	if event.is_action_pressed("ui_interact"):
		sleep_cancelled.emit()
		get_viewport().set_input_as_handled()
		return
	
	# Handle ESC key (ui_cancel) - cancel sleep
	if event.is_action_pressed("ui_cancel"):
		sleep_cancelled.emit()
		get_viewport().set_input_as_handled()
		return
	
	# Also handle ui_accept (E) as fallback - cancel sleep
	if event.is_action_pressed("ui_accept"):
		sleep_cancelled.emit()
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	"""Handle input as fallback - fires after _input() if event not handled"""
	if not visible:
		return
	
	# Fallback handlers (should not reach here if _input() works correctly)
	if event.is_action_pressed("ui_accept"):
		# E key - cancel sleep
		sleep_cancelled.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		# ESC key - cancel sleep
		sleep_cancelled.emit()
		get_viewport().set_input_as_handled()


func _on_yes_pressed() -> void:
	"""Handle Yes button press - confirm sleep"""
	sleep_confirmed.emit()


func _on_no_pressed() -> void:
	"""Handle No button press - cancel sleep"""
	sleep_cancelled.emit()
