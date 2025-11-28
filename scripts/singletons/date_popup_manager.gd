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
	# Load the date popup scene
	date_popup_scene = load("res://scenes/ui/date_popup.tscn")
	if not date_popup_scene:
		return
	
	# Instantiate the scene
	date_popup_instance = date_popup_scene.instantiate()
	if not date_popup_instance:
		return
	
	# Add to scene tree
	add_child(date_popup_instance)
	
	# Find the Label node
	var control = date_popup_instance.get_node_or_null("Control")
	if control:
		date_label = control.get_node_or_null("Label")
		if date_label:
			# Ensure label starts invisible (will be made visible by show_day_popup)
			date_label.modulate.a = 0.0
	
	# Ensure the Control node is hidden initially
	if control:
		control.visible = false


func show_day_popup(day: int, season: int, year: int) -> void:
	"""Show the date popup with fade in/hold/fade out animation
	
	Args:
		day: Day of season (1-28)
		season: Season index (0-3: Spring, Summer, Fall, Winter)
		year: Year number (1+)
	"""
	
	if not date_popup_instance or not date_label:
		return
	
	# Build date string
	var season_name: String
	if season >= 0 and season < SEASON_NAMES.size():
		season_name = SEASON_NAMES[season]
	else:
		season_name = "Unknown"
	
	var date_text = "%s %d, Year %d" % [season_name, day, year]
	date_label.text = date_text
	
	# Get the Control node and make it visible
	var control = date_popup_instance.get_node_or_null("Control")
	if not control:
		return
	
	control.visible = true
	date_label.modulate.a = 0.0 # Start transparent
	
	# Kill existing tween if any
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create new tween for fade in/hold/fade out
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Phase 1: Fade in (1.0s)
	_tween.tween_property(date_label, "modulate:a", 1.0, 1.0)
	
	# Phase 2: Hold (1.5s)
	_tween.tween_interval(1.5)

	# Phase 3: Fade out (1.0s)

	_tween.tween_property(date_label, "modulate:a", 0.0, 1.0)
	_tween.tween_callback(func():
		hide_popup()
		popup_sequence_finished.emit()
	)


func hide_popup() -> void:
	"""Hide the date popup"""
	if date_popup_instance:
		var control = date_popup_instance.get_node_or_null("Control")
		if control:
			control.visible = false