extends Node

# Inventory data to store the item textures assigned to each slot
var inventory_slots: Dictionary = {}

# Toolkit data to store the item textures assigned to each toolkit slot (HUD slots 0-9)
var toolkit_slots: Dictionary = {}

# Reference to the inventory UI scene and instance
@export var inventory_scene: PackedScene
var inventory_instance: Control = null

# Use GameConfig Resource instead of magic number (follows .cursor/rules/godot.md)
var game_config: Resource = null
var max_inventory_slots: int = 12  # Default inventory size (will be overridden by GameConfig)
var max_toolkit_slots: int = 10  # Default toolkit size (will be overridden by GameConfig)

func _ready() -> void:
	# Load GameConfig Resource
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		max_inventory_slots = game_config.inventory_slot_count
		max_toolkit_slots = game_config.hud_slot_count
	
	# Initialize inventory_slots
	for i in range(max_inventory_slots):
		inventory_slots[i] = null
	
	# Initialize toolkit_slots
	for i in range(max_toolkit_slots):
		toolkit_slots[i] = null
		
# Add an item to the inventory (returns true if successful, false if full)
func add_item(slot_index: int, item_texture: Texture) -> bool:
	inventory_slots[slot_index] = item_texture
	return true

func get_first_empty_slot() -> int:
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == null:
			return i
	return -1
	
# Remove an item from the inventory
func remove_item(slot_index: int) -> void:
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = null

# Get an item from the inventory
func get_item(slot_index: int) -> Texture:
	return inventory_slots.get(slot_index, null)

# Remove an item from inventory (for drag/drop)
func remove_item_from_inventory(slot_index: int) -> void:
	"""Remove item from inventory slot (used when dragging to toolkit)"""
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = null
		sync_inventory_ui()

# Instantiate the inventory UI and add it to the current scene tree
func instantiate_inventory_ui(parent_node: Node = null) -> void:
	if inventory_instance:  # Prevent duplicates
		print("Inventory instance already exists.")
		return

	if not inventory_scene:
		print("Error: Inventory scene is not assigned in the inspector.")
		return

	inventory_instance = inventory_scene.instantiate() as Control
	if not inventory_instance:
		print("Error: Failed to instantiate inventory scene.")
		return

	# Adding inventory instance to the specified parent node or the root node
	if parent_node:
		parent_node.add_child(inventory_instance)
	else:
		get_tree().root.add_child(inventory_instance)

	inventory_instance.visible = false
	print("Inventory UI successfully instantiated.")

	# Set layout properties for proper anchoring and centering
	inventory_instance.anchor_left = 0.5
	inventory_instance.anchor_right = 0.5
	inventory_instance.anchor_top = 0.5
	inventory_instance.anchor_bottom = 0.5
	inventory_instance.offset_left = -200
	inventory_instance.offset_top = -200
	inventory_instance.offset_right = 200
	inventory_instance.offset_bottom = 200

	# Assign textures to slots
	assign_textures_to_slots()

# Set the inventory instance
func set_inventory_instance(instance: Control) -> void:
	if instance and instance is Control:
		inventory_instance = instance
	else:
		print("Error: Provided instance is not a valid Control node.")

func add_item_to_first_empty_slot(item_data: Resource) -> bool:
	
	# Iterate over the slots in the inventory
	for slot_index in inventory_slots.keys():
		if inventory_slots[slot_index] == null:  # Check if the slot is empty
			#print("Found empty slot: ", slot_index)
			inventory_slots[slot_index] = item_data.texture
			#print("Item added to slot: ", slot_index, " Item ID: ", item_data.item_id)
			sync_inventory_ui()  # Trigger UI update
			return true
	return false

#	Functions for the inventory panel
func update_inventory_slots(slot_index: int, item_texture: Texture) -> void:
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = item_texture
		#print("Inventory slot ", slot_index, " updated with texture: ", item_texture)
	else:
		print("Error: Slot index ", slot_index, " is out of bounds.")

func sync_inventory_ui() -> void:
	#print("Syncing UI with inventory_slots dictionary...")

	if not inventory_instance:
		print("Error: Inventory instance is null. Cannot sync UI.")
		return

	# Access the GridContainer for slots
	var grid_container = inventory_instance.get_node_or_null("CenterContainer/GridContainer")
	if not grid_container:
		print("Error: GridContainer node not found in inventory instance.")
		return

	# Sync slots with inventory dictionary
	for i in range(inventory_slots.size()):
		if i >= grid_container.get_child_count():
			#print("Warning: Slot index", i, "exceeds GridContainer child count.")
			break  # Stop if we exceed the available slots in GridContainer

		var slot = grid_container.get_child(i)  # Get slot by index
		if slot and slot is TextureButton:
			var item_texture = inventory_slots[i]
			slot.texture_normal = item_texture if item_texture != null else null  # Update texture
			#print("Updated slot: ", i, " with texture: ", item_texture)
		else:
			print("Warning: Slot", i, "is not a TextureButton or not found.")

	#print("Inventory UI sync complete.")

# Toolkit tracking functions for drag/drop
func add_item_from_toolkit(slot_index: int, texture: Texture) -> bool:
	"""Add item to inventory from toolkit slot"""
	if slot_index < 0 or slot_index >= max_inventory_slots:
		print("Error: Inventory slot index ", slot_index, " is out of bounds.")
		return false
	
	inventory_slots[slot_index] = texture
	sync_inventory_ui()
	return true

func remove_item_from_toolkit(slot_index: int) -> void:
	"""Remove item from toolkit slot (used when dragging to inventory)"""
	if toolkit_slots.has(slot_index):
		toolkit_slots[slot_index] = null
		sync_toolkit_ui()

func get_toolkit_item(slot_index: int) -> Texture:
	"""Get item texture from toolkit slot"""
	return toolkit_slots.get(slot_index, null)

func add_item_to_toolkit(slot_index: int, texture: Texture) -> bool:
	"""Add item to toolkit slot (used when dragging from inventory)"""
	if slot_index < 0 or slot_index >= max_toolkit_slots:
		print("Error: Toolkit slot index ", slot_index, " is out of bounds.")
		return false
	
	toolkit_slots[slot_index] = texture
	sync_toolkit_ui()
	return true

func sync_toolkit_ui(hud_instance: Node = null) -> void:
	"""Sync toolkit UI with toolkit_slots dictionary"""
	if not hud_instance:
		# Try to find HUD in scene tree
		var hud = get_tree().root.get_node_or_null("HUD")
		if hud:
			hud_instance = hud
		else:
			print("Error: HUD instance not provided and not found in scene tree.")
			return
	
	# Use GameConfig for toolkit slot count
	var hud_slot_count: int = max_toolkit_slots
	if game_config:
		hud_slot_count = game_config.hud_slot_count
	
	# Access the HBoxContainer for toolkit slots
	var slots_container = hud_instance.get_node_or_null("MarginContainer/HBoxContainer")
	if not slots_container:
		print("Error: HBoxContainer not found in HUD instance.")
		return
	
	# Sync toolkit slots with UI
	for i in range(hud_slot_count):
		if i >= slots_container.get_child_count():
			break
		
		var texture_button = slots_container.get_child(i)
		if texture_button and texture_button is TextureButton:
			var hud_slot = texture_button.get_node_or_null("Hud_slot_" + str(i))
			if hud_slot:
				var item_texture = toolkit_slots.get(i, null)
				if hud_slot.has_method("set_item"):
					hud_slot.set_item(item_texture)
				else:
					# Fallback for TextureRect nodes
					if hud_slot is TextureRect:
						hud_slot.texture = item_texture

#	Functions for Hud 
func add_item_to_hud_slot(item_data: Resource, hud: Node) -> bool:
	# Iterate through HUD slots using GameConfig (follows .cursor/rules/godot.md)
	var hud_slot_count: int = 10
	if game_config:
		hud_slot_count = game_config.hud_slot_count
	
	for i in range(hud_slot_count):
		var slot_path = "HUD/MarginContainer/HBoxContainer/TextureButton_" + str(i) + "/Hud_slot_" + str(i)
		var slot = hud.get_node_or_null(slot_path)

		if slot:
			if slot.texture != null:  # Skip if slot already has a item
				continue

			# Directly assign the droppable's texture
			if item_data and item_data.texture:
				inventory_slots[i] = item_data.texture  # Update inventory slot for reference
				slot.texture = item_data.texture  # Update HUD slot
				return true

		else:
			print("HUD slot ", i, " not found at path:", slot_path)
	#print('Hud Full returning false and attempting inventory')
	return false


# Assign textures to the UI slots
func assign_textures_to_slots() -> void:
	if not inventory_instance:
		print("Error: No inventory instance available for assigning textures.")
		return

	var grid_container = inventory_instance.get_node_or_null("CenterContainer/GridContainer")
	if not grid_container:
		print("Error: GridContainer node not found in inventory instance.")
		return

	var slots = grid_container.get_children()
	for slot in slots:
		if slot is TextureButton:
			var slot_index = 0  # Declare slot_index before use
			if not slot.has_meta("slot_index"):
				slot_index = slots.find(slot)
				slot.set_meta("slot_index", slot_index)
			else:
				slot_index = slot.get_meta("slot_index")

			var item_texture = get_item(slot_index)
			if item_texture != null:
				slot.texture_normal = item_texture
			else:
				var empty_texture = slot.get("empty_texture")
				if empty_texture:
					slot.texture_normal = empty_texture
				else:
					print("Error: No empty texture assigned to slot index", slot_index)
		else:
			print("Warning: Unexpected node found in inventory slots. Expected 'TextureButton'. Node name:", slot.name)


#// Base functionality ends

# Upgrades

#func upgrade_inventory(new_size: int) -> void:
	#if new_size > max_inventory_slots:
		#for i in range(max_inventory_slots, new_size):
			#inventory_slots[i] = null  # Initialize new slots
		#max_inventory_slots = new_size
		#print("Inventory upgraded! New size:", max_inventory_slots)
		#update_inventory_ui()  # Update UI to reflect the new size
	#else:
		#print("New size must be larger than current capacity!")

#func update_inventory_ui() -> void:
		#print('add slots to inventory panel for more inventory');
		
#func update_hud_slots_ui(hud: Node) -> void:
	## Iterate through tool slots (hud_slot_0 to hud_slot_4)
	#for i in range(10):  # Assuming 5 tool slots
		#var slot_path = "HUD/MarginContainer/HBoxContainer/TextureButton_" + str(i) + "/Hud_slot_" + str(i)
		#var slot = hud.get_node_or_null(slot_path)
#
		#if slot:
			#var item_texture = inventory_slots.get(i, null)  # Fetch from inventory_slots
#
			#if item_texture != null:
				#slot.texture = item_texture  # Assign the texture
			#else:
				#slot.texture = null  # Clear the slot if empty
		#else:
			#print("HUD slot", i, "not found at path:", slot_path)
#
#
##Debug functions
## Populate the inventory with only a single test item for drag-and-drop testing
##func populate_inventory_with_test_items() -> void:
	##var test_texture = preload("res://assets/tiles/tools/shovel.png")
	##if add_item(0, test_texture):
		##print("Test item added to inventory at slot 0.")
	##else:
		##print("Error: Could not add test item to inventory.")
#
	##assign_textures_to_slots()
