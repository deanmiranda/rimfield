extends CanvasLayer

## ScreenFadeManager - Handles screen fade transitions for sleep sequence
##
## Provides fade_out() and fade_in() methods with callback support.
## Uses a ColorRect overlay to fade the screen to/from black.

var fade_rect: ColorRect = null
var _tween: Tween = null


func _ready() -> void:
	"""Initialize fade manager"""
	# Ensure this runs even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set layer below date popup (50) so popup at layer 200 draws above it
	layer = 50
	follow_viewport_enabled = false
	
	# Create fade rect
	fade_rect = ColorRect.new()
	fade_rect.name = "ColorRect"
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	
	# Set to fullscreen
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.offset_left = 0
	fade_rect.offset_top = 0
	fade_rect.offset_right = 0
	fade_rect.offset_bottom = 0
	
	# Start transparent
	fade_rect.modulate.a = 0.0


func fade_out(callback: Callable = Callable(), duration: float = 2.0) -> void:
	"""Fade screen to black
	
	Args:
		callback: Optional callback to call when fade completes
		duration: Duration of fade in seconds (default: 2.0)
	"""
	print("ScreenFadeManager: Fade out started (duration: ", duration, "s)")
	if not fade_rect:
		if callback.is_valid():
			callback.call()
		return
	
	# Kill existing tween
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create new tween
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	
	if callback.is_valid():
		_tween.tween_callback(func():
			print("ScreenFadeManager: Fade out complete")
			callback.call()
		)
	else:
		await _tween.finished
		print("ScreenFadeManager: Fade out complete")


func fade_in(callback: Callable = Callable(), duration: float = 2.0) -> void:
	"""Fade screen from black to clear
	
	Args:
		callback: Optional callback to call when fade completes
		duration: Duration of fade in seconds (default: 2.0)
	"""
	print("ScreenFadeManager: Fade in started (duration: ", duration, "s)")
	if not fade_rect:
		if callback.is_valid():
			callback.call()
		return
	
	# Kill existing tween
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create new tween
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	
	if callback.is_valid():
		_tween.tween_callback(func():
			print("ScreenFadeManager: Fade in complete")
			callback.call()
		)
	else:
		await _tween.finished
		print("ScreenFadeManager: Fade in complete")


func fade_out_and_hold(fadeout_seconds: float, hold_seconds: float, callback: Callable) -> void:
	"""Fade out to black, hold at black, then call callback (does NOT fade in automatically)
	
	Args:
		fadeout_seconds: Duration of fade out in seconds
		hold_seconds: Duration to hold at full black in seconds
		callback: Callback called after hold period completes (before fade-in)
	"""
	print("ScreenFadeManager: fade_out_and_hold() called - fade_out: ", fadeout_seconds, "s, hold: ", hold_seconds, "s")
	
	if not fade_rect:
		if callback.is_valid():
			callback.call()
		return
	
	# Kill existing tween
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create new tween
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Phase 1: Fade out
	print("ScreenFadeManager: Phase 1 - Fade out started")
	_tween.tween_property(fade_rect, "modulate:a", 1.0, fadeout_seconds)
	_tween.tween_callback(func():
		print("ScreenFadeManager: Phase 1 - Fade out complete")
	)
	
	# Phase 2: Hold at black
	print("ScreenFadeManager: Phase 2 - Hold period started (duration: ", hold_seconds, "s)")
	_tween.tween_interval(hold_seconds)
	_tween.tween_callback(func():
		print("ScreenFadeManager: Phase 2 - Hold period complete, calling callback")
		if callback.is_valid():
			callback.call()
	)


func fade_out_with_hold(
	fade_out_duration: float = 2.0,
	hold_duration: float = 2.0,
	fade_in_duration: float = 2.0,
	hold_callback: Callable = Callable(),
	complete_callback: Callable = Callable()
) -> void:
	"""Fade out, hold at black, then fade in (Stardew Valley style)
	
	Args:
		fade_out_duration: Duration of fade out in seconds (default: 2.0)
		hold_duration: Duration to hold at full black in seconds (default: 2.0)
		fade_in_duration: Duration of fade in in seconds (default: 2.0)
		hold_callback: Callback called during hold period (for date label update)
		complete_callback: Callback called when fade in completes
	"""
	print("ScreenFadeManager: fade_out_with_hold() called - fade_out: ", fade_out_duration, "s, hold: ", hold_duration, "s, fade_in: ", fade_in_duration, "s")
	
	if not fade_rect:
		if hold_callback.is_valid():
			hold_callback.call()
		if complete_callback.is_valid():
			complete_callback.call()
		return
	
	# Kill existing tween
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Create new tween
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Phase 1: Fade out
	print("ScreenFadeManager: Phase 1 - Fade out started")
	_tween.tween_property(fade_rect, "modulate:a", 1.0, fade_out_duration)
	_tween.tween_callback(func():
		print("ScreenFadeManager: Phase 1 - Fade out complete")
	)
	
	# Phase 2: Hold at black (run hold_callback during hold)
	print("ScreenFadeManager: Hold interval starting, duration = ", hold_duration)
	if hold_callback.is_valid():
		_tween.tween_callback(hold_callback)
	_tween.tween_interval(hold_duration)
	_tween.tween_callback(func():
		print("ScreenFadeManager: Phase 2 - Hold period complete")
	)
	
	# Phase 3: Fade in
	_tween.tween_callback(func():
		print("ScreenFadeManager: Phase 3 - Fade in started")
	)
	_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_in_duration)
	_tween.tween_callback(func():
		print("ScreenFadeManager: Phase 3 - Fade in complete")
		if complete_callback.is_valid():
			complete_callback.call()
	)
