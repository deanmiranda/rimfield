extends Node2D

@export var item_data: Resource  # Reference to the DroppableItem resource

func _ready() -> void:
	# Ensure item_data is set
	if not item_data:
		queue_free()
		return

	# Set the texture of the Sprite2D
	var sprite = $Sprite2D
	if sprite and item_data.texture:
		sprite.texture = item_data.texture
	else:
		print("Error: Sprite2D or texture is missing!")

	# Connect interaction logic (on Area2D enter)
	$Area2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name == "Player":  # Example: check if the player overlaps
		DroppableFactory.add_to_inventory(item_data)  # Add to inventory via factory
		queue_free()  # Remove the droppable from the world
