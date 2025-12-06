# hud_initializer.gd
# Initializes HUD with ToolkitContainer + SlotBase system
# Attach this to the Hud root node in hud.tscn

extends Node

# References
@onready var slots_container: HBoxContainer = $HUD/MarginContainer/HBoxContainer
var toolkit_container: ToolkitContainer = null


func _ready() -> void:
	# Create ToolkitContainer
	toolkit_container = ToolkitContainer.new()
	toolkit_container.name = "ToolkitContainer"
	add_child(toolkit_container)
	
	# Wait for container to be ready
	await get_tree().process_frame
	
	# Replace HUD slots with SlotBase
	_setup_toolkit_slots()
	
	print("[HudInitializer] HUD initialized with ToolkitContainer")


func _setup_toolkit_slots() -> void:
	"""Replace existing HUD slots with SlotBase connected to ToolkitContainer"""
	if not slots_container or not toolkit_container:
		print("[HudInitializer] ERROR: Missing slots_container or toolkit_container!")
		return
	
	var empty_texture = preload("res://assets/ui/tile_outline.png")
	
	# Get existing slots
	var existing_slots = slots_container.get_children()
	
	# Replace each slot while preserving Highlight children
	for i in range(min(existing_slots.size(), 10)):
		var old_slot = existing_slots[i]
		
		# Preserve Highlight child (for active tool visual)
		var highlight_node = old_slot.get_node_or_null("Highlight")
		if highlight_node:
			old_slot.remove_child(highlight_node) # Remove from old slot but don't free it
		
		# Copy any existing item from old slot's Hud_slot_X child
		var existing_texture = null
		var existing_count = 1
		var hud_slot_child = old_slot.get_node_or_null("Hud_slot_" + str(i))
		if hud_slot_child and hud_slot_child is TextureRect:
			existing_texture = hud_slot_child.texture
			if existing_texture:
				# Check if texture is AtlasTexture (for chest icon)
				if existing_texture is AtlasTexture:
					existing_texture = existing_texture.atlas
		elif old_slot.has_method("get_item"):
			existing_texture = old_slot.get_item()
			if "stack_count" in old_slot:
				existing_count = old_slot.stack_count
		
		# Set in container data if item exists
		if existing_texture:
			toolkit_container.inventory_data[i] = {
				"texture": existing_texture,
				"count": existing_count,
				"weight": 0.0
			}
		
		# Create new SlotBase
		var new_slot = SlotBase.new()
		new_slot.slot_index = i
		new_slot.empty_texture = empty_texture
		new_slot.container_ref = toolkit_container
		new_slot.name = "TextureButton_%d" % i # Keep same name for compatibility
		new_slot.custom_minimum_size = Vector2(100, 100)
		new_slot.ignore_texture_size = true
		new_slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		# Add to container and scene
		slots_container.add_child(new_slot)
		slots_container.move_child(new_slot, i) # Maintain order
		toolkit_container.slots.append(new_slot)
		
		# Re-add Highlight child to new slot
		if highlight_node:
			new_slot.add_child(highlight_node)
		
		# Initialize slot
		new_slot._ready()
		
		# Remove old slot
		slots_container.remove_child(old_slot)
		old_slot.queue_free()
	
	# Sync UI to show migrated data
	toolkit_container.sync_ui()
	
	print("[HudInitializer] Created %d toolkit slots" % toolkit_container.slots.size())
	
	# Update InventoryManager reference
	if InventoryManager:
		InventoryManager.toolkit_container = toolkit_container
		print("[HudInitializer] Linked ToolkitContainer to InventoryManager")
