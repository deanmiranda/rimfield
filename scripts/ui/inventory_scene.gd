extends Control

# Tracks if the inventory is open or closed
var is_open: bool = false

# Reference to slots in the inventory
var slots: Array
var inventory_scene: PackedScene = preload("res://scenes/ui/inventory_scene.tscn")

func _ready() -> void:
	# Reference the GridContainer within the inventory
	var grid_container = get_node_or_null("CenterContainer/GridContainer")
	if not grid_container:
		print("GridContainer node not found in inventory scene!")
		return

	slots = grid_container.get_children()

	# Connect slot signals properly
	for slot in slots:
		if slot.has_signal("can_drop_data") and slot.has_signal("drop_data"):
			if not slot.is_connected("can_drop_data", Callable(self, "_on_can_drop_data")):
				slot.connect("can_drop_data", Callable(self, "_on_can_drop_data"))
			if not slot.is_connected("drop_data", Callable(self, "_on_drop_data")):
				slot.connect("drop_data", Callable(self, "_on_drop_data"))

# Function to toggle inventory visibility
func toggle_inventory() -> void:
	is_open = !is_open
	self.visible = is_open

	# Explicitly calculate and set the position to be centered
	var viewport_size = get_viewport().get_visible_rect().size
	self.rect_position = Vector2(
		viewport_size.x / 2 - self.rect_size.x / 2,
		viewport_size.y / 2 - self.rect_size.y / 2
	)

	if is_open:
		print("Inventory opened. Visibility:", self.visible, " Position:", self.rect_position, " Size:", self.rect_size, " Viewport Size:", viewport_size)
	else:
		print("Inventory closed. Visibility:", self.visible, " Position:", self.rect_position, " Size:", self.rect_size, " Viewport Size:", viewport_size)


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

# Handle drop data to execute swapping of items
func _on_drop_data(position: Vector2, data) -> void:
	var source_slot = slots[data["slot_index"]]
	var target_slot = slots.find(position)
	if target_slot:
		swap_items(source_slot, target_slot)

# Placeholder for the can_drop_data function (to avoid runtime errors)
func _on_can_drop_data(position: Vector2, data) -> bool:
	# Logic to determine if an item can be dropped here
	return true
