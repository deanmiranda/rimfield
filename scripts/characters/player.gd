# player.gd
# Handles basic player movements.

extends CharacterBody2D

# Use GameConfig Resource instead of magic number (follows .cursor/rules/godot.md)
var game_config: Resource = null
var speed: float = 200 # Default (will be overridden by GameConfig)
var direction: Vector2 = Vector2.ZERO # Tracks input direction
var interactable: Node = null # Stores the interactable object the player is near
var farming_manager: Node = null # Reference to the farming system
var current_interaction: String = "" # Track the current interaction

# Interaction system - signal-based sets (no polling)
var nearby_pickables: Array = [] # Array of nearby pickable items
var pickup_radius: float = 48.0 # Default (will be overridden by GameConfig)

@onready var inventory_manager = InventoryManager # Singleton reference
@onready var sprite = $AnimatedSprite2D # Reference to AnimatedSprite2D node
@onready var interaction_area: Area2D = null # Will be created in _ready


func _ready() -> void:
	# Load GameConfig Resource
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		speed = game_config.player_speed
		pickup_radius = game_config.pickup_radius

	# Create interaction Area2D for detecting nearby pickables
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.monitorable = false # This area detects, doesn't need to be detected
	interaction_area.monitoring = true # Enable monitoring
	interaction_area.collision_mask = 2 # Detect items on collision layer 2
	add_child(interaction_area)

	# Create collision shape for interaction radius
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = pickup_radius
	collision_shape.shape = circle_shape
	interaction_area.add_child(collision_shape)

	# Connect signals for tracking nearby pickables
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	interaction_area.area_entered.connect(_on_interaction_area_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_area_exited)

	# Locate farming system if in the farm scene
	var farm_scene = get_tree().current_scene

	if farm_scene and farm_scene.has_node("FarmingManager"):
		farming_manager = farm_scene.get_node("FarmingManager")
	else:
		# Fallback: try to find FarmingManager via scene tree search
		var farming_managers = get_tree().get_nodes_in_group("farming_manager")
		if farming_managers.size() > 0:
			farming_manager = farming_managers[0]
		else:
			# Try to find it as a child of current scene
			if farm_scene:
				var found_manager = farm_scene.find_child("FarmingManager", true, false)
				if found_manager:
					farming_manager = found_manager
				else:
					farming_manager = null
			else:
				farming_manager = null


func _physics_process(_delta: float) -> void:
	# Reset direction
	direction = Vector2.ZERO

	# Handle input for movement
	direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))

	# Normalize direction for diagonal movement
	if direction.length() > 1:
		direction = direction.normalized()

	# Update velocity based on direction and speed
	velocity = direction * speed

	# Apply movement using built-in move_and_slide()
	move_and_slide()

	# Update animation direction and state
	_update_animation(direction)


func _update_animation(input_direction: Vector2) -> void:
	if input_direction == Vector2.ZERO:
		if sprite.animation.begins_with("walk_"):
			var idle_animation = "stand_" + sprite.animation.substr(5)
			sprite.play(idle_animation)
	else:
		if input_direction.x > 0:
			sprite.play("walk_right")
		elif input_direction.x < 0:
			sprite.play("walk_left")
		elif input_direction.y > 0:
			sprite.play("walk_down")
		elif input_direction.y < 0:
			sprite.play("walk_up")


func _input(event: InputEvent) -> void:
	# CRITICAL: Don't process farming interactions here - moved to _unhandled_input()
	# This ensures UI elements (toolkit, inventory) get priority and can handle clicks first
	# Only check for dragging state to prevent conflicts
	if event.is_action_pressed("ui_mouse_left") and not event.is_echo():
		# CRITICAL: Don't trigger tool actions if player is dragging an item
		# Check if any toolkit or inventory slot is currently dragging
		if _is_any_slot_dragging():
			# Don't mark as handled - let UI handle it if needed
			return # Block tool action when dragging


func _unhandled_input(event: InputEvent) -> void:
	# CRITICAL: _unhandled_input() is called AFTER UI elements have had a chance to handle input
	# This ensures UI elements (toolkit, inventory) get priority over world interactions
	# Handle left-click for farming interactions (only if not handled by UI)
	if event.is_action_pressed("ui_mouse_left") and not event.is_echo():
		# CRITICAL: Don't trigger tool actions if player is dragging an item
		if _is_any_slot_dragging():
			return # Block tool action when dragging
		
		# Only process farming if UI didn't handle the click
		if farming_manager:
			var mouse_pos = MouseUtil.get_world_mouse_pos_2d(self)
			# Let farming_manager handle the interaction
			# CRITICAL: This should only be called once per click, not every frame
			farming_manager.interact_with_tile(mouse_pos, global_position)
	
	# REMOVED: Direct tool shortcuts that bypass ToolSwitcher
	# Tools are now managed entirely by ToolSwitcher based on slot selection
	# Keyboard shortcuts (1-0) select slots via ToolSwitcher, which then updates farming_manager
	# This ensures tools are tied to tool textures, not slot positions
	# Handle E key for door interactions (house entrance)
	if event.is_action_pressed("ui_interact"):
		if current_interaction == "house":
			# Door interaction is handled by house_interaction.gd
			# This is just a fallback - door should handle its own input
			pass

	# Handle right-click for item pickup (vegetables, dropped items)
	# Note: This won't conflict with toolkit right-click drag because UI elements
	# capture input first. If right-click is over a toolkit slot, it won't reach here.
	if event is InputEventMouseButton:
		if event.button_index == 2 and event.pressed: # MOUSE_BUTTON_RIGHT = 2
			# Right-click to pick up nearby items
			if nearby_pickables.size() > 0:
				_pickup_nearest_item()


func _is_any_slot_dragging() -> bool:
	"""Check if any toolkit or inventory slot is currently dragging an item"""
	# Check toolkit slots
	var hud = get_tree().root.get_node_or_null("Hud")
	if not hud:
		# Try alternative path
		hud = get_tree().current_scene.get_node_or_null("Hud")
	
	if hud:
		# CRITICAL: HUD structure is Hud (Node) -> HUD (CanvasLayer) -> MarginContainer -> HBoxContainer
		var hud_canvas = hud.get_node_or_null("HUD")
		if hud_canvas:
			var margin_container = hud_canvas.get_node_or_null("MarginContainer")
			if margin_container:
				var toolkit_container = margin_container.get_node_or_null("HBoxContainer")
				if toolkit_container:
					for i in range(toolkit_container.get_child_count()):
						var slot = toolkit_container.get_child(i)
						if slot and slot is TextureButton:
							if "is_dragging" in slot and slot.is_dragging:
								return true
	
	# Check inventory slots (only if pause menu is visible)
	var pause_menu = null
	if UiManager and "pause_menu" in UiManager:
		pause_menu = UiManager.pause_menu
	
	if pause_menu and pause_menu.visible:
		var inventory_grid = pause_menu.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid"
		)
		if inventory_grid:
			for i in range(inventory_grid.get_child_count()):
				var slot = inventory_grid.get_child(i)
				if slot and slot is TextureButton:
					if "is_dragging" in slot and slot.is_dragging:
						return true
	
	return false


func _on_interaction_area_body_entered(body: Node2D) -> void:
	# Track pickable items in the interaction area
	if body.is_in_group("pickable"):
		if not nearby_pickables.has(body):
			nearby_pickables.append(body)


func _on_interaction_area_body_exited(body: Node2D) -> void:
	# Remove pickable items when they leave the interaction area
	if body.is_in_group("pickable"):
		var index = nearby_pickables.find(body)
		if index >= 0:
			nearby_pickables.remove_at(index)


func _on_interaction_area_area_entered(area: Area2D) -> void:
	# Track pickable items (Area2D parent)
	var parent = area.get_parent()
	if parent and parent.is_in_group("pickable"):
		if not nearby_pickables.has(parent):
			nearby_pickables.append(parent)


func _on_interaction_area_area_exited(area: Area2D) -> void:
	# Remove pickable items when they leave
	var parent = area.get_parent()
	if parent and parent.is_in_group("pickable"):
		var index = nearby_pickables.find(parent)
		if index >= 0:
			nearby_pickables.remove_at(index)


func _pickup_nearest_item() -> void:
	# Find the nearest pickable item
	var nearest_item = null
	var nearest_distance = INF

	for item in nearby_pickables:
		if not is_instance_valid(item):
			continue

		var distance = global_position.distance_to(item.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_item = item

	# Pick up the nearest item
	if nearest_item:
		if nearest_item.has_method("pickup_item"):
			# Set HUD reference if needed (get from current scene)
			if not nearest_item.hud:
				var current_scene = get_tree().current_scene
				if (
					current_scene
					and current_scene.has_method("get")
					and current_scene.has("hud_instance")
				):
					nearest_item.hud = current_scene.hud_instance
				elif HUD and HUD.hud_scene_instance:
					nearest_item.hud = HUD.hud_scene_instance

			nearest_item.pickup_item()
			# Remove from nearby set
			var index = nearby_pickables.find(nearest_item)
			if index >= 0:
				nearby_pickables.remove_at(index)


func start_interaction(interaction_type: String):
	current_interaction = interaction_type
	# print("Player can interact with:", interaction_type)


func stop_interaction():
	current_interaction = ""


func interact_with_droppable(droppable_data: Resource) -> void:
	if inventory_manager:
		var _success = inventory_manager.add_item_to_first_empty_slot(droppable_data)
