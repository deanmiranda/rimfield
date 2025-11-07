# interaction_indicator.gd
# Shows a "+" indicator when hovering over pickable items
extends CanvasLayer

var plus_icon: TextureRect = null
var hide_timer: Timer = null
var current_pickable: Node = null
var last_check_time: float = 0.0
const CHECK_INTERVAL: float = 0.05  # Check every 50ms in _process

func _ready() -> void:
	print("DEBUG: InteractionIndicator _ready() called")
	
	# Set layer to be on top
	layer = 100
	
	# Create a Control container for the plus icon (needed for proper positioning in CanvasLayer)
	var control = Control.new()
	control.name = "IndicatorContainer"
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(control)
	print("DEBUG: Control container created and added, layer: ", layer)
	
	# Create the plus icon TextureRect
	plus_icon = TextureRect.new()
	plus_icon.name = "PlusIcon"
	plus_icon.visible = false
	plus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input
	
	# Try to load a plus icon texture, or create a simple colored rect
	var plus_texture = load("res://assets/ui/plus_icon.png")
	if not plus_texture:
		print("DEBUG: Plus icon texture not found, using fallback")
		# Create a simple colored rect as fallback
		plus_icon.modulate = Color(1, 1, 1, 0.8)
		plus_icon.custom_minimum_size = Vector2(32, 32)
		plus_icon.size = Vector2(32, 32)  # Explicit size
	else:
		print("DEBUG: Plus icon texture loaded successfully")
		plus_icon.texture = plus_texture
		plus_icon.custom_minimum_size = Vector2(32, 32)
		plus_icon.size = Vector2(32, 32)  # Explicit size
		plus_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	control.add_child(plus_icon)
	print("DEBUG: Plus icon created and added to control, size: ", plus_icon.size)
	
	# Create a timer to hide the indicator after mouse stops moving
	hide_timer = Timer.new()
	hide_timer.wait_time = 0.2
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(hide_timer)

func _input(event: InputEvent) -> void:
	# React to mouse motion events (use _input instead of _unhandled_input to catch all events)
	if event is InputEventMouseMotion:
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			var world_pos = MouseUtil.get_world_mouse_pos_2d(self)
			# Debug: occasionally print that we're checking
			if randf() < 0.1:  # 10% chance
				print("DEBUG: _input mouse motion detected, mouse_pos: ", mouse_pos, " world_pos: ", world_pos)
			_check_pickable_under_cursor(world_pos, mouse_pos)
		# Reset hide timer
		if hide_timer:
			hide_timer.stop()
			hide_timer.start()

func _process(delta: float) -> void:
	# Also check periodically as a fallback (in case mouse motion events are consumed)
	last_check_time += delta
	if last_check_time >= CHECK_INTERVAL:
		last_check_time = 0.0
		var viewport = get_viewport()
		if viewport:
			var mouse_pos = viewport.get_mouse_position()
			var world_pos = MouseUtil.get_world_mouse_pos_2d(self)
			# Only check if mouse is actually moving (reduce spam)
			if mouse_pos != Vector2.ZERO:
				_check_pickable_under_cursor(world_pos, mouse_pos)

func _check_pickable_under_cursor(world_pos: Vector2, screen_pos: Vector2) -> void:
	# Check if mouse cursor is over any pickable item
	# This should work regardless of player distance - it's a hover indicator
	var pickables = get_tree().get_nodes_in_group("pickable")
	
	# Debug: occasionally print that we're checking
	if randf() < 0.05:  # 5% chance
		print("DEBUG: _check_pickable_under_cursor called, pickables: ", pickables.size(), " mouse_screen: ", screen_pos)
	
	if pickables.size() == 0:
		_hide_indicator()
		return
	
	var found_pickable = null
	var closest_distance = INF
	var viewport = get_viewport()
	var viewport_size = viewport.size if viewport else Vector2.ZERO
	var checked_count = 0
	var skipped_off_screen = 0
	
	# Check each pickable to see if mouse is over it
	for pickable in pickables:
		if not is_instance_valid(pickable):
			continue
		
		if not pickable is Node2D:
			continue
		
		# Convert pickable world position to screen position
		var pickable_world_pos = (pickable as Node2D).global_position
		var pickable_screen_pos = _world_to_screen_position(pickable_world_pos)
		
		checked_count += 1
		
		# Check if pickable is actually visible on screen first
		# Use a very large margin to avoid filtering out pickables that are just slightly off-screen
		if viewport:
			var margin = 500.0  # Large margin to catch pickables near screen edges
			if pickable_screen_pos.x < -margin or pickable_screen_pos.x > viewport_size.x + margin or \
			   pickable_screen_pos.y < -margin or pickable_screen_pos.y > viewport_size.y + margin:
				skipped_off_screen += 1
				# Debug: occasionally print why we're skipping
				if randf() < 0.02:  # 2% chance
					print("DEBUG: Skipping pickable ", pickable.name, " - way off screen. screen_pos: ", pickable_screen_pos, " viewport: ", viewport_size)
				continue
		
		# Check if mouse is over the pickable's visual representation
		var is_over = false
		var distance_to_mouse = screen_pos.distance_to(pickable_screen_pos)
		
		# Debug: print info about on-screen pickables occasionally
		if randf() < 0.01:  # 1% chance per pickable
			print("DEBUG: Checking pickable ", pickable.name, " world: ", pickable_world_pos, " screen: ", pickable_screen_pos, " mouse: ", screen_pos, " distance: ", distance_to_mouse)
		
		# Try to find a Sprite2D to get visual size
		var sprite = pickable.get_node_or_null("Sprite2D")
		if sprite and sprite is Sprite2D:
			# Get sprite's visual size on screen
			var sprite_texture = sprite.texture
			if sprite_texture:
				# Calculate sprite size in screen space (accounting for scale and zoom)
				var camera = viewport.get_camera_2d() if viewport else null
				var zoom = camera.zoom if camera else Vector2.ONE
				
				var sprite_size_world = sprite_texture.get_size() * sprite.scale * (pickable as Node2D).scale
				var sprite_size_screen = sprite_size_world * zoom
				
				# Check if mouse is within sprite bounds (with minimal padding for precise hovering)
				var half_size = sprite_size_screen / 2.0
				var padding = 5.0  # Small padding for easier hovering (reduced from 20)
				var mouse_offset = screen_pos - pickable_screen_pos
				
				if abs(mouse_offset.x) <= half_size.x + padding and abs(mouse_offset.y) <= half_size.y + padding:
					is_over = true
					if distance_to_mouse < closest_distance:
						closest_distance = distance_to_mouse
						found_pickable = pickable
						# Debug: always print when sprite detection works
						print("DEBUG: ✓ Sprite detection! ", pickable.name, " mouse_offset: ", mouse_offset, " half_size: ", half_size, " padding: ", padding)
		
		# Fallback: use distance check if no sprite found or sprite check failed
		if not is_over:
			var hover_radius = 25.0  # Small hover radius for items without sprites (reduced from 100)
			if distance_to_mouse <= hover_radius:
				if distance_to_mouse < closest_distance:
					closest_distance = distance_to_mouse
					found_pickable = pickable
					is_over = true
					# Debug: always print when distance detection works
					print("DEBUG: ✓ Distance detection! ", pickable.name, " distance: ", distance_to_mouse, " radius: ", hover_radius)
	
	# Show indicator at mouse cursor if we found a pickable
	if found_pickable:
		current_pickable = found_pickable
		_show_indicator(screen_pos)
		# Always print when we find one (for debugging)
		var pickable_world_pos = (found_pickable as Node2D).global_position
		var pickable_screen_pos = _world_to_screen_position(pickable_world_pos)
		print("DEBUG: ✓ HOVER DETECTED! Pickable: ", found_pickable.name, " mouse_screen: ", screen_pos, " pickable_screen: ", pickable_screen_pos, " distance: ", screen_pos.distance_to(pickable_screen_pos))
	else:
		# Debug: occasionally print why we didn't find anything
		if randf() < 0.05:  # 5% chance
			print("DEBUG: No pickable found. Checked: ", checked_count, " skipped_off_screen: ", skipped_off_screen, " viewport_size: ", viewport_size)
		_hide_indicator()

func _world_to_screen_position(world_pos: Vector2) -> Vector2:
	# Convert world position to screen position
	var viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	
	var camera = viewport.get_camera_2d()
	if not camera:
		return Vector2.ZERO
	
	# Use the camera's canvas transform which properly converts world to screen
	# This is the transform that the camera uses to render sprites
	var canvas_transform = camera.get_canvas_transform()
	
	# Transform the world position to screen coordinates
	var screen_pos = canvas_transform * world_pos
	
	# Debug occasionally to verify
	if randf() < 0.01:  # 1% chance
		print("DEBUG: World to screen - world: ", world_pos, " screen: ", screen_pos, " camera_pos: ", camera.global_position)
	
	return screen_pos

func _show_indicator(screen_pos: Vector2) -> void:
	if not plus_icon:
		print("DEBUG: ERROR - plus_icon is null!")
		return
	
	# Ensure parent control exists and is visible
	var parent_control = plus_icon.get_parent()
	if not parent_control:
		print("DEBUG: ERROR - parent control is null!")
		return
	
	# Make sure parent is visible
	parent_control.visible = true
	
	# Position near mouse cursor with offset (relative to parent Control)
	# Use screen_pos directly since we're in a CanvasLayer
	plus_icon.position = screen_pos + Vector2(20, 20)  # Offset from cursor
	
	# Ensure the icon is actually on screen
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.size
		# Clamp position to viewport bounds
		plus_icon.position.x = clamp(plus_icon.position.x, 0, viewport_size.x - plus_icon.size.x)
		plus_icon.position.y = clamp(plus_icon.position.y, 0, viewport_size.y - plus_icon.size.y)
	
	# Set z-index to ensure it's on top
	plus_icon.z_index = 1000
	plus_icon.z_as_relative = true
	
	# Make sure icon is visible
	plus_icon.visible = true
	plus_icon.modulate = Color.WHITE  # Ensure full opacity
	
	# Force update
	plus_icon.queue_redraw()
	parent_control.queue_redraw()
	
	# Always print when showing (for debugging)
	print("DEBUG: ✓ SHOWING INDICATOR at screen pos: ", screen_pos, " icon pos: ", plus_icon.position, " visible: ", plus_icon.visible, " size: ", plus_icon.size, " texture: ", plus_icon.texture != null)

func _hide_indicator() -> void:
	if plus_icon:
		plus_icon.visible = false
	current_pickable = null

func _on_hide_timer_timeout() -> void:
	# Hide indicator after mouse stops moving
	_hide_indicator()
