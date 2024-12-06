# player.gd
# Handles basic player movements.

extends CharacterBody2D

var speed: float = 200
var direction: Vector2 = Vector2.ZERO  # Tracks input direction
var interactable: Node = null          # Stores the interactable object the player is near
var farming_manager: Node = null       # Reference to the farming system
var current_interaction: String = ""  # Track the current interaction

@onready var inventory_manager = InventoryManager  # Singleton reference
@onready var sprite = $AnimatedSprite2D  # Reference to AnimatedSprite2D node

func _ready() -> void:
	# Locate farming system if in the farm scene
	var farm_scene = get_tree().current_scene
	print("Current scene:", farm_scene)

	if farm_scene and farm_scene.has_node("FarmingManager"):
		farming_manager = farm_scene.get_node("FarmingManager")
		print("FarmingManager found and connected:", farming_manager)
	else:
		farming_manager = null
		print("No FarmingManager found in this scene. Current children of the scene:")
		for child in farm_scene.get_children():
			print("- ", child.name)

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
	if Input.is_action_just_pressed("ui_interact"):
		if farming_manager:
			var mouse_pos = get_global_mouse_position()

			# Let farming_manager handle the interaction
			farming_manager.interact_with_tile(mouse_pos, global_position)

func start_interaction(interaction_type: String):
	current_interaction = interaction_type
	print("Player can interact with:", interaction_type)

func stop_interaction():
	current_interaction = ""
	print("Player interaction ended.")
	
func interact_with_droppable(droppable_data: Resource) -> void:
	print("Player interacting with droppable. Item ID:", droppable_data.item_id)
	if inventory_manager:
		var success = inventory_manager.add_item_to_first_empty_slot(droppable_data)
		if success:
			print("Item added to inventory:", droppable_data.item_id)
		else:
			print("Inventory full! Could not pick up:", droppable_data.item_id)
