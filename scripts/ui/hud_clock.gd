extends Label

## HUD Clock - Displays current game time
##
## This script subscribes to GameTimeManager.time_changed signal and
## displays the current time in 12-hour format (H:MM AM/PM).
##
## This script is READ-ONLY - it does NOT modify time or call advance_time().
## It only listens to signals and updates the Label text.

func _ready() -> void:
	# Connect to GameTimeManager time_changed signal
	if GameTimeManager:
		if not GameTimeManager.time_changed.is_connected(_on_time_changed):
			GameTimeManager.time_changed.connect(_on_time_changed)
		
		# Immediately display current time so label is correct at startup
		_on_time_changed(GameTimeManager.time_of_day)
	else:
		print("Error: GameTimeManager not found in hud_clock.gd")


func _on_time_changed(time_of_day: int) -> void:
	"""Handle time_changed signal from GameTimeManager.
	
	Args:
		time_of_day: Minutes since midnight (0-1439)
	"""
	var formatted_time = _format_time(time_of_day)
	text = formatted_time


func _format_time(minutes: int) -> String:
	"""Convert minutes since midnight to 12-hour format string.
	
	Args:
		minutes: Minutes since midnight (0-1439)
	
	Returns:
		Formatted time string like "6:00 AM" or "1:30 PM"
	
	Examples:
		- 0 minutes → "12:00 AM" (midnight)
		- 60 minutes → "1:00 AM"
		- 360 minutes → "6:00 AM"
		- 780 minutes → "1:00 PM"
		- 1439 minutes → "11:59 PM"
	"""
	# Calculate 24-hour format
	var hour_24 = int(minutes / 60.0) # 0-23
	var mins = minutes % 60 # 0-59
	
	# Convert to 12-hour format
	var hour_12: int
	var period: String
	
	if hour_24 == 0:
		# Midnight (0:00) → 12:00 AM
		hour_12 = 12
		period = "AM"
	elif hour_24 == 12:
		# Noon (12:00) → 12:00 PM
		hour_12 = 12
		period = "PM"
	elif hour_24 > 12:
		# Afternoon/evening (13:00-23:59) → 1:00 PM - 11:59 PM
		hour_12 = hour_24 - 12
		period = "PM"
	else:
		# Morning (1:00-11:59) → 1:00 AM - 11:59 AM
		hour_12 = hour_24
		period = "AM"
	
	# Format as "H:MM AM/PM" with leading zero for minutes
	return "%d:%02d %s" % [hour_12, mins, period]
