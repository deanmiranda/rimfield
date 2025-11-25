extends Area2D

## BedInteraction - Handles player interaction with the bed
##
## This script detects when the player enters the bed area, shows a tooltip,
## and allows the player to sleep by pressing E (ui_accept).
##
## When the player sleeps, it calls GameTimeManager.sleep_to_next_morning()
## to advance time to the next day.

var player_in_bed_area: bool = false
var tooltip: Label = null


func _ready() -> void:
	"""Initialize bed interaction and set up tooltip label"""
	# Find existing Label child or create one
	tooltip = get_node_or_null("Label")
	
	if not tooltip:
		# Create tooltip label programmatically
		tooltip = Label.new()
		tooltip.name = "Label"
		add_child(tooltip)
		
		# Configure tooltip appearance
		tooltip.text = "Press E to Sleep"
		tooltip.visible = false
		tooltip.position = Vector2(0, -20) # Position above bed
		tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tooltip.add_theme_color_override("font_color", Color.WHITE)
	
	# Connect Area2D signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the bed area"""
	# Check if the body is the player
	if _is_player(body):
		player_in_bed_area = true
		if tooltip:
			tooltip.visible = true


func _on_body_exited(body: Node2D) -> void:
	"""Called when a body exits the bed area"""
	# Check if the body is the player
	if _is_player(body):
		player_in_bed_area = false
		if tooltip:
			tooltip.visible = false


func _unhandled_input(event: InputEvent) -> void:
	"""Handle input when player is in bed area"""
	if player_in_bed_area and event.is_action_pressed("ui_accept"):
		# Player pressed E while in bed area - go to sleep
		if GameTimeManager:
			if GameTimeManager.has_method("sleep_to_next_morning"):
				GameTimeManager.sleep_to_next_morning()
			else:
				print("Error: GameTimeManager.sleep_to_next_morning() method not found")
		else:
			print("Error: GameTimeManager not found in bed_interaction.gd")


func _is_player(body: Node2D) -> bool:
	"""Check if the given body is the player character
	
	Args:
		body: The body that entered/exited the area
		
	Returns:
		True if body is the player, False otherwise
	"""
	# First check if body is in the "player" group (preferred method)
	if body.is_in_group("player"):
		return true
	
	# Fallback: check if it's a CharacterBody2D with start_interaction method
	# (matches the pattern used in house_interaction.gd)
	if body is CharacterBody2D and body.has_method("start_interaction"):
		return true
	
	return false
