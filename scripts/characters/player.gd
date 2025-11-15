# player.gd
# Handles basic player movements.

extends CharacterBody2D

# Use GameConfig Resource instead of magic number (follows .cursor/rules/godot.md)
var game_config: Resource = null
var speed: float = 200  # Default (will be overridden by GameConfig)
var direction: Vector2 = Vector2.ZERO  # Tracks input direction
var interactable: Node = null          # Stores the interactable object the player is near
var farming_manager: Node = null       # Reference to the farming system
var current_interaction: String = ""  # Track the current interaction

# Interaction system - signal-based sets (no polling)
var nearby_pickables: Array = []  # Array of nearby pickable items
var pickup_radius: float = 48.0  # Default (will be overridden by GameConfig)

@onready var inventory_manager = InventoryManager  # Singleton reference
@onready var sprite = $AnimatedSprite2D  # Reference to AnimatedSprite2D node
@onready var interaction_area: Area2D = null  # Will be created in _ready

func _ready() -> void:
	# ============================================
	# CONFIRMATION: CURSOR AI IS EDITING THIS FILE
	# This is a test change to verify we're in the right project
	# ============================================
	var timestamp = Time.get_datetime_string_from_system()
	print("============================================")
	print("CURSOR AI CONFIRMATION: Player script loaded!")
	print("Last edited: ", timestamp)
	print("If you see this message, we're editing the RIGHT project!")
	print("============================================")
	
	# Load GameConfig Resource
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		speed = game_config.player_speed
		pickup_radius = game_config.pickup_radius
	
	# Create interaction Area2D for detecting nearby pickables
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.monitorable = false  # This area detects, doesn't need to be detected
	interaction_area.monitoring = true   # Enable monitoring
	interaction_area.collision_mask = 2  # Detect items on collision layer 2
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

func _process(_delta: float) -> void:
	# Handle interaction input
	if Input.is_action_just_pressed("ui_mouse_left"):
		if farming_manager:
			var mouse_pos = MouseUtil.get_world_mouse_pos_2d(self)
			# Let farming_manager handle the interaction
			farming_manager.interact_with_tile(mouse_pos, global_position)

func _unhandled_input(event: InputEvent) -> void:
	# Handle tool keyboard shortcuts (1, 2, 3, 4) - directly use tool at mouse position
	if farming_manager:
		var mouse_pos = MouseUtil.get_world_mouse_pos_2d(self)
		if event.is_action_pressed("ui_tool_hoe"):
			print("DEBUG: Hoe tool pressed")
			farming_manager.current_tool = "hoe"
			farming_manager.interact_with_tile(mouse_pos, global_position)
		elif event.is_action_pressed("ui_tool_till"):
			print("DEBUG: Till tool pressed")
			farming_manager.current_tool = "till"
			farming_manager.interact_with_tile(mouse_pos, global_position)
		elif event.is_action_pressed("ui_tool_pickaxe"):
			print("DEBUG: Pickaxe tool pressed")
			farming_manager.current_tool = "pickaxe"
			farming_manager.interact_with_tile(mouse_pos, global_position)
		elif event.is_action_pressed("ui_tool_seed"):
			print("DEBUG: Seed tool pressed")
			farming_manager.current_tool = "seed"
			farming_manager.interact_with_tile(mouse_pos, global_position)
	
	# Handle E key for contextual interaction
	if event.is_action_pressed("ui_interact"):
		# Prioritize pickables over doors
		if nearby_pickables.size() > 0:
			print("DEBUG: E pressed, attempting to pick up from ", nearby_pickables.size(), " nearby items")
			_pickup_nearest_item()
		elif current_interaction == "house":
			# Door interaction is handled by house_interaction.gd
			# This is just a fallback - door should handle its own input
			pass
		else:
			print("DEBUG: E pressed but no nearby pickables (count: ", nearby_pickables.size(), ")")

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
			print("DEBUG: Pickable item entered interaction area: ", parent.name)

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
		print("DEBUG: Nearest item found: ", nearest_item.name, " at distance: ", nearest_distance)
		if nearest_item.has_method("pickup_item"):
			# Set HUD reference if needed (get from current scene)
			if not nearest_item.hud:
				var current_scene = get_tree().current_scene
				if current_scene and current_scene.has_method("get") and current_scene.has("hud_instance"):
					nearest_item.hud = current_scene.hud_instance
				elif HUD and HUD.hud_scene_instance:
					nearest_item.hud = HUD.hud_scene_instance
			
			print("DEBUG: Calling pickup_item() on ", nearest_item.name)
			nearest_item.pickup_item()
			# Remove from nearby set
			var index = nearby_pickables.find(nearest_item)
			if index >= 0:
				nearby_pickables.remove_at(index)
		else:
			print("DEBUG: Item ", nearest_item.name, " does not have pickup_item() method")
	else:
		print("DEBUG: No valid nearest item found")

func start_interaction(interaction_type: String):
	current_interaction = interaction_type
	# print("Player can interact with:", interaction_type)

func stop_interaction():
	current_interaction = ""
	
func interact_with_droppable(droppable_data: Resource) -> void:
	if inventory_manager:
		var success = inventory_manager.add_item_to_first_empty_slot(droppable_data)
		if success:
			print("Item added to inventory:", droppable_data.item_id)
		else:
			print("Inventory full! Could not pick up:", droppable_data.item_id)
