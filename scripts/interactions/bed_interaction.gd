extends Area2D

## BedInteraction - Handles player detection in bed area
##
## This script detects when the player enters/exits the bed area, shows/hides a tooltip,
## and emits signals for SleepController to handle.
##
## This script does NOT handle input - UiManager handles E key globally.

# Signals emitted when player enters/exits bed area
signal player_entered_bed_area(player: Node2D)
signal player_exited_bed_area(player: Node2D)


func _ready() -> void:
	"""Initialize bed interaction"""
	# Connect Area2D signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	"""Called when a body enters the bed area"""
	# Check if the body is the player
	if _is_player(body):
		# Show tooltip via SleepController (SleepController is a scene node, not a singleton)
		var sleep_controller = _find_sleep_controller()
		if sleep_controller and sleep_controller.has_method("show_bed_tooltip"):
			sleep_controller.show_bed_tooltip()
		# Emit signal for SleepController
		player_entered_bed_area.emit(body)


func _on_body_exited(body: Node2D) -> void:
	"""Called when a body exits the bed area"""
	# Check if the body is the player
	if _is_player(body):
		# Hide tooltip via SleepController (SleepController is a scene node, not a singleton)
		var sleep_controller = _find_sleep_controller()
		if sleep_controller and sleep_controller.has_method("hide_bed_tooltip"):
			sleep_controller.hide_bed_tooltip()
		# Emit signal for SleepController
		player_exited_bed_area.emit(body)


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


func _find_sleep_controller() -> Node:
	"""Find SleepController node in the current scene
	SleepController is a scene node (not a singleton), so we search the current scene.
	
	Returns:
		SleepController node if found, null otherwise
	"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	
	# Try direct node path first (SleepController is a direct child of scene root)
	var sleep_controller = current_scene.get_node_or_null("SleepController")
	if sleep_controller:
		return sleep_controller
	
	# Fallback: search recursively for node with sleep_controller script
	for child in current_scene.get_children():
		var found = _find_sleep_controller_in_children(child)
		if found:
			return found
	
	return null


func _find_sleep_controller_in_children(node: Node) -> Node:
	"""Recursively search for node with sleep_controller script"""
	var script = node.get_script()
	if script:
		var script_path = script.resource_path
		if script_path and "sleep_controller" in script_path:
			return node
	
	for child in node.get_children():
		var result = _find_sleep_controller_in_children(child)
		if result:
			return result
	
	return null
