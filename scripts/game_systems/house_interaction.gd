extends Area2D

const HOUSE_SCENE_PATH = "res://scenes/world/house_scene.tscn"
const HOUSE_SPAWN_POSITION = Vector2(-8, 54)  # Inside house, far from exit

var player: Node = null  # Reference to the player
var player_in_zone: bool = false  # Tracks if the player is in the zone
var is_transitioning: bool = false  # Prevent multiple transitions

# Screen-space label (not affected by camera zoom)
var tooltip_canvas: CanvasLayer = null
var interaction_label: Label = null


func _ready() -> void:
	_setup_screen_space_tooltip()
	_configure_interaction_label()


func _exit_tree() -> void:
	"""Clean up CanvasLayer when Area2D is removed"""
	if tooltip_canvas:
		tooltip_canvas.queue_free()
		tooltip_canvas = null


func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player using type or class name
	if body is CharacterBody2D and body.has_method("start_interaction"):
		if interaction_label:
			interaction_label.visible = true
		player = body  # Store reference to the player
		player_in_zone = true  # Set player_in_zone to true
		# Notify the player
		player.start_interaction("house")


func _on_body_exited(body: Node2D) -> void:
	# Check if the body is the player
	if body == player:
		if interaction_label:
			interaction_label.visible = false
		player_in_zone = false  # Set player_in_zone to false
		is_transitioning = false  # Reset transition flag
		# Notify the player
		if player.has_method("stop_interaction"):
			player.stop_interaction()
		player = null  # Clear the player reference


func _input(event: InputEvent) -> void:
	# Use _input() instead of _process() polling (follows .cursor/rules/godot.md)
	if player_in_zone and event.is_action_pressed("ui_interact") and not is_transitioning:
		is_transitioning = true
		SceneManager.change_scene(HOUSE_SCENE_PATH, HOUSE_SPAWN_POSITION)
		# Only handle input if viewport is available (may be null during scene transitions)
		var viewport = get_viewport()
		if viewport:
			viewport.set_input_as_handled()  # Prevent further processing


func _setup_screen_space_tooltip() -> void:
	"""Create a CanvasLayer-based tooltip that's not affected by camera zoom"""
	# Create CanvasLayer for screen-space rendering
	tooltip_canvas = CanvasLayer.new()
	tooltip_canvas.name = "HouseTooltipCanvas"
	tooltip_canvas.layer = 99  # Below interaction_indicator (100) but above most UI
	tooltip_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(tooltip_canvas)

	# Create Control container
	var control = Control.new()
	control.name = "TooltipContainer"
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	tooltip_canvas.add_child(control)

	# Create label
	interaction_label = Label.new()
	interaction_label.name = "TooltipLabel"
	interaction_label.visible = false
	control.add_child(interaction_label)


func _process(_delta: float) -> void:
	"""Update tooltip position in screen space"""
	if not interaction_label or not interaction_label.visible:
		return

	# Convert house door world position to screen position
	var door_world_pos = global_position + Vector2(0, 1)  # Door is at y=1 relative to Area2D
	var screen_pos = _world_to_screen_position(door_world_pos)

	# Position label above door in screen space
	interaction_label.position = screen_pos + Vector2(0, -36)


func _world_to_screen_position(world_pos: Vector2) -> Vector2:
	"""Convert world position to screen position (same as interaction_indicator)"""
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


func _configure_interaction_label() -> void:
	"""Configure the interaction label to match the fruit hover text style"""
	if not interaction_label:
		return

	# Match the fruit hover text configuration exactly (font size 14, crisp in screen space)
	interaction_label.add_theme_font_size_override("font_size", 14)
	interaction_label.add_theme_color_override("font_color", Color.WHITE)
	interaction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	interaction_label.add_theme_constant_override("outline_size", 2)
	interaction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Set text and alignment
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.text = "Press E to Enter"
