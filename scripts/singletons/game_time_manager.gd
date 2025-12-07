extends Node

## GameTimeManager - Single Source of Truth for Game Time
##
## This singleton manages all game time, day, season, and year state.
## 
## Time Representation:
## - `time_of_day` is stored as minutes since midnight (0-1439)
## - One in-game day = 1440 minutes (24 hours * 60 minutes)
## - Days are numbered 1-28 per season
## - Seasons are numbered 0-3 (Spring, Summer, Fall, Winter)
## - Years start at 1 and increment indefinitely
##
## This class is PURE LOGIC - no UI, lighting, or scene references.
## Other systems listen to signals and react accordingly.

# Time constants
const MINUTES_PER_DAY := 1440
const START_TIME_MINUTES := 6 * 60 # 6:00 AM
const MIDNIGHT_MINUTES := 0 # 00:00
const PASS_OUT_MINUTES := 2 * 60 # 2:00 AM

# Calendar constants
const DAYS_PER_SEASON := 28
const SEASONS_PER_YEAR := 4

# State variables
var time_of_day: int = START_TIME_MINUTES # Minutes since midnight (0-1439)
var day: int = 1 # Day of season (1-28)
var season: int = 0 # Season of year (0-3: Spring, Summer, Fall, Winter)
var year: int = 1 # Year number (starts at 1)
var game_paused: bool = false

# Internal flags to prevent duplicate signal emissions
var has_triggered_midnight_warning_today: bool = false
var has_triggered_pass_out_today: bool = false

# Signals
signal time_changed(time_of_day: int)
signal day_changed(day: int, season: int, year: int)
signal midnight_warning()
signal pass_out()


func _ready() -> void:
	"""Initialize time system to default starting values"""
	time_of_day = START_TIME_MINUTES
	day = 1
	season = 0
	year = 1
	game_paused = false
	
	# Reset per-day flags
	has_triggered_midnight_warning_today = false
	has_triggered_pass_out_today = false
	
	# Emit initial signals so UI/listeners can sync
	time_changed.emit(time_of_day)
	day_changed.emit(day, season, year)


func set_paused(paused: bool) -> void:
	"""Set the game paused state. When paused, time does not advance."""
	game_paused = paused


func advance_time(minutes: int) -> void:
	"""Advance game time by the specified number of minutes.
	
	Handles:
	- Day rollover (when time exceeds 24 hours)
	- Season rollover (when day exceeds 28)
	- Year rollover (when season exceeds 3)
	- Midnight warning signal (when crossing midnight)
	- Pass-out signal (when reaching 2:00 AM)
	
	Args:
		minutes: Number of minutes to advance (must be > 0)
	"""
	# Do nothing if minutes is invalid or game is paused
	if minutes <= 0:
		return
	
	if game_paused:
		return
	
	# Store previous time for midnight detection
	var previous_time = time_of_day
	
	# Add minutes to current time
	time_of_day += minutes
	
	# Handle day rollover and day/season/year progression
	var days_advanced = 0
	while time_of_day >= MINUTES_PER_DAY:
		time_of_day -= MINUTES_PER_DAY
		days_advanced += 1
		day += 1
		
		# Reset per-day flags when a new day starts
		has_triggered_midnight_warning_today = false
		has_triggered_pass_out_today = false
		
		# Handle season rollover
		if day > DAYS_PER_SEASON:
			day = 1
			season += 1
			
			# Handle year rollover
			if season >= SEASONS_PER_YEAR:
				season = 0
				year += 1
		
		# Emit day_changed signal for each day that passes
		day_changed.emit(day, season, year)
	
	# Check for midnight warning (crossing from before midnight to at/after midnight)
	# This handles both same-day midnight crossing and day rollover cases
	if not has_triggered_midnight_warning_today:
		# Case 1: Normal midnight crossing (previous_time < MIDNIGHT, new_time >= MIDNIGHT)
		# Case 2: Day rollover (previous_time was late in day, rolled over to new day)
		if (previous_time < MINUTES_PER_DAY and time_of_day >= MIDNIGHT_MINUTES) or days_advanced > 0:
			# Only trigger if we're actually at or past midnight now
			if time_of_day >= MIDNIGHT_MINUTES:
				has_triggered_midnight_warning_today = true
				midnight_warning.emit()
	
	# Check for pass-out (reaching 2:00 AM)
	# Only check if we haven't already passed out today
	if not has_triggered_pass_out_today:
		# Check if we've reached or passed 2:00 AM
		# Handle both same-day progression and day rollover cases
		var reached_pass_out = false
		
		if days_advanced > 0:
			# Day rolled over - check if we're now at/past 2 AM
			reached_pass_out = (time_of_day >= PASS_OUT_MINUTES)
		else:
			# Same day - check if we crossed the 2 AM threshold
			reached_pass_out = (previous_time < PASS_OUT_MINUTES and time_of_day >= PASS_OUT_MINUTES)
		
		if reached_pass_out:
			has_triggered_pass_out_today = true
			pass_out.emit()
	
	# Emit time_changed signal after all adjustments
	time_changed.emit(time_of_day)


func sleep_to_next_morning() -> void:
	"""Advance the calendar by one day and reset time to morning.
	
	This method is called when the player sleeps in bed or passes out.
	It advances the day by exactly one, handles season/year rollover,
	resets time to START_TIME_MINUTES (6:00 AM), and resets per-day flags.
	
	This method does NOT handle player movement, screen fading, or input.
	Those are handled by the calling system (bed interaction, pass-out sequence).
	"""
	
	# Store previous values for logging
	var old_day = day
	var old_season = season
	var old_year = year
	
	# Advance day by 1
	day += 1
	
	# Handle season rollover
	if day > DAYS_PER_SEASON:
		day = 1
		season += 1
		
		# Handle year rollover
		if season >= SEASONS_PER_YEAR:
			season = 0
			year += 1
	
	# Log day change
	if day != old_day or season != old_season or year != old_year:
		print("GameTimeManager: Day changed - Day: ", old_day, " -> ", day, ", Season: ", old_season, " -> ", season, ", Year: ", old_year, " -> ", year)
	
	# Reset time to morning (6:00 AM)
	time_of_day = START_TIME_MINUTES
	
	# Reset per-day flags for the new day
	has_triggered_midnight_warning_today = false
	has_triggered_pass_out_today = false
	
	# Emit signals so UI/listeners can sync
	day_changed.emit(day, season, year)
	time_changed.emit(time_of_day)


func get_absolute_day() -> int:
	"""Get absolute day number (days since game start, accounting for years and seasons)
	
	This provides a consistent day count that can be used for comparisons across
	season and year boundaries. Useful for tracking crop growth, watering, etc.
	
	Formula: (year - 1) * 112 + season * 28 + day
	Where 112 = 4 seasons * 28 days per season
	
	Returns:
		Absolute day number (starts at 1 for Spring 1, Year 1)
	"""
	return (year - 1) * 112 + season * 28 + day


func get_date_string() -> String:
	"""Get formatted date string in format "Spring 1, Year 1"
	
	Returns:
		Formatted date string
	"""
	var season_names := ["Spring", "Summer", "Fall", "Winter"]
	var season_name: String
	if season >= 0 and season < season_names.size():
		season_name = season_names[season]
	else:
		season_name = "Unknown"
	
	return "%s %d, Year %d" % [season_name, day, year]


func _format_time_for_log(minutes: int) -> String:
	"""Helper to format time for logging"""
	var hours = int(minutes / 60.0)
	var mins = minutes % 60
	return "%02d:%02d" % [hours, mins]


func save_state() -> Dictionary:
	"""Save current time state to a dictionary for serialization.
	
	Returns:
		Dictionary containing time_of_day, day, season, and year
	"""
	return {
		"time_of_day": time_of_day,
		"day": day,
		"season": season,
		"year": year
	}


func load_state(state: Dictionary) -> void:
	"""Load time state from a dictionary.
	
	Args:
		state: Dictionary containing time_of_day, day, season, and year
	"""
	# Safely load values with defaults if keys are missing
	if "time_of_day" in state:
		var loaded_time = state["time_of_day"]
		if loaded_time is int and loaded_time >= 0 and loaded_time < MINUTES_PER_DAY:
			time_of_day = loaded_time
		else:
			time_of_day = START_TIME_MINUTES
	
	if "day" in state:
		var loaded_day = state["day"]
		if loaded_day is int and loaded_day >= 1 and loaded_day <= DAYS_PER_SEASON:
			day = loaded_day
		else:
			day = 1
	
	if "season" in state:
		var loaded_season = state["season"]
		if loaded_season is int and loaded_season >= 0 and loaded_season < SEASONS_PER_YEAR:
			season = loaded_season
		else:
			season = 0
	
	if "year" in state:
		var loaded_year = state["year"]
		if loaded_year is int and loaded_year >= 1:
			year = loaded_year
		else:
			year = 1
	
	# Reset per-day flags based on loaded time
	# If time is already past midnight, consider midnight warning already triggered
	has_triggered_midnight_warning_today = (time_of_day >= MIDNIGHT_MINUTES)
	
	# If time is already past 2 AM, consider pass-out already triggered
	has_triggered_pass_out_today = (time_of_day >= PASS_OUT_MINUTES)
	
	# Emit signals so UI/listeners can sync with loaded state
	time_changed.emit(time_of_day)
	day_changed.emit(day, season, year)
