# droppable_generic.gd
extends Node2D

@export var item_data: Resource  # Reference to the DroppableItem resource

signal picked_up(item_data: Resource)  # Signal to emit when picked up

var player: Node = null  # Reference to the player

func _ready() -> void:
	# Ensure item_data is set
	if not item_data:
		print("Error: item_data is not assigned!")
		queue_free()
		return

	# Set the texture of the Sprite2D
	var sprite = $Sprite2D
	if sprite and item_data.texture:
		sprite.texture = item_data.texture
	else:
		print("Error: Sprite2D or texture is missing!")

	# Connect interaction logic (on Area2D enter)
	print("Connecting body_entered signal for droppable...")

func _on_body_entered(body: Node2D) -> void:
	# Check if the body is the player using type or class name
	if body is CharacterBody2D and body.name == "Player":
		print("Body entered droppable area:", body.name)
		player = body  # Store reference to the player
		emit_signal("picked_up", item_data)  # Emit signal with item data
		queue_free()  # Remove droppable from the world
	else:
		print("Non-player body entered. Ignoring.")
