extends Label

## DateLabel - Displays current in-game date
##
## This script subscribes to GameTimeManager.day_changed signal and
## displays the current date in the format "Spring 1, Year 1".
##
## This script is READ-ONLY - it does NOT modify time, day, season, or year.
## It only listens to signals and updates the Label text.

# Season names array - maps season index to display name
const SEASON_NAMES := ["Spring", "Summer", "Fall", "Winter"]


func _ready() -> void:
	"""Initialize date label and connect to GameTimeManager"""
	# Connect to GameTimeManager day_changed signal
	if GameTimeManager:
		if not GameTimeManager.day_changed.is_connected(_on_day_changed):
			GameTimeManager.day_changed.connect(_on_day_changed)
		
		# Immediately display current date so label is correct at startup
		var current_day = GameTimeManager.day
		var current_season = GameTimeManager.season
		var current_year = GameTimeManager.year
		_update_date_text(current_day, current_season, current_year)
	else:
		print("Error: GameTimeManager not found in date_label.gd")


func _on_day_changed(day: int, season: int, year: int) -> void:
	"""Handle day_changed signal from GameTimeManager.
	
	Args:
		day: Day of season (1-28)
		season: Season index (0-3: Spring, Summer, Fall, Winter)
		year: Year number (1+)
	"""
	_update_date_text(day, season, year)


func _update_date_text(day: int, season: int, year: int) -> void:
	"""Update the label text with formatted date string.
	
	Args:
		day: Day of season (1-28)
		season: Season index (0-3)
		year: Year number (1+)
	"""
	# Convert season index to name using array lookup
	var season_name: String
	if season >= 0 and season < SEASON_NAMES.size():
		season_name = SEASON_NAMES[season]
	else:
		# Fallback for invalid season index
		season_name = "Unknown"
	
	# Format as "<Season> <Day>, Year <Year>"
	# Examples: "Spring 1, Year 1" or "Summer 14, Year 2"
	var new_text = "%s %d, Year %d" % [season_name, day, year]
	text = new_text
