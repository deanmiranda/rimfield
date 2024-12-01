extends Control

# Tracks if the inventory is open or closed
var is_open: bool = false

# Reference to slots in the inventory
var slots: Array

func _ready() -> void:
	# Initially hide the inventory
	self.visible = false
	# Get references to all the button nodes (slots) in the grid container
	slots = $GridContainer.get_children()

# Function to toggle inventory visibility
func toggle_inventory() -> void:
	is_open = !is_open
	self.visible = is_open
	if is_open:
		print("Inventory opened.")
	else:
		print("Inventory closed.")

# Function to add an item to the first empty slot
func add_item(item_id: int) -> bool:
	# Check for an empty slot in the inventory and add the item
	for slot in slots:
		if slot.slot_index == -1:
			slot.slot_index = item_id
			slot.text = "Item: %d" % item_id  # Update button text to indicate it now holds an item
			print("Added item %d to inventory." % item_id)
			return true
	print("Inventory is full! Cannot add item %d." % item_id)
	return false

# Swap item positions between two slots
func swap_items(slot_a, slot_b) -> void:
	# Swap slot_index values and update the text
	var temp_index = slot_a.slot_index
	slot_a.slot_index = slot_b.slot_index
	slot_b.slot_index = temp_index

	# Update button text to reflect item movement
	slot_a.text = "Item: %d" % slot_a.slot_index if slot_a.slot_index != -1 else ""
	slot_b.text = "Item: %d" % slot_b.slot_index if slot_b.slot_index != -1 else ""

# Function to handle dragging and dropping of items
func handle_dragged_item(source_slot_index: int, target_slot) -> void:
	# Ensure target_slot is valid and we’re not dropping onto the same slot
	if target_slot.slot_index == source_slot_index:
		return

	# Swap the item positions
	swap_items(slots[source_slot_index], target_slot)

func _process(delta: float) -> void:
	# Detect if the 'i' key is pressed to toggle the inventory
	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()
