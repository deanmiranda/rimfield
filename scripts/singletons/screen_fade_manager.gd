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
	
	# Set high layer to be on top
	layer = 1000
	
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


func fade_out(callback: Callable = Callable()) -> void:
	"""Fade screen to black
	
	Args:
		callback: Optional callback to call when fade completes
	"""
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
	_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	
	if callback.is_valid():
		_tween.tween_callback(callback)
	else:
		await _tween.finished


func fade_in(callback: Callable = Callable()) -> void:
	"""Fade screen from black to clear
	
	Args:
		callback: Optional callback to call when fade completes
	"""
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
	_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
	
	if callback.is_valid():
		_tween.tween_callback(callback)
	else:
		await _tween.finished
