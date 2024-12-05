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
		print("Inventory instance set successfully.")
	else:
		print("Error: Provided instance is not a valid Control node.")
