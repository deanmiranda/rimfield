extends Node

## TimeTickManager - Drives game time advancement
##
## This singleton advances game time at a Stardew-like pace by calling
## GameTimeManager.advance_time() at regular intervals.
##
## Timing:
## - Advances time by 10 in-game minutes every 7 real seconds
## - Uses a Timer node for clean, event-driven timing
## - Respects pause state (GameTimeManager handles pause internally)

var time_timer: Timer = null


func _ready() -> void:
	"""Initialize the time tick timer"""
	# Verify GameTimeManager exists
	if not GameTimeManager:
		print("Error: GameTimeManager not found! Time will not advance.")
		return
	
	# Create Timer node as child
	time_timer = Timer.new()
	add_child(time_timer)
	
	# Configure timer: 7 seconds per tick, repeating, auto-start
	time_timer.wait_time = 7.0
	time_timer.one_shot = false
	time_timer.autostart = true
	
	# Connect timeout signal to advance time
	if not time_timer.timeout.is_connected(_on_timer_timeout):
		time_timer.timeout.connect(_on_timer_timeout)
	time_timer.start()

func _on_timer_timeout() -> void:
	"""Called every 7 seconds to advance game time by 10 minutes"""
	if GameTimeManager:
		# Advance time by 10 in-game minutes
		# GameTimeManager will handle pause state internally
		GameTimeManager.advance_time(10)
	else:
		print("Error: GameTimeManager not available in time_tick_manager!")
