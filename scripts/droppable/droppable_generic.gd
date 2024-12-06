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
		print("Droppable picked up by player. Item ID:", item_data.item_id)
		# Pass the HUD when adding the tool to the inventory
		var hud = get_tree().current_scene.get_node("HUD")
		if hud and InventoryManager.add_tool_to_slot(item_data, hud):
			print("Tool successfully added to inventory.")
			queue_free()  # Remove the droppable from the world
		else:
			print("Tool slots are full. Could not pick up tool.")
