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
			# Check HUD slots for stacking
			var added_to_hud = _try_stack_in_hud(item_data.texture)

			if not added_to_hud:
				# Fallback to InventoryManager for overflow or first empty slot
				var added_to_inventory = InventoryManager.add_item_to_hud_slot(item_data, hud)
				if not added_to_inventory:
					added_to_inventory = InventoryManager.add_item_to_first_empty_slot(item_data)

				# Exit if unable to stack or add
				if not added_to_inventory:
					print("Unable to add item to inventory or HUD.")
					return

			# If added successfully to HUD or inventory, remove the droppable
			queue_free()
		else:
			print("HUD reference or item data is null; cannot update.")

func _try_stack_in_hud(item_texture: Texture) -> bool:
	# Access the HBoxContainer directly from the singleton
	var slots_container = hud.get_node_or_null("HUD/MarginContainer/HBoxContainer")
	if not slots_container:
		print("Error: Could not find HBoxContainer in HUD.")
		return false

	# Iterate through the TextureButtons and their Hud_slot_X children
	var slots = slots_container.get_children()
	for slot in slots:
		if slot is TextureButton:
			# Access the Hud_slot_X node (TextureRect) inside the TextureButton
			var hud_slot = slot.get_node_or_null("Hud_slot_" + str(slot.slot_index))
			if hud_slot and hud_slot.has_method("get_texture") and hud_slot.texture == item_texture:
				# Stack the item
				var label = slot.get_node_or_null("Label")
				if label and label.visible:
					label.text = str(int(label.text) + 1)  # Increment the count
				else:
					label.text = "2"  # Set the initial stack count
					label.visible = true
				return true  # Item successfully stacked

	# If no slot was available for stacking, return false
	return false
