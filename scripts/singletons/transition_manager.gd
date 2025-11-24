extends CanvasLayer

# Fade transition manager for scene changes
var fade_rect: ColorRect = null
var current_tween: Tween = null


func _ready() -> void:
	# Ensure this runs even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create fullscreen black rect for fading
	fade_rect = ColorRect.new()
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

	# Ensure this layer is on top of everything
	layer = 1000

func fade_to_black(duration: float = 0.3) -> void:
	"""Fade screen to black"""
	if not fade_rect:
		print("ERROR: fade_rect is null!")
		return

	# Kill existing tween
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	fade_rect.modulate.a = 0.0 # Start from transparent
	current_tween = create_tween()
	current_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	await current_tween.finished

func fade_from_black(duration: float = 0.3) -> void:
	"""Fade screen from black to clear"""
	if not fade_rect:
		print("ERROR: fade_rect is null!")
		return

	# Kill existing tween
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	fade_rect.modulate.a = 1.0 # Start from black
	current_tween = create_tween()
	current_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	await current_tween.finished


func fade_transition(duration: float = 0.3) -> void:
	"""Complete fade out and back in"""
	await fade_to_black(duration)
	await fade_from_black(duration)
