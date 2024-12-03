extends Control

@export var grid_container_path: NodePath  # Exported path for GridContainer
@export var slot_size: Vector2 = Vector2(64, 64)  # Default slot size to ensure visibility

# Tracks if the inventory is open or closed
var is_open: bool = false

# Reference to slots in the inventory
var slots: Array

func _ready() -> void:
	# Reference the GridContainer within the inventory
	var grid_container = get_node_or_null(grid_container_path)
	if not grid_container:
		print("GridContainer node not found in inventory scene!")
		return

	slots = grid_container.get_children()

	# Populate slots visually with the items from InventoryManager
	visualize_inventory()

# Visualize inventory items in the slots
func visualize_inventory() -> void:
	if InventoryManager:
		for slot in slots:
			if slot is TextureButton:
				var slot_index = slots.find(slot)
				var item_texture = InventoryManager.get_item(slot_index)
				if item_texture:
					slot.texture_normal = item_texture
					print("Setting texture for slot:", slot_index)
				else:
					slot.texture_normal = null  # Set to empty if no item
			else:
				print("Warning: Unexpected node found in inventory slots. Expected 'TextureButton'. Node name:", slot.name)
