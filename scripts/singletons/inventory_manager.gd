extends Node

# Inventory data to store the item textures, stack counts, and weight assigned to each slot
# Format: {slot_index: {"texture": Texture, "count": int, "weight": float}}
# Weight is a placeholder for future strength/weight system (defaults to 0.0)
var inventory_slots: Dictionary = {}

# Toolkit data to store the item textures, stack counts, and weight assigned to each toolkit slot (HUD slots 0-9)
# Format: {slot_index: {"texture": Texture, "count": int, "weight": float}}
# Weight is a placeholder for future strength/weight system (defaults to 0.0)
var toolkit_slots: Dictionary = {}

# Reference to the inventory UI scene and instance
@export var inventory_scene: PackedScene
var inventory_instance: Control = null

# Use GameConfig Resource instead of magic number (follows .cursor/rules/godot.md)
var game_config: Resource = null
var max_inventory_slots: int = 12  # Default inventory size (will be overridden by GameConfig)
var max_toolkit_slots: int = 10  # Default toolkit size (will be overridden by GameConfig)

# Stack limits
const MAX_TOOLBELT_STACK = 9
const MAX_INVENTORY_STACK = 99


func _ready() -> void:
	# Load GameConfig Resource
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		max_inventory_slots = game_config.inventory_slot_count
		max_toolkit_slots = game_config.hud_slot_count

	# Initialize inventory_slots with new format (includes weight placeholder)
	for i in range(max_inventory_slots):
		inventory_slots[i] = {"texture": null, "count": 0, "weight": 0.0}

	# Initialize toolkit_slots with new format (includes weight placeholder)
	for i in range(max_toolkit_slots):
		toolkit_slots[i] = {"texture": null, "count": 0, "weight": 0.0}

	# Note: _sync_initial_toolkit_from_ui() is called by hud_slot.gd after HUD is ready


# Add an item to the inventory with auto-stacking (returns true if successful, false if full)
func add_item(slot_index: int, item_texture: Texture, count: int = 1) -> bool:
	if not inventory_slots.has(slot_index):
		return false

	inventory_slots[slot_index] = {"texture": item_texture, "count": count, "weight": 0.0}
	return true


# Add item with auto-stacking - finds existing stacks first
func add_item_auto_stack(item_texture: Texture, count: int = 1) -> int:
	"""Add item to inventory with auto-stacking. Returns remaining count that couldn't be added."""
	if not item_texture:
		return count

	var remaining = count

	# First pass: Try to add to existing stacks
	for i in range(max_inventory_slots):
		if remaining <= 0:
			break

		var slot_data = inventory_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == item_texture and slot_data["count"] > 0:
			var space = MAX_INVENTORY_STACK - slot_data["count"]
			var add_amount = mini(remaining, space)
			slot_data["count"] += add_amount
			inventory_slots[i] = slot_data
			remaining -= add_amount

	# Second pass: Use empty slots for remaining items
	for i in range(max_inventory_slots):
		if remaining <= 0:
			break

		var slot_data = inventory_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			var add_amount = mini(remaining, MAX_INVENTORY_STACK)
			inventory_slots[i] = {"texture": item_texture, "count": add_amount, "weight": 0.0}
			remaining -= add_amount

	# Update UI
	sync_inventory_ui()

	return remaining  # Return any overflow


# Add item to toolkit with auto-stacking
func add_item_to_toolkit_auto_stack(item_texture: Texture, count: int = 1) -> int:
	"""Add item to toolkit with auto-stacking. Returns remaining count that couldn't be added."""
	if not item_texture:
		return count

	var remaining = count

	# First pass: Try to add to existing stacks
	for i in range(max_toolkit_slots):
		if remaining <= 0:
			break

		var slot_data = toolkit_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == item_texture and slot_data["count"] > 0:
			var space = MAX_TOOLBELT_STACK - slot_data["count"]
			var add_amount = mini(remaining, space)
			slot_data["count"] += add_amount
			toolkit_slots[i] = slot_data
			remaining -= add_amount

	# Second pass: Use empty slots for remaining items
	for i in range(max_toolkit_slots):
		if remaining <= 0:
			break

		var slot_data = toolkit_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			var add_amount = mini(remaining, MAX_TOOLBELT_STACK)
			toolkit_slots[i] = {"texture": item_texture, "count": add_amount, "weight": 0.0}
			remaining -= add_amount

	# Update UI
	sync_toolkit_ui()

	return remaining  # Return any overflow


func get_first_empty_slot() -> int:
	for i in range(inventory_slots.size()):
		var slot_data = inventory_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			return i
	return -1


# Remove an item from the inventory
func remove_item(slot_index: int) -> void:
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = {"texture": null, "count": 0, "weight": 0.0}


# Get an item texture from the inventory
func get_item(slot_index: int) -> Texture:
	var slot_data = inventory_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	return slot_data["texture"]


# Get item count from inventory slot
func get_item_count(slot_index: int) -> int:
	var slot_data = inventory_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	return slot_data["count"]


# Remove an item from inventory (for drag/drop)
func remove_item_from_inventory(slot_index: int) -> void:
	"""Remove item from inventory slot (used when dragging to toolkit)"""
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
		sync_inventory_ui()


# Instantiate the inventory UI and add it to the current scene tree
func instantiate_inventory_ui(parent_node: Node = null) -> void:
	if inventory_instance:  # Prevent duplicates
		return

	if not inventory_scene:
		return

	inventory_instance = inventory_scene.instantiate() as Control
	if not inventory_instance:
		return

	# Adding inventory instance to the specified parent node or the root node
	if parent_node:
		parent_node.add_child(inventory_instance)
	else:
		get_tree().root.add_child(inventory_instance)

	inventory_instance.visible = false

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


func add_item_to_first_empty_slot(item_data: Resource) -> bool:
	# Iterate over the slots in the inventory
	for slot_index in inventory_slots.keys():
		var slot_data = inventory_slots.get(
			slot_index, {"texture": null, "count": 0, "weight": 0.0}
		)
		if slot_data["texture"] == null or slot_data["count"] == 0:  # Check if the slot is empty
			#print("Found empty slot: ", slot_index)
			inventory_slots[slot_index] = {"texture": item_data.texture, "count": 1, "weight": 0.0}
			#print("Item added to slot: ", slot_index, " Item ID: ", item_data.item_id)
			sync_inventory_ui()  # Trigger UI update
			return true
	return false


#	Functions for the inventory panel
func update_inventory_slots(slot_index: int, item_texture: Texture, count: int = 1) -> void:
	if slot_index < 0 or slot_index >= max_inventory_slots:
		return

	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = {"texture": item_texture, "count": count, "weight": 0.0}


func sync_inventory_ui() -> void:
	if not inventory_instance:
		return

	# Try multiple possible paths for the GridContainer
	# Path 1: Standalone inventory (old system)
	var grid_container = inventory_instance.get_node_or_null("CenterContainer/GridContainer")

	# Path 2: Pause menu inventory (new system)
	if not grid_container:
		grid_container = inventory_instance.get_node_or_null("InventoryGrid")

	# Path 3: Check if inventory_instance IS the GridContainer
	if not grid_container and inventory_instance is GridContainer:
		grid_container = inventory_instance

	if not grid_container:
		return

	# Sync slots with inventory dictionary
	for i in range(inventory_slots.size()):
		if i >= grid_container.get_child_count():
			break  # Stop if we exceed the available slots in GridContainer

		var slot = grid_container.get_child(i)  # Get slot by index
		if slot and slot is TextureButton:
			var slot_data = inventory_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
			var item_texture = slot_data["texture"]
			var item_count = slot_data["count"]

			# Update slot with texture and count
			if slot.has_method("set_item"):
				slot.set_item(item_texture, item_count)
			else:
				slot.texture_normal = item_texture if item_texture != null else null


# Toolkit tracking functions for drag/drop
func add_item_from_toolkit(slot_index: int, texture: Texture, count: int = 1) -> bool:
	"""Add item to inventory from toolkit slot"""
	if slot_index < 0 or slot_index >= max_inventory_slots:
		return false

	inventory_slots[slot_index] = {"texture": texture, "count": count, "weight": 0.0}
	sync_inventory_ui()
	return true


func remove_item_from_toolkit(slot_index: int) -> void:
	"""Remove item from toolkit slot (used when dragging to inventory)"""
	if toolkit_slots.has(slot_index):
		toolkit_slots[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
		sync_toolkit_ui()


func get_toolkit_item(slot_index: int) -> Texture:
	"""Get item texture from toolkit slot"""
	var slot_data = toolkit_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	return slot_data["texture"]


func get_toolkit_item_count(slot_index: int) -> int:
	"""Get item count from toolkit slot"""
	var slot_data = toolkit_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	return slot_data["count"]


func add_item_to_toolkit(slot_index: int, texture: Texture, count: int = 1) -> bool:
	"""Add item to toolkit slot (used when dragging from inventory)"""

	if slot_index < 0 or slot_index >= max_toolkit_slots:
		return false

	toolkit_slots[slot_index] = {"texture": texture, "count": count, "weight": 0.0}
	return true


func sync_toolkit_ui(hud_instance: Node = null) -> void:
	"""Sync toolkit UI with toolkit_slots dictionary"""
	if not hud_instance:
		# Try to find HUD CanvasLayer in scene tree
		# The hud.tscn is instantiated as "Hud" (Node), which contains "HUD" (CanvasLayer)
		var hud_root = _find_hud_root(get_tree().root)
		if hud_root:
			hud_instance = hud_root.get_node_or_null("HUD")

		if not hud_instance:
			return

	# Use GameConfig for toolkit slot count
	var hud_slot_count: int = max_toolkit_slots
	if game_config:
		hud_slot_count = game_config.hud_slot_count

	# Access the HBoxContainer for toolkit slots
	var slots_container = hud_instance.get_node_or_null("MarginContainer/HBoxContainer")
	if not slots_container:
		return

	# Sync toolkit slots with UI
	for i in range(hud_slot_count):
		if i >= slots_container.get_child_count():
			break

		var texture_button = slots_container.get_child(i)
		if texture_button and texture_button is TextureButton:
			var slot_data = toolkit_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
			var item_texture = slot_data["texture"]
			var item_count = slot_data["count"]

			# Update the TextureButton itself (which is the hud_slot)
			if texture_button.has_method("set_item"):
				texture_button.set_item(item_texture, item_count)
			else:
				# Fallback: update child TextureRect
				var hud_slot = texture_button.get_node_or_null("Hud_slot_" + str(i))
				if hud_slot:
					if hud_slot.has_method("set_item"):
						hud_slot.set_item(item_texture, item_count)
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
		var slot_path = (
			"HUD/MarginContainer/HBoxContainer/TextureButton_" + str(i) + "/Hud_slot_" + str(i)
		)
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
	return false


# Assign textures to the UI slots
func assign_textures_to_slots() -> void:
	if not inventory_instance:
		return

	var grid_container = inventory_instance.get_node_or_null("CenterContainer/GridContainer")
	if not grid_container:
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
			print(
				"Warning: Unexpected node found in inventory slots. Expected 'TextureButton'. Node name:",
				slot.name
			)


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
func _find_hud_root(node: Node) -> Node:
	"""Recursively search for Hud Node (root of hud.tscn)"""
	if not node:
		return null
	# Look for a Node named "Hud" that has a CanvasLayer child named "HUD"
	if node.name == "Hud" and node is Node:
		# Verify it has an "HUD" CanvasLayer child
		var hud_child = node.get_node_or_null("HUD")
		if hud_child and hud_child is CanvasLayer:
			return node

	# Recursively check children
	for child in node.get_children():
		var result = _find_hud_root(child)
		if result:
			return result
	return null


func _sync_initial_toolkit_from_ui() -> void:
	"""Read initial tools from HUD scene and populate toolkit_slots dictionary"""
	var hud_root = _find_hud_root(get_tree().root)
	if not hud_root:
		return

	var hud_canvas = hud_root.get_node_or_null("HUD")
	if not hud_canvas:
		return

	var slots_container = hud_canvas.get_node_or_null("MarginContainer/HBoxContainer")
	if not slots_container:
		return

	# Read each toolkit slot from the UI
	for i in range(min(max_toolkit_slots, slots_container.get_child_count())):
		var texture_button = slots_container.get_child(i)
		if texture_button and texture_button is TextureButton:
			# Try to get the texture from the slot
			var slot_texture: Texture = null

			# Check if the button has get_item method
			if texture_button.has_method("get_item"):
				slot_texture = texture_button.get_item()
			else:
				# Fallback: check child TextureRect
				var hud_slot = texture_button.get_node_or_null("Hud_slot_" + str(i))
				if hud_slot and hud_slot is TextureRect:
					slot_texture = hud_slot.texture

			# Populate toolkit_slots with the found texture
			if slot_texture:
				toolkit_slots[i] = {"texture": slot_texture, "count": 1, "weight": 0.0}

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
