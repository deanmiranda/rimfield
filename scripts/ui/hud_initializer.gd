# hud_initializer.gd
# Initializes HUD with ToolkitContainer + SlotBase system
# Attach this to the Hud root node in hud.tscn

extends Node

# References
@onready var slots_container: HBoxContainer = $HUD/MarginContainer/HBoxContainer
var toolkit_container: ToolkitContainer = null
var is_initialized: bool = false


func _ready() -> void:
	# GUARD: Prevent re-initialization if already set up with the same container
	if is_initialized:
		if InventoryManager and InventoryManager.toolkit_container == toolkit_container:
			print("[HudInitializer] Already initialized with same ToolkitContainer - skipping")
			return
		else:
			print("[HudInitializer] WARNING: Re-initializing with different container!")
	
	# Check if ToolkitContainer already exists in InventoryManager (prevent duplicates)
	if InventoryManager and InventoryManager.toolkit_container:
		print("[HudInitializer] ToolkitContainer already exists - reusing existing instance")
		toolkit_container = InventoryManager.toolkit_container
		# Still need to set up slots for THIS HUD scene instance (slots are scene-specific)
		_setup_toolkit_slots()
		is_initialized = true
		print("[HudInitializer] HUD slots linked to existing ToolkitContainer")
		return
	else:
		# Create ToolkitContainer (first time)
		# Load script since class_name may not be recognized until Godot restarts
		var container_script = load("res://scripts/ui/toolkit_container.gd")
		if container_script:
			toolkit_container = container_script.new()
			toolkit_container.name = "ToolkitContainer"
			add_child(toolkit_container)
			
			# Wait for container to be ready and register
			await get_tree().process_frame
		else:
			push_error("[HudInitializer] Failed to load ToolkitContainer script!")
			return
	
	# Replace HUD slots with SlotBase
	_setup_toolkit_slots()
	is_initialized = true
	
	print("[HudInitializer] HUD initialized with ToolkitContainer")


func _setup_toolkit_slots() -> void:
	"""Replace existing HUD slots with SlotBase connected to ToolkitContainer"""
	if not slots_container or not toolkit_container:
		print("[HudInitializer] ERROR: Missing slots_container or toolkit_container!")
		return
	
	# GUARD: Only clear slots if this is a fresh setup
	# If slots already exist and are linked to this container, preserve them
	var needs_rebuild = false
	if toolkit_container.slots.size() == 0:
		needs_rebuild = true
	else:
		# Check if existing slots are actually in the scene tree
		var first_slot = toolkit_container.slots[0] if toolkit_container.slots.size() > 0 else null
		if not first_slot or not is_instance_valid(first_slot) or not first_slot.get_parent():
			needs_rebuild = true
	
	if needs_rebuild:
		# Clear old slot references (this HUD instance will provide new ones)
		toolkit_container.slots.clear()
	else:
		# Slots already exist and are valid - don't rebuild
		print("[HudInitializer] Slots already exist and are valid - skipping rebuild")
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
	
	# InventoryManager reference is set automatically by container registration
	# No need to set manually here
	print("[HudInitializer] Slots linked to ToolkitContainer")
