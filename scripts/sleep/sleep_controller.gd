extends Node

## SleepController - Coordinates sleep flow and state
##
## This script tracks sleep-related state and coordinates between BedInteraction
## and the sleep sequence. It does NOT handle input directly - UiManager handles
## E key globally and calls request_sleep_from_bed() when appropriate.

# State flags
var _is_sleep_prompt_open: bool = false
var _is_sleep_sequence_running: bool = false
var _is_player_in_bed_area: bool = false

# Reference to bed interaction node
var bed_interaction: Area2D = null

# References to game systems (singletons)
var game_time_manager: Node = null
var screen_fade_manager: Node = null
var sleep_prompt_ui: Control = null
var bed_tooltip_label: Label = null
var bed_spawn_point: Node2D = null


func _ready() -> void:
	"""Initialize SleepController and connect to bed signals"""
	# Get singleton references
	game_time_manager = GameTimeManager
	# Access ScreenFadeManager via autoload path
	screen_fade_manager = get_node_or_null("/root/ScreenFadeManager")
	
	# Find bed interaction node in the scene
	_find_bed_interaction()
	
	# Find sleep prompt UI in HUD (with deferred retry if not ready)
	_find_sleep_prompt_ui()
	if not sleep_prompt_ui:
		# HUD might not be ready yet, retry after a frame
		call_deferred("_find_sleep_prompt_ui")
	
	# Find bed tooltip label in HUD (with deferred retry if not ready)
	_find_bed_tooltip_label()
	if not bed_tooltip_label:
		# HUD might not be ready yet, retry after a frame
		call_deferred("_find_bed_tooltip_label")
	
	# Find bed spawn point in scene
	_find_bed_spawn_point()
	
	# Connect to sleep prompt UI signals (with deferred retry if not ready)
	_connect_sleep_prompt_signals()
	if not sleep_prompt_ui:
		# Retry connection after deferred lookup
		call_deferred("_connect_sleep_prompt_signals")
	
	# Connect to GameTimeManager pass_out signal
	_connect_pass_out_signal()
	
	# Start with _process disabled (only update position when tooltip is visible)
	set_process(false)


func _find_bed_interaction() -> void:
	"""Find the BedInteraction Area2D node in the current scene"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	# Search for Area2D node with bed_interaction script
	for child in current_scene.get_children():
		bed_interaction = _find_bed_in_children(child)
		if bed_interaction:
			break
	
	# If not found, try searching in the scene tree
	if not bed_interaction:
		var bed_area = current_scene.get_node_or_null("BedArea")
		if bed_area and bed_area is Area2D:
			bed_interaction = bed_area
	
	# Connect to bed signals if found
	if bed_interaction:
		if bed_interaction.has_signal("player_entered_bed_area"):
			if not bed_interaction.player_entered_bed_area.is_connected(_on_player_entered_bed_area):
				bed_interaction.player_entered_bed_area.connect(_on_player_entered_bed_area)
		if bed_interaction.has_signal("player_exited_bed_area"):
			if not bed_interaction.player_exited_bed_area.is_connected(_on_player_exited_bed_area):
				bed_interaction.player_exited_bed_area.connect(_on_player_exited_bed_area)


func _find_bed_in_children(node: Node) -> Area2D:
	"""Recursively search for Area2D with bed_interaction script"""
	if node is Area2D:
		var script = node.get_script()
		if script:
			var script_path = script.resource_path
			if script_path and "bed_interaction" in script_path:
				return node
	
	for child in node.get_children():
		var result = _find_bed_in_children(child)
		if result:
			return result
	
	return null


func is_player_in_bed_area() -> bool:
	"""Check if player is currently in bed area
	
	Returns:
		True if player is in bed area, False otherwise
	"""
	return _is_player_in_bed_area


func is_sleep_prompt_open() -> bool:
	"""Check if sleep prompt is currently open
	
	Returns:
		True if sleep prompt is open, False otherwise
	"""
	return _is_sleep_prompt_open


func is_sleep_sequence_running() -> bool:
	"""Check if sleep sequence is currently running
	
	Returns:
		True if sleep sequence is running, False otherwise
	"""
	return _is_sleep_sequence_running


func request_sleep_from_bed() -> void:
	"""Called by UiManager when E is pressed and player is in bed area"""
	if _is_sleep_sequence_running:
		return
	if _is_sleep_prompt_open:
		return
	
	# Retry finding SleepPromptUI if not found yet (HUD might not have been ready in _ready())
	if not sleep_prompt_ui:
		_find_sleep_prompt_ui()
	
	_is_sleep_prompt_open = true
	
	if sleep_prompt_ui:
		if sleep_prompt_ui.has_method("show_prompt"):
			sleep_prompt_ui.show_prompt()

func _find_sleep_prompt_ui() -> void:
	"""Find SleepPromptUI in the scene tree"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	
	# Search for SleepPromptUI in HUD
	var hud = current_scene.get_node_or_null("Hud")
	if hud:
		var hud_canvas = hud.get_node_or_null("HUD")
		if hud_canvas:
			sleep_prompt_ui = hud_canvas.get_node_or_null("SleepPromptUI")
	
	# Fallback 1: Try via HUD singleton if available
	if not sleep_prompt_ui:
		if HUD and HUD.has_method("get") and "hud_scene_instance" in HUD:
			var hud_instance = HUD.get("hud_scene_instance")
			if hud_instance:
				var hud_canvas = hud_instance.get_node_or_null("HUD")
				if hud_canvas:
					sleep_prompt_ui = hud_canvas.get_node_or_null("SleepPromptUI")

	# Fallback 2: search recursively
	if not sleep_prompt_ui:
		for child in current_scene.get_children():
			sleep_prompt_ui = _find_sleep_prompt_in_children(child)
			if sleep_prompt_ui:
				break
	

func _find_sleep_prompt_in_children(node: Node) -> Control:
	"""Recursively search for SleepPromptUI"""
	if node is Control:
		var script = node.get_script()
		if script:
			var script_path = script.resource_path
			if script_path and "sleep_prompt_ui" in script_path:
				return node
	
	for child in node.get_children():
		var result = _find_sleep_prompt_in_children(child)
		if result:
			return result
	
	return null


func _find_bed_tooltip_label() -> void:
	"""Find BedTooltipLabel in the scene tree
	Expected path: /root/UiManager/Hud/HUD/BedTooltipLabel
	Current search: Resolves from root via UiManager, then Hud/HUD/BedTooltipLabel
	"""
	# Primary: Resolve from root via UiManager (most reliable, doesn't depend on current_scene)
	var root := get_tree().root
	var ui_manager := root.get_node_or_null("UiManager")
	if ui_manager:
		var hud_canvas := ui_manager.get_node_or_null("Hud")
		if hud_canvas:
			var hud_root := hud_canvas.get_node_or_null("HUD")
			if hud_root:
				bed_tooltip_label = hud_root.get_node_or_null("BedTooltipLabel")
				if bed_tooltip_label:
					return
	
	# Fallback 1: Try via HUD singleton's hud_scene_instance if available
	if HUD and HUD.hud_scene_instance != null:
		var hud_instance = HUD.hud_scene_instance
		if hud_instance:
			var hud_root = hud_instance.get_node_or_null("HUD")
			if hud_root:
				bed_tooltip_label = hud_root.get_node_or_null("BedTooltipLabel")
				if bed_tooltip_label:
					return
	
	# Fallback 2: Search in current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		var hud = current_scene.get_node_or_null("Hud")
		if hud:
			var hud_root = hud.get_node_or_null("HUD")
			if hud_root:
				bed_tooltip_label = hud_root.get_node_or_null("BedTooltipLabel")
				if bed_tooltip_label:
					return
	
	if bed_tooltip_label:
		return
	else:
		push_warning("SleepController: BedTooltipLabel not found at expected HUD path")


func _find_bed_tooltip_in_children(node: Node) -> Label:
	"""Recursively search for BedTooltipLabel"""
	if node is Label and node.name == "BedTooltipLabel":
		return node
	
	for child in node.get_children():
		var result = _find_bed_tooltip_in_children(child)
		if result:
			return result
	
	return null


func show_bed_tooltip() -> void:
	"""Show the bed tooltip label"""
	if bed_tooltip_label:
		bed_tooltip_label.visible = true
		set_process(true) # Start updating position
	else:
		# Retry finding the label if not found yet
		_find_bed_tooltip_label()
		if bed_tooltip_label:
			bed_tooltip_label.visible = true
			set_process(true) # Start updating position


func hide_bed_tooltip() -> void:
	"""Hide the bed tooltip label"""
	if bed_tooltip_label:
		bed_tooltip_label.visible = false
		set_process(false) # Stop updating position when hidden
	else:
		# Retry finding the label if not found yet
		_find_bed_tooltip_label()
		if bed_tooltip_label:
			bed_tooltip_label.visible = false
			set_process(false) # Stop updating position when hidden


func _find_bed_spawn_point() -> void:
	"""Find BedSpawnPoint in the current scene"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	
	bed_spawn_point = current_scene.get_node_or_null("BedSpawnPoint")


func _connect_sleep_prompt_signals() -> void:
	"""Connect to SleepPromptUI signals"""
	if sleep_prompt_ui:
		if sleep_prompt_ui.has_signal("sleep_confirmed"):
			if not sleep_prompt_ui.sleep_confirmed.is_connected(_on_sleep_confirmed):
				sleep_prompt_ui.sleep_confirmed.connect(_on_sleep_confirmed)
		if sleep_prompt_ui.has_signal("sleep_cancelled"):
			if not sleep_prompt_ui.sleep_cancelled.is_connected(_on_sleep_cancelled):
				sleep_prompt_ui.sleep_cancelled.connect(_on_sleep_cancelled)


func _connect_pass_out_signal() -> void:
	"""Connect to GameTimeManager pass_out signal"""
	if game_time_manager:
		if game_time_manager.has_signal("pass_out"):
			if not game_time_manager.pass_out.is_connected(_on_pass_out):
				game_time_manager.pass_out.connect(_on_pass_out)


func _on_sleep_confirmed() -> void:
	"""Called when player confirms sleep"""
	_is_sleep_prompt_open = false
	if sleep_prompt_ui and sleep_prompt_ui.has_method("hide_prompt"):
		sleep_prompt_ui.hide_prompt()
	_execute_sleep_sequence()


func _on_sleep_cancelled() -> void:
	"""Called when player cancels sleep"""
	_is_sleep_prompt_open = false
	if sleep_prompt_ui and sleep_prompt_ui.has_method("hide_prompt"):
		sleep_prompt_ui.hide_prompt()


func _execute_sleep_sequence() -> void:
	"""Execute the full sleep sequence: fade out → hold black (update date) → fade in → teleport"""
	if _is_sleep_sequence_running:
		return
	
	_is_sleep_sequence_running = true
	
	# Pause gameplay/time
	if game_time_manager and game_time_manager.has_method("set_paused"):
		game_time_manager.set_paused(true)
	
	# Connect to fade_started signal to hide HUD
	if screen_fade_manager and screen_fade_manager.has_signal("fade_started"):
		if not screen_fade_manager.fade_started.is_connected(_on_fade_started):
			screen_fade_manager.fade_started.connect(_on_fade_started, CONNECT_ONE_SHOT)
	
	# Use fade_out_and_hold for sleep sequence (does NOT auto fade-in)
	if screen_fade_manager and screen_fade_manager.has_method("fade_out_and_hold"):
		screen_fade_manager.fade_out_and_hold(
			2.0, # fade_out_duration: 2 seconds
			2.0, # hold_duration: 2 seconds
			_on_hold_period_callback # callback: called after hold period
		)
	else:
		# Fallback if fade manager doesn't have new method
		if screen_fade_manager and screen_fade_manager.has_method("fade_out"):
			screen_fade_manager.fade_out(Callable(self, "_on_fade_out_complete"))
		else:
			_on_fade_out_complete()


func _on_hold_period_callback() -> void:
	"""Called during the hold-black period to update date label"""
	# Advance to next morning (this will emit day_changed signal, updating date label)
	if game_time_manager and game_time_manager.has_method("sleep_to_next_morning"):
		game_time_manager.sleep_to_next_morning()
		
		# Restore energy and give happiness boost after sleeping
		if PlayerStatsManager:
			PlayerStatsManager.restore_energy_full()
			PlayerStatsManager.modify_happiness(5) # Small happiness boost for good sleep
		
		# Show date popup with new date
		if DatePopupManager and DatePopupManager.has_method("show_day_popup"):
			var new_day = game_time_manager.day
			var new_season = game_time_manager.season
			var new_year = game_time_manager.year
			DatePopupManager.show_day_popup(new_day, new_season, new_year)
			
			# Connect to popup completion signal (one-shot)
			if DatePopupManager.has_signal("popup_sequence_finished"):
				if not DatePopupManager.popup_sequence_finished.is_connected(_on_date_popup_finished):
					DatePopupManager.popup_sequence_finished.connect(_on_date_popup_finished, CONNECT_ONE_SHOT)
		else:
			# Fallback: start fade-in immediately if popup manager not available
			_on_date_popup_finished()
	else:
		# Fallback: start fade-in immediately if time manager not available
		_on_date_popup_finished()


func _on_fade_out_complete() -> void:
	"""Called when fade out completes (fallback method)"""
	# Advance to next morning
	if game_time_manager and game_time_manager.has_method("sleep_to_next_morning"):
		game_time_manager.sleep_to_next_morning()
	
	# Restore energy and give happiness boost after sleeping
	if PlayerStatsManager:
		PlayerStatsManager.restore_energy_full()
		PlayerStatsManager.modify_happiness(5) # Small happiness boost for good sleep
	
	# Start fade in
	if screen_fade_manager and screen_fade_manager.has_method("fade_in"):
		screen_fade_manager.fade_in(Callable(self, "_on_fade_in_complete"))
	else:
		_on_fade_in_complete()


func _on_date_popup_finished() -> void:
	"""Called when date popup sequence completes - starts fade-in"""
	if screen_fade_manager and screen_fade_manager.has_method("fade_in"):
		screen_fade_manager.fade_in(Callable(self, "_on_fade_in_complete"), 2.0)
	else:
		_on_fade_in_complete()


func _on_fade_in_complete() -> void:
	"""Called when fade in completes"""
	
	# Get tree reference - check if it's valid
	var tree = get_tree()
	if not tree:
		return
	
	# Delay player lookup by two frames to ensure player node exists
	await tree.process_frame
	await tree.process_frame
	
	# Teleport player to bed spawn
	var player = tree.get_first_node_in_group("player")
	if player:
		if bed_spawn_point:
			player.global_position = bed_spawn_point.global_position

	# Unpause gameplay/time
	if game_time_manager and game_time_manager.has_method("set_paused"):
		game_time_manager.set_paused(false)
	
	# Ensure scene tree is also unpaused
	if get_tree().paused:
		get_tree().paused = false
	
	# Show HUD again after fade-in completes
	_show_hud()
	
	_is_sleep_sequence_running = false


func _get_player() -> Node2D:
	"""Find the player node in the scene
	
	Returns:
		Player node if found, null otherwise
	"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


func _on_pass_out() -> void:
	"""Called when player passes out at 2AM"""
	if _is_sleep_sequence_running:
		return
	# Do NOT open the prompt, just run the sequence directly
	_execute_sleep_sequence()


func _on_player_entered_bed_area(_player: Node2D) -> void:
	"""Called when player enters bed area"""
	_is_player_in_bed_area = true


func _on_player_exited_bed_area(_player: Node2D) -> void:
	"""Called when player exits bed area"""
	_is_player_in_bed_area = false


func _process(_delta: float) -> void:
	"""Update tooltip position in screen space when visible"""
	if not bed_tooltip_label or not bed_tooltip_label.visible:
		return
	
	if not bed_interaction:
		return
	
	# Convert bed world position to screen position
	var bed_world_pos = bed_interaction.global_position
	var screen_pos = _world_to_screen_position(bed_world_pos)
	
	# Position label above bed in screen space (centered horizontally, offset upward)
	bed_tooltip_label.position = screen_pos + Vector2(-bed_tooltip_label.size.x / 2, -36)


func _world_to_screen_position(world_pos: Vector2) -> Vector2:
	"""Convert world position to screen position"""
	var viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	
	var camera = viewport.get_camera_2d()
	if not camera:
		return Vector2.ZERO
	
	# Use the camera's canvas transform which properly converts world to screen
	var canvas_transform = camera.get_canvas_transform()
	var screen_pos = canvas_transform * world_pos
	
	return screen_pos


func _on_fade_started() -> void:
	"""Called when fade-out starts - hide HUD"""
	_hide_hud()


func _hide_hud() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.visible = false


func _show_hud() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.visible = true
