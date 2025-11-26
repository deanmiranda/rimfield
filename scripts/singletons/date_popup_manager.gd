extends Node

## DatePopupManager - Manages the date popup UI during sleep sequence
##
## Displays a large date popup (e.g., "Spring 2, Year 1") during the sleep
## sequence hold period. Uses fade in/hold/fade out animation.

# Signal emitted when popup sequence (fade in/hold/fade out) completes
signal popup_sequence_finished

# Season names array - maps season index to display name
const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]

var date_popup_scene: PackedScene = null
var date_popup_instance: CanvasLayer = null
var date_label: Label = null
var _tween: Tween = null


func _ready() -> void:
	"""Initialize DatePopupManager and load the date popup scene"""
	print("DatePopupManager: Initializing")
	# Load the date popup scene
	date_popup_scene = load("res://scenes/ui/date_popup.tscn")
	if not date_popup_scene:
		print("DatePopupManager: ERROR - Failed to load date_popup.tscn")
		return
	
	# Instantiate the scene
	date_popup_instance = date_popup_scene.instantiate()
	if not date_popup_instance:
		print("DatePopupManager: ERROR - Failed to instantiate date popup scene")
		return
	
	# Add to scene tree
	add_child(date_popup_instance)
	
	# Find the Label node
	var control = date_popup_instance.get_node_or_null("Control")
	if control:
		date_label = control.get_node_or_null("Label")
		if date_label:
			print("DatePopupManager: Date label found successfully")
			# Ensure label starts invisible (will be made visible by show_day_popup)
			date_label.modulate.a = 0.0
		else:
			print("DatePopupManager: ERROR - Label not found in Control")
	else:
		print("DatePopupManager: ERROR - Control not found in date popup instance")
	
	# Ensure the Control node is hidden initially
	if control:
		control.visible = false
		print("DatePopupManager: Date popup initialized and hidden")


func show_day_popup(day: int, season: int, year: int) -> void:
	"""Show the date popup with fade in/hold/fade out animation
	
	Args:
		day: Day of season (1-28)
		season: Season index (0-3: Spring, Summer, Fall, Winter)
		year: Year number (1+)
	"""
	print("DatePopupManager: show_day_popup() called - Day: ", day, ", Season: ", season, ", Year: ", year)
	
	if not date_popup_instance or not date_label:
		print("DatePopupManager: ERROR - Date popup or label not initialized")
		return
	
	# Build date string
	var season_name: String
	if season >= 0 and season < SEASON_NAMES.size():
		season_name = SEASON_NAMES[season]
	else:
		season_name = "Unknown"
		print("DatePopupManager: WARNING - Invalid season index: ", season)
	
	var date_text = "%s %d, Year %d" % [season_name, day, year]
	date_label.text = date_text
	print("DatePopupManager: Date text set to: \"", date_text, "\"")
	
	# Get the Control node and make it visible
	var control = date_popup_instance.get_node_or_null("Control")
	if not control:
		print("DatePopupManager: ERROR - Control node not found")
		return
	
	control.visible = true
	date_label.modulate.a = 0.0 # Start transparent
	print("DatePopupManager: Date popup made visible, starting animation")
	
	# Kill existing tween if any
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create new tween for fade in/hold/fade out
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Phase 1: Fade in (1.0s)
	print("DatePopupManager: Phase 1 - Fade in started (1.0s)")
	_tween.tween_property(date_label, "modulate:a", 1.0, 1.0)
	_tween.tween_callback(func():
		print("DatePopupManager: Phase 1 - Fade in complete")
	)
	
	# Phase 2: Hold (1.5s)
	print("DatePopupManager: Phase 2 - Hold period started (1.5s)")
	_tween.tween_interval(1.5)
	_tween.tween_callback(func():
		print("DatePopupManager: Phase 2 - Hold period complete")
	)
	
	# Phase 3: Fade out (1.0s)
	_tween.tween_callback(func():
		print("DatePopupManager: Phase 3 - Fade out started (1.0s)")
	)
	_tween.tween_property(date_label, "modulate:a", 0.0, 1.0)
	_tween.tween_callback(func():
		print("DatePopupManager: Phase 3 - Fade out complete, hiding popup and emitting signal")
		hide_popup()
		popup_sequence_finished.emit()
		print("DatePopupManager: Popup sequence complete, popup_sequence_finished signal emitted")
	)


func hide_popup() -> void:
	"""Hide the date popup"""
	print("DatePopupManager: hide_popup() called")
	if date_popup_instance:
		var control = date_popup_instance.get_node_or_null("Control")
		if control:
			control.visible = false
			print("DatePopupManager: Date popup hidden")
		else:
			print("DatePopupManager: WARNING - Control node not found when hiding")
	else:
		print("DatePopupManager: WARNING - Date popup instance not found when hiding")
