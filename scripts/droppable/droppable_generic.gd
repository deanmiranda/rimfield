# droppable_generic.gd
extends Node2D

@export var item_data: Resource  # Reference to the DroppableItem resource

signal picked_up(item_data: Resource)  # Signal to emit when picked up

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
	if body is CharacterBody2D and body.name == "Player":
		if hud and item_data and item_data.texture:
			# Try adding to HUD slots first
			var added_to_hud = InventoryManager.add_item_to_hud_slot(item_data, hud)

			if not added_to_hud:
				print("All tool slots are full. Attempting to add to inventory.")
				
				# Try adding to inventory as overflow
				var added_to_inventory = InventoryManager.add_item_to_first_empty_slot(item_data)
				
				if not added_to_inventory:
					print("Inventory is also full. Droppable remains on the map.")
					return  # Exit without removing the droppable
					
			# If added successfully to HUD or inventory, remove from the map
			queue_free()
		else:
			print("HUD reference or item data is null; cannot update.")
