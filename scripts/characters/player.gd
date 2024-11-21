extends CharacterBody2D

var speed: float = 200
var direction: Vector2 = Vector2.ZERO  # Tracks input direction
var interactable: Node = null          # Stores the interactable object the player is near

# Called every physics frame
func _physics_process(_delta: float) -> void:
	# Reset direction to zero
	direction = Vector2.ZERO

	# Handle input for movement
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	# Normalize direction to prevent diagonal speed boost
	direction = direction.normalized()

	# Update velocity based on direction and speed
	velocity = direction * speed

	# Apply movement using built-in move_and_slide()
	move_and_slide()

	# Handle interaction
	if Input.is_action_just_pressed("ui_interact") and interactable != null:
		interactable.call("on_interact")  # Call the interactable's interaction method

# Detect when the player enters an interaction zone
func _on_body_entered(body: Node) -> void:
	if body.has_method("on_interact"):  # Check if the object can be interacted with
		interactable = body

# Detect when the player leaves an interaction zone
func _on_body_exited(body: Node) -> void:
	if interactable == body:
		interactable = null

func _process(_delta):
	if Input.is_action_just_pressed("ui_interact"):
		if get_node_or_null("HouseInteractionZone"):
			print("Interact key pressed in zone")
			get_node("HouseInteractionZone").handle_interaction()
