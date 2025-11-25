extends Area2D

## BedInteraction - Handles player interaction with the bed
##
## This script detects when the player enters the bed area, shows a tooltip,
## and allows the player to sleep by pressing E (ui_accept) after confirmation.
##
## When the player sleeps, it calls GameTimeManager.sleep_to_next_morning()
## to advance time to the next day.

var player_in_bed_area: bool = false
var confirm_active: bool = false
var tooltip: Label = null
var confirm_label: Label = null


func _ready() -> void:
	"""Initialize bed interaction and set up tooltip and confirmation labels"""
	# Find existing Label children if present
	tooltip = null
	confirm_label = null
	
	for child in get_children():
		if child is Label:
			# Use first Label as tooltip if not already assigned
			if not tooltip:
				tooltip = child
			# Use second Label as confirm_label if not already assigned
			elif not confirm_label:
				confirm_label = child
	
	# Create tooltip label if not found
	if not tooltip:
		tooltip = Label.new()
		add_child(tooltip)
		tooltip.text = "Press E to Sleep"
		tooltip.visible = false
		tooltip.position = Vector2(0, -20) # Position above bed
		tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Create confirmation label if not found
	if not confirm_label:
		confirm_label = Label.new()
		add_child(confirm_label)
		confirm_label.text = "Go to bed?\n[E] Yes    [Esc] No"
		confirm_label.visible = false
		confirm_label.position = Vector2(0, -20) # Position above bed (same as tooltip)
		confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Connect Area2D signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	"""Called when a body enters the bed area"""
	# Check if the body is the player
	if _is_player(body):
		player_in_bed_area = true
		# Reset confirmation state when entering
		confirm_active = false
		if tooltip:
			tooltip.visible = true
		if confirm_label:
			confirm_label.visible = false


func _on_body_exited(body: Node) -> void:
	"""Called when a body exits the bed area"""
	# Check if the body is the player
	if _is_player(body):
		player_in_bed_area = false
		# Reset confirmation state when exiting
		confirm_active = false
		if tooltip:
			tooltip.visible = false
		if confirm_label:
			confirm_label.visible = false


func _input(event: InputEvent) -> void:
	"""Handle input when player is in bed area - must use _input to catch events before pause menu"""
	# Only process input if player is in bed area
	if not player_in_bed_area:
		return
	
	# Handle E (ui_accept) press
	if event.is_action_pressed("ui_accept"):
		if not confirm_active:
			# First E press: show confirmation
			confirm_active = true
			if tooltip:
				tooltip.visible = false
			if confirm_label:
				confirm_label.visible = true
			# Consume event to prevent inventory from opening
			get_viewport().set_input_as_handled()
		else:
			# Second E press (confirmation active): confirm sleep
			if GameTimeManager:
				GameTimeManager.sleep_to_next_morning()
			# Reset confirmation state
			confirm_active = false
			if confirm_label:
				confirm_label.visible = false
			if tooltip:
				tooltip.visible = true
			# Consume event
			get_viewport().set_input_as_handled()
	
	# Handle ESC (ui_cancel) press when confirmation is active
	elif event.is_action_pressed("ui_cancel") and confirm_active:
		# Cancel confirmation
		confirm_active = false
		if confirm_label:
			confirm_label.visible = false
		if tooltip:
			tooltip.visible = true
		# Consume event to prevent pause menu from opening
		get_viewport().set_input_as_handled()


func _is_player(body: Node) -> bool:
	"""Check if the given body is the player character
	
	Args:
		body: The body that entered/exited the area
		
	Returns:
		True if body is the player, False otherwise
	"""
	# Prefer checking "player" group if available
	if body.is_in_group("player"):
		return true
	
	# Fallback: check if it's a CharacterBody2D with start_interaction method
	# (matches the pattern used in house_interaction.gd)
	if body is CharacterBody2D and body.has_method("start_interaction"):
		return true
	
	return false
