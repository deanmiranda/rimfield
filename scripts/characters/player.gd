extends CharacterBody2D

var speed: float = 200
var direction: Vector2 = Vector2.ZERO  # Tracks input direction
var interactable: Node = null          # Stores the interactable object the player is near

@onready var sprite = $AnimatedSprite2D  # Reference to AnimatedSprite2D node
func _physics_process(_delta: float) -> void:
	# Reset direction to zero
	direction = Vector2.ZERO

	# Handle input for movement
	direction.x = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	direction.y = int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))

	# Normalize direction to prevent diagonal speed boost
	if direction.length() > 1:
		direction = direction.normalized()

	# Update velocity based on direction and speed
	velocity = direction * speed

	# Apply movement using built-in move_and_slide()
	move_and_slide()

	# Update animation direction and state
	_update_animation(direction)
	
func _update_animation(input_direction: Vector2) -> void:
	var anim_sprite = $AnimatedSprite2D

	if input_direction == Vector2.ZERO:
		if anim_sprite.animation.begins_with("walk_"):
			var idle_animation = "stand_" + anim_sprite.animation.substr(5)
			anim_sprite.play(idle_animation)
	else:
		if input_direction.x > 0:
			anim_sprite.play("walk_right")
		elif input_direction.x < 0:
			anim_sprite.play("walk_left")
		elif input_direction.y > 0:
			anim_sprite.play("walk_down")
		elif input_direction.y < 0:
			anim_sprite.play("walk_up")

# Detect when the player enters an interaction zone
func _on_body_entered(body: Node) -> void:
	if body.has_method("on_interact"):  # Check if the object can be interacted with
		interactable = body

# Detect when the player leaves an interaction zone
func _on_body_exited(body: Node) -> void:
	if interactable == body:
		interactable = null

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_interact"):
		if get_node_or_null("HouseInteractionZone"):
			print("Interact key pressed in zone")
			get_node("HouseInteractionZone").handle_interaction()
