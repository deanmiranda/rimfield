# interaction_indicator.gd
# Shows a "+" indicator when hovering over pickable items
extends CanvasLayer

var plus_icon: TextureRect = null
var tooltip_label: Label = null
var hide_timer: Timer = null
var current_pickable: Node = null
var last_check_time: float = 0.0
var tooltip_tween: Tween = null
var was_nearby_last_frame: bool = false  # Track if item was nearby last frame
const CHECK_INTERVAL: float = 0.05  # Check every 50ms in _process

# Interaction radius for enabling the icon (default 64px, can be overridden)
@export var interaction_radius: float = 64.0

# Color settings for enabled/disabled states
var disabled_modulate := Color(0.5, 0.5, 0.5, 0.7)  # Grayed out
var enabled_modulate := Color(1.0, 1.0, 1.0, 1.0)   # Normal white

func _ready() -> void:
	# Set layer to be on top
	layer = 100
	
	# Create a Control container for the plus icon (needed for proper positioning in CanvasLayer)
	var control = Control.new()
	control.name = "IndicatorContainer"
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(control)
	
	# Create the plus icon TextureRect
	plus_icon = TextureRect.new()
	plus_icon.name = "PlusIcon"
	plus_icon.visible = false
	plus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input
	
	# Load plus icon texture
	var plus_texture = load("res://assets/ui/plus_icon.png")
	if plus_texture:
		plus_icon.texture = plus_texture
		plus_icon.custom_minimum_size = Vector2(32, 32)
		plus_icon.size = Vector2(32, 32)
		plus_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	else:
		# Fallback if texture not found
		plus_icon.custom_minimum_size = Vector2(32, 32)
		plus_icon.size = Vector2(32, 32)
	
	# Start with disabled (grayed out) state
	plus_icon.modulate = disabled_modulate
	
	control.add_child(plus_icon)
	
	# Create tooltip label
	tooltip_label = Label.new()
	tooltip_label.name = "TooltipLabel"
	tooltip_label.text = "Press E to collect"
	tooltip_label.visible = false
	tooltip_label.modulate = Color(1, 1, 1, 0)  # Start invisible
	tooltip_label.add_theme_font_size_override("font_size", 14)
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tooltip_label.add_theme_constant_override("outline_size", 2)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(tooltip_label)
	
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
			_check_pickable_under_cursor(world_pos, mouse_pos)
		# Reset hide timer
		if hide_timer:
			hide_timer.stop()
			hide_timer.start()

func _process(delta: float) -> void:
	# Continuously update indicator state if icon is visible
	# This ensures the icon updates in real-time as player moves
	if plus_icon and plus_icon.visible and current_pickable:
		_update_indicator_state()
		
		# Check if item was collected (was nearby but no longer valid)
		if was_nearby_last_frame:
			if not is_instance_valid(current_pickable):
				# Item was collected and freed
				_on_item_collected()
	
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

func _check_pickable_under_cursor(_world_pos: Vector2, screen_pos: Vector2) -> void:
	# Check if mouse cursor is over any pickable item
	# This should work regardless of player distance - it's a hover indicator
	var pickables = get_tree().get_nodes_in_group("pickable")
	
	if pickables.size() == 0:
		_hide_indicator()
		return
	
	var found_pickable = null
	var closest_distance = INF
	var viewport = get_viewport()
	var viewport_size = viewport.size if viewport else Vector2.ZERO
	
	# Check each pickable to see if mouse is over it
	for pickable in pickables:
		if not is_instance_valid(pickable):
			continue
		
		if not pickable is Node2D:
			continue
		
		# Convert pickable world position to screen position
		var pickable_world_pos = (pickable as Node2D).global_position
		var pickable_screen_pos = _world_to_screen_position(pickable_world_pos)
		
		# Check if pickable is actually visible on screen first
		if viewport:
			var margin = 500.0  # Large margin to catch pickables near screen edges
			if pickable_screen_pos.x < -margin or pickable_screen_pos.x > viewport_size.x + margin or \
			   pickable_screen_pos.y < -margin or pickable_screen_pos.y > viewport_size.y + margin:
				continue
		
		# Check if mouse is over the pickable's visual representation
		var is_over = false
		var distance_to_mouse = screen_pos.distance_to(pickable_screen_pos)
		
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
		
		# Fallback: use distance check if no sprite found or sprite check failed
		if not is_over:
			var hover_radius = 25.0  # Small hover radius for items without sprites
			if distance_to_mouse <= hover_radius:
				if distance_to_mouse < closest_distance:
					closest_distance = distance_to_mouse
					found_pickable = pickable
					is_over = true
	
	# Show indicator at mouse cursor if we found a pickable
	if found_pickable:
		# If switching to a different pickable, reset state tracking
		var is_new_pickable = (current_pickable != found_pickable)
		if is_new_pickable:
			was_nearby_last_frame = false  # Reset to force state update
		current_pickable = found_pickable
		_show_indicator(screen_pos)
		# Immediately update state for new item
		_update_indicator_state()
	else:
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
	var canvas_transform = camera.get_canvas_transform()
	var screen_pos = canvas_transform * world_pos
	
	return screen_pos

func _show_indicator(screen_pos: Vector2) -> void:
	if not plus_icon or not tooltip_label:
		return
	
	# Ensure parent control exists and is visible
	var parent_control = plus_icon.get_parent()
	if not parent_control:
		return
	
	parent_control.visible = true
	
	# Position icon near mouse cursor with offset
	plus_icon.position = screen_pos + Vector2(20, 20)
	
	# Ensure the icon is actually on screen
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.size
		plus_icon.position.x = clamp(plus_icon.position.x, 0, viewport_size.x - plus_icon.size.x)
		plus_icon.position.y = clamp(plus_icon.position.y, 0, viewport_size.y - plus_icon.size.y)
	
	# Position tooltip below icon
	tooltip_label.position = plus_icon.position + Vector2(0, plus_icon.size.y + 5)
	if viewport:
		var viewport_size = viewport.size
		tooltip_label.position.x = clamp(tooltip_label.position.x, 0, viewport_size.x - tooltip_label.size.x)
	
	# Set z-index to ensure it's on top
	plus_icon.z_index = 1000
	plus_icon.z_as_relative = true
	tooltip_label.z_index = 1001
	tooltip_label.z_as_relative = true
	
	# Make icon visible (starts disabled/grayed out)
	plus_icon.visible = true
	plus_icon.modulate = disabled_modulate  # Start disabled
	
	# Update state based on player proximity
	_update_indicator_state()
	
	# Force update
	plus_icon.queue_redraw()
	parent_control.queue_redraw()

func _update_indicator_state() -> void:
	# Check if player is close enough to interact with current_pickable
	if not current_pickable or not is_instance_valid(current_pickable):
		return
	
	if not plus_icon:
		return
	
	# Try multiple methods to find the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Player")
		if not player:
			var scene = get_tree().current_scene
			if scene:
				for child in scene.get_children():
					if child is CharacterBody2D and "nearby_pickables" in child:
						player = child
						break
	
	if not player or not (player is Node2D):
		# No player found - keep disabled state
		plus_icon.modulate = disabled_modulate
		_hide_tooltip()
		was_nearby_last_frame = false
		return
	
	var is_nearby = false
	
	# Primary method: Direct distance check (most reliable)
	if current_pickable is Node2D:
		var player_pos = (player as Node2D).global_position
		var pickable_pos = (current_pickable as Node2D).global_position
		var distance = player_pos.distance_to(pickable_pos)
		
		# Use player's pickup_radius if available, otherwise use interaction_radius
		var radius = interaction_radius
		if "pickup_radius" in player:
			radius = player.pickup_radius
		
		if distance <= radius:
			is_nearby = true
	
	# Secondary method: Verify with nearby_pickables array (if distance check didn't find it)
	# This helps catch edge cases where distance might be slightly off
	if not is_nearby and "nearby_pickables" in player and current_pickable:
		# Try multiple comparison methods since node references might differ
		for nearby_item in player.nearby_pickables:
			if not is_instance_valid(nearby_item):
				continue
			# Check by reference first
			if nearby_item == current_pickable:
				is_nearby = true
				break
			# Check by instance ID as fallback
			if nearby_item.get_instance_id() == current_pickable.get_instance_id():
				is_nearby = true
				break
			# Check by scene path as another fallback
			if nearby_item.get_path() == current_pickable.get_path():
				is_nearby = true
				break
	
	# Update icon appearance based on proximity
	var state_changed = (is_nearby != was_nearby_last_frame)
	
	if is_nearby:
		# Player is close - show enabled icon and tooltip
		plus_icon.modulate = enabled_modulate
		# Only show tooltip if state changed (wasn't nearby before)
		if state_changed:
			_show_tooltip()
		was_nearby_last_frame = true
	else:
		# Player is far - show disabled icon, hide tooltip
		plus_icon.modulate = disabled_modulate
		# Only hide tooltip if state changed (was nearby before)
		if state_changed:
			_hide_tooltip()
		was_nearby_last_frame = false

func _hide_indicator() -> void:
	if plus_icon:
		plus_icon.visible = false
	_hide_tooltip()
	current_pickable = null
	was_nearby_last_frame = false

func _show_tooltip() -> void:
	if not tooltip_label:
		return
	
	tooltip_label.visible = true
	
	# Stop any existing tween
	if tooltip_tween:
		tooltip_tween.kill()
	
	# Fade in tooltip
	tooltip_tween = create_tween()
	tooltip_tween.tween_property(tooltip_label, "modulate:a", 1.0, 0.2)

func _hide_tooltip() -> void:
	if not tooltip_label:
		return
	
	# Stop any existing tween
	if tooltip_tween:
		tooltip_tween.kill()
	
	# Fade out tooltip
	tooltip_tween = create_tween()
	tooltip_tween.tween_property(tooltip_label, "modulate:a", 0.0, 0.2)
	tooltip_tween.tween_callback(func(): tooltip_label.visible = false)

func _on_hide_timer_timeout() -> void:
	# Hide indicator after mouse stops moving
	_hide_indicator()

func _on_item_collected() -> void:
	# Called when an item is collected - fade out tooltip
	if current_pickable:
		_hide_tooltip()
		# Hide icon after a brief delay
		if tooltip_tween:
			tooltip_tween.kill()
		tooltip_tween = create_tween()
		tooltip_tween.tween_delay(0.5)
		tooltip_tween.tween_callback(_hide_indicator)
