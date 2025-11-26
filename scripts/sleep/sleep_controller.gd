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
	
	# Find bed spawn point in scene
	_find_bed_spawn_point()
	
	# Connect to sleep prompt UI signals (with deferred retry if not ready)
	_connect_sleep_prompt_signals()
	if not sleep_prompt_ui:
		# Retry connection after deferred lookup
		call_deferred("_connect_sleep_prompt_signals")
	
	# Connect to GameTimeManager pass_out signal
	_connect_pass_out_signal()


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
		print("SleepController: Connected to bed interaction")
	else:
		print("Warning: SleepController could not find bed interaction node")


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
	print("SleepController: request_sleep_from_bed() called")
	if _is_sleep_sequence_running:
		print("SleepController: Sleep sequence already running, returning")
		return
	if _is_sleep_prompt_open:
		print("SleepController: Sleep prompt already open, returning")
		return
	
	# Retry finding SleepPromptUI if not found yet (HUD might not have been ready in _ready())
	if not sleep_prompt_ui:
		print("SleepController: sleep_prompt_ui is null, retrying search...")
		_find_sleep_prompt_ui()
	
	_is_sleep_prompt_open = true
	print("SleepController: _is_sleep_prompt_open set to true")
	
	if sleep_prompt_ui:
		print("SleepController: sleep_prompt_ui reference exists")
		if sleep_prompt_ui.has_method("show_prompt"):
			print("SleepController: Calling sleep_prompt_ui.show_prompt()")
			sleep_prompt_ui.show_prompt()
		else:
			print("SleepController: ERROR - sleep_prompt_ui does not have show_prompt() method")
	else:
		print("SleepController: ERROR - sleep_prompt_ui is null, cannot show prompt")


func _find_sleep_prompt_ui() -> void:
	"""Find SleepPromptUI in the scene tree"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("SleepController: No current scene found")
		return
	
	print("SleepController: Searching for SleepPromptUI in scene: ", current_scene.name)
	
	# Search for SleepPromptUI in HUD
	var hud = current_scene.get_node_or_null("Hud")
	if hud:
		print("SleepController: Found Hud node")
		var hud_canvas = hud.get_node_or_null("HUD")
		if hud_canvas:
			print("SleepController: Found HUD CanvasLayer")
			sleep_prompt_ui = hud_canvas.get_node_or_null("SleepPromptUI")
			if sleep_prompt_ui:
				print("SleepController: Found SleepPromptUI via direct path")
			else:
				print("SleepController: SleepPromptUI not found in HUD/HUD path")
	else:
		print("SleepController: Hud node not found in current scene")
	
	# Fallback 1: Try via HUD singleton if available
	if not sleep_prompt_ui:
		if HUD and HUD.has_method("get") and "hud_scene_instance" in HUD:
			var hud_instance = HUD.get("hud_scene_instance")
			if hud_instance:
				print("SleepController: Attempting to find SleepPromptUI via HUD singleton")
				var hud_canvas = hud_instance.get_node_or_null("HUD")
				if hud_canvas:
					sleep_prompt_ui = hud_canvas.get_node_or_null("SleepPromptUI")
					if sleep_prompt_ui:
						print("SleepController: Found SleepPromptUI via HUD singleton")
	
	# Fallback 2: search recursively
	if not sleep_prompt_ui:
		print("SleepController: Attempting recursive search for SleepPromptUI")
		for child in current_scene.get_children():
			sleep_prompt_ui = _find_sleep_prompt_in_children(child)
			if sleep_prompt_ui:
				print("SleepController: Found SleepPromptUI via recursive search")
				break
	
	if sleep_prompt_ui:
		print("SleepController: SleepPromptUI reference set successfully")
	else:
		print("SleepController: ERROR - SleepPromptUI not found in scene tree")


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
	print("SleepController: Sleep sequence started")
	if _is_sleep_sequence_running:
		print("SleepController: Sleep sequence already running, returning")
		return
	
	_is_sleep_sequence_running = true
	
	# Pause gameplay/time
	if game_time_manager and game_time_manager.has_method("set_paused"):
		game_time_manager.set_paused(true)
		print("SleepController: Game paused")
	
	# Connect to fade_started signal to hide HUD
	if screen_fade_manager and screen_fade_manager.has_signal("fade_started"):
		if not screen_fade_manager.fade_started.is_connected(_on_fade_started):
			screen_fade_manager.fade_started.connect(_on_fade_started, CONNECT_ONE_SHOT)
			print("SleepController: Connected to fade_started signal")
	
	# Use fade_out_and_hold for sleep sequence (does NOT auto fade-in)
	if screen_fade_manager and screen_fade_manager.has_method("fade_out_and_hold"):
		print("SleepController: Starting fade_out_and_hold sequence")
		screen_fade_manager.fade_out_and_hold(
			2.0, # fade_out_duration: 2 seconds
			2.0, # hold_duration: 2 seconds
			_on_hold_period_callback # callback: called after hold period
		)
	else:
		# Fallback if fade manager doesn't have new method
		print("SleepController: WARNING - fade_out_and_hold not available, using fallback")
		if screen_fade_manager and screen_fade_manager.has_method("fade_out"):
			screen_fade_manager.fade_out(func():
				_on_fade_out_complete()
			)
		else:
			_on_fade_out_complete()


func _on_hold_period_callback() -> void:
	"""Called during the hold-black period to update date label"""
	print("SleepController: Hold period callback - calling sleep_to_next_morning()")
	# Advance to next morning (this will emit day_changed signal, updating date label)
	if game_time_manager and game_time_manager.has_method("sleep_to_next_morning"):
		game_time_manager.sleep_to_next_morning()
		print("SleepController: sleep_to_next_morning() called, date label should update")
		
		# Show date popup with new date
		if DatePopupManager and DatePopupManager.has_method("show_day_popup"):
			var new_day = game_time_manager.day
			var new_season = game_time_manager.season
			var new_year = game_time_manager.year
			print("SleepController: Showing date popup - Day: ", new_day)
			DatePopupManager.show_day_popup(new_day, new_season, new_year)
			
			# Connect to popup completion signal (one-shot)
			print("SleepController: Connecting to popup_sequence_finished")
			if DatePopupManager.has_signal("popup_sequence_finished"):
				if not DatePopupManager.popup_sequence_finished.is_connected(_on_date_popup_finished):
					DatePopupManager.popup_sequence_finished.connect(_on_date_popup_finished, CONNECT_ONE_SHOT)
					print("SleepController: Connected to popup_sequence_finished signal")
				else:
					print("SleepController: WARNING - Already connected to popup_sequence_finished")
			else:
				print("SleepController: ERROR - popup_sequence_finished signal not found")
		else:
			print("SleepController: WARNING - DatePopupManager not found or missing show_day_popup() method")
			# Fallback: start fade-in immediately if popup manager not available
			_on_date_popup_finished()
	else:
		print("SleepController: ERROR - sleep_to_next_morning() method not found")
		# Fallback: start fade-in immediately if time manager not available
		_on_date_popup_finished()


func _on_fade_out_complete() -> void:
	"""Called when fade out completes (fallback method)"""
	print("SleepController: _on_fade_out_complete() called (fallback)")
	# Advance to next morning
	if game_time_manager and game_time_manager.has_method("sleep_to_next_morning"):
		game_time_manager.sleep_to_next_morning()
	
	# Start fade in
	if screen_fade_manager and screen_fade_manager.has_method("fade_in"):
		screen_fade_manager.fade_in(func():
			_on_fade_in_complete()
		)
	else:
		_on_fade_in_complete()


func _on_date_popup_finished() -> void:
	"""Called when date popup sequence completes - starts fade-in"""
	print("SleepController: Popup finished → starting fade-in now")
	if screen_fade_manager and screen_fade_manager.has_method("fade_in"):
		screen_fade_manager.fade_in(func():
			_on_fade_in_complete()
		, 2.0)
		print("SleepController: Fade-in started (2.0s duration)")
	else:
		print("SleepController: ERROR - ScreenFadeManager.fade_in() not available")
		_on_fade_in_complete()


func _on_fade_in_complete() -> void:
	"""Called when fade in completes"""
	print("SleepController: _on_fade_in_complete() called")
	
	# Delay player lookup by two frames to ensure player node exists
	await get_tree().process_frame
	await get_tree().process_frame
	print("SleepController: Double frame delay complete, looking up player")
	
	# Teleport player to bed spawn
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if bed_spawn_point:
			player.global_position = bed_spawn_point.global_position
			print("SleepController: Player found → teleporting to bed spawn")
		else:
			print("SleepController: WARNING - Bed spawn point not found")
	else:
		print("SleepController: ERROR - Player still not found after 2-frame delay")
	
	# Unpause gameplay/time
	if game_time_manager and game_time_manager.has_method("set_paused"):
		game_time_manager.set_paused(false)
		print("SleepController: Game unpaused")
	
	# Ensure scene tree is also unpaused
	if get_tree().paused:
		get_tree().paused = false
		print("SleepController: Scene tree unpaused")
	
	# Show HUD again after fade-in completes
	_show_hud()
	
	_is_sleep_sequence_running = false
	print("SleepController: Sleep sequence complete")


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


func _on_fade_started() -> void:
	"""Called when fade-out starts - hide HUD"""
	print("SleepController: Fade started, hiding HUD")
	_hide_hud()


func _hide_hud() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.visible = false
		print("SleepController: HIDING HUD ", hud)


func _show_hud() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.visible = true
		print("SleepController: SHOWING HUD ", hud)
