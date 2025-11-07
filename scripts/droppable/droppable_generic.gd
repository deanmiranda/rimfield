# droppable_generic.gd
extends Node2D

@export var item_data: Resource  # Reference to the DroppableItem resource

# Signal removed - pickup is handled directly via pickup_item() method
# signal picked_up(item_data: Resource)  # Signal to emit when picked up

var player: Node = null  # Reference to the player
var hud: Node = null  # Reference to the HUD

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

func _on_body_entered(body: Node2D) -> void:
	# Mark as nearby candidate only - no auto-pickup
	# The player's interaction manager will handle pickup on E press
	if body is CharacterBody2D and body.name == "Player":
		# Signal that this item is nearby (player will track it)
		pass

func _on_body_exited(body: Node2D) -> void:
	# Player left the area - will be removed from nearby set
	if body is CharacterBody2D and body.name == "Player":
		pass

func pickup_item() -> void:
	# Called by player when E is pressed
	if hud and item_data and item_data.texture:
		# Try adding to HUD slots first
		var added_to_hud = InventoryManager.add_item_to_hud_slot(item_data, hud)

		if not added_to_hud:
			# Try adding to inventory as overflow
			var added_to_inventory = InventoryManager.add_item_to_first_empty_slot(item_data)
			
			if not added_to_inventory:
				return  # Exit without removing the droppable
				
		# If added successfully to HUD or inventory, remove from the map
		queue_free()
	else:
		print("HUD reference or item data is null; cannot update.")
