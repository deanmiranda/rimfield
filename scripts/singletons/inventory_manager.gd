extends Node

# Inventory data to store the item textures assigned to each slot
var inventory_slots: Dictionary = {}

# Reference to the inventory UI scene and instance
@export var inventory_scene: PackedScene
var inventory_instance: Control = null

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
		inventory_slots.erase(slot_index)

# Get an item from the inventory
func get_item(slot_index: int) -> Texture:
	return inventory_slots.get(slot_index, null)

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

# Assign textures to the inventory UI slots
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

# Populate the inventory with only a single test item for drag-and-drop testing
func populate_inventory_with_test_items() -> void:
	var test_texture = preload("res://assets/tiles/tools/shovel.png")
	if add_item(0, test_texture):
		print("Test item added to inventory at slot 0.")
	else:
		print("Error: Could not add test item to inventory.")

	assign_textures_to_slots()

# Set the inventory instance
func set_inventory_instance(instance: Control) -> void:
	if instance and instance is Control:
		inventory_instance = instance
	else:
		print("Error: Provided instance is not a valid Control node.")

func add_item_to_first_empty_slot(item_data: Resource) -> bool:
	print("Attempting to add item:", item_data.item_id, "to inventory.")
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == null:  # Check if slot is empty
			print("Found empty slot:", i)
			inventory_slots[i] = item_data.texture
			print("Item added to slot:", i, "Item ID:", item_data.item_id)
			update_inventory_ui()  # Trigger UI update
			return true
	print("Inventory full. Could not add item:", item_data.item_id)
	return false
	
func update_inventory_ui() -> void:
	print("Updating inventory UI...")

	# Fetch HUD node using its path
	var hud = get_node_or_null("res://scenes/ui/hud.tscn")
	if not hud:
		print("Error: HUD instance not found.")
		return

	# Access the inventory container within the HUD
	var inventory_container = hud.get_node_or_null("MarginContainer/HBoxContainer")
	if not inventory_container:
		print("Error: Inventory container not found in HUD.")
		return

	# Iterate through the inventory slots
	for i in range(inventory_slots.size()):
		print('inventory size', inventory_slots.size())
		var slot = inventory_container.get_child(i)  # Get the TextureButton or slot node
		if slot and inventory_slots[i] != null:
			print("Updating slot:", i, "with texture:", inventory_slots[i])
			slot.texture_normal = inventory_slots[i]  # Update slot texture
		else:
			print("Clearing slot:", i)
			slot.texture_normal = null  # Clear the slot if empty

	print("Inventory UI updated.")

func add_item_to_hud_slot(item_data: Resource, hud: Node) -> bool:
	# Iterate through HUD tool slots
	for i in range(5):  # Assuming 5 tool slots
		var slot_path = "HUD/MarginContainer/HBoxContainer/TextureButton_" + str(i) + "/tool_slot_" + str(i)
		var slot = hud.get_node_or_null(slot_path)

		if slot:
			if slot.texture != null:  # Skip if slot already has a tool
				continue

			# Directly assign the droppable's texture
			if item_data and item_data.texture:
				inventory_slots[i] = item_data.texture  # Update inventory slot for reference
				slot.texture = item_data.texture  # Update HUD slot
				return true

		else:
			print("HUD slot", i, "not found at path:", slot_path)

	return false

func update_hud_slots_ui(hud: Node) -> void:
	# Iterate through tool slots (tool_slot_0 to tool_slot_4)
	for i in range(5):  # Assuming 5 tool slots
		var slot_path = "HUD/MarginContainer/HBoxContainer/TextureButton_" + str(i) + "/tool_slot_" + str(i)
		var slot = hud.get_node_or_null(slot_path)

		if slot:
			var item_texture = inventory_slots.get(i, null)  # Fetch from inventory_slots

			if item_texture != null:
				slot.texture = item_texture  # Assign the texture
			else:
				slot.texture = null  # Clear the slot if empty
		else:
			print("HUD slot", i, "not found at path:", slot_path)
