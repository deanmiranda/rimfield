extends Control

## SleepPromptUI - Sleep confirmation dialog
##
## Displays a confirmation prompt when player wants to sleep.
## Handles E (confirm) and ESC (cancel) input.

# Signals
signal sleep_confirmed
signal sleep_cancelled


func _ready() -> void:
	"""Initialize sleep prompt UI"""
	visible = false
	set_process_unhandled_input(true)


func show_prompt() -> void:
	"""Show the sleep confirmation prompt"""
	print("SleepPromptUI: show_prompt called")
	visible = true
	print("SleepPromptUI: visible set to ", visible)
	
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
	
	print("SleepPromptUI: Focus grabbed, all input processing enabled, input marked as handled")


func hide_prompt() -> void:
	"""Hide the sleep confirmation prompt"""
	print("SleepPromptUI: hide_prompt called")
	visible = false
	print("SleepPromptUI: visible set to ", visible)
	
	# Release focus
	release_focus()
	
	# Disable all input processing
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	
	# Allow mouse events to pass through
	set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	
	print("SleepPromptUI: Focus released, all input processing disabled")


func _input(event: InputEvent) -> void:
	"""Handle input at highest priority - fires before _unhandled_input()"""
	print("SleepPromptUI: _input() called, visible = ", visible, ", event type = ", event.get_class())
	
	if not visible:
		print("SleepPromptUI: Not visible, returning early from _input()")
		return
	
	# Handle E key (ui_interact) - confirm sleep
	if event.is_action_pressed("ui_interact"):
		print("SleepPromptUI: ui_interact (E) pressed in _input(), confirming sleep")
		sleep_confirmed.emit()
		get_viewport().set_input_as_handled()
		print("SleepPromptUI: Input marked as handled, event stopped")
		return
	
	# Handle ESC key (ui_cancel) - cancel sleep
	if event.is_action_pressed("ui_cancel"):
		print("SleepPromptUI: ui_cancel (ESC) pressed in _input(), cancelling sleep")
		sleep_cancelled.emit()
		get_viewport().set_input_as_handled()
		print("SleepPromptUI: Input marked as handled, event stopped")
		return
	
	# Also handle ui_accept (E) as fallback
	if event.is_action_pressed("ui_accept"):
		print("SleepPromptUI: ui_accept (E) pressed in _input(), confirming sleep")
		sleep_confirmed.emit()
		get_viewport().set_input_as_handled()
		print("SleepPromptUI: Input marked as handled, event stopped")
		return


func _unhandled_input(event: InputEvent) -> void:
	"""Handle input as fallback - fires after _input() if event not handled"""
	print("SleepPromptUI: _unhandled_input called, visible = ", visible)
	if not visible:
		print("SleepPromptUI: Not visible, returning early from _unhandled_input()")
		return
	
	# Fallback handlers (should not reach here if _input() works correctly)
	if event.is_action_pressed("ui_accept"):
		# E key - confirm sleep
		print("SleepPromptUI: ui_accept (E) pressed in _unhandled_input(), confirming sleep (fallback)")
		sleep_confirmed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		# ESC key - cancel sleep
		print("SleepPromptUI: ui_cancel (ESC) pressed in _unhandled_input(), cancelling sleep (fallback)")
		sleep_cancelled.emit()
		get_viewport().set_input_as_handled()
