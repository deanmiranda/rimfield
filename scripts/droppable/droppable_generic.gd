# droppable_generic.gd
extends Node2D

@export var item_data: Resource # Reference to the DroppableItem resource

# Signal removed - pickup is handled directly via pickup_item() method
# signal picked_up(item_data: Resource)  # Signal to emit when picked up

var player: Node = null # Reference to the player
var hud: Node = null # Reference to the HUD


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
		# Try adding to toolkit (toolbelt) with auto-stacking first
		var remaining = InventoryManager.add_item_to_toolkit_auto_stack(item_data.texture, 1)

		if remaining > 0:
			# Try adding to inventory as overflow
			remaining = InventoryManager.add_item_auto_stack(item_data.texture, remaining)

			if remaining > 0:
				return # Exit without removing the droppable (inventory full)

		# Log chest pickups for debugging
		if item_data.item_id == "chest":
			var chest_slot = -1
			var chest_count = 0
			# Find which slot has the chest
			for i in range(InventoryManager.max_toolkit_slots):
				var slot_texture = InventoryManager.get_toolkit_item(i)
				if slot_texture == item_data.texture:
					chest_slot = i
					chest_count = InventoryManager.get_toolkit_item_count(i)
					break
			print("[CHEST PICKUP] Added chest to toolkit slot=%d new_count=%d" % [chest_slot, chest_count])
		
		# If added successfully to toolkit or inventory, remove from the map
		queue_free()
