extends Control

@export var grid_container_path: NodePath  # Path to GridContainer
@export var slot_size: Vector2 = Vector2(64, 64)  # Default slot size

var is_open: bool = false  # Tracks if the inventory is open
var slots: Array  # Stores references to slot nodes

func _ready() -> void:
	var grid_container = get_node_or_null(grid_container_path)
	if not grid_container:
		return
	
	slots = grid_container.get_children()
	visualize_inventory()
	#debug_z_indexes_on_screen()

func visualize_inventory() -> void:
	if InventoryManager:
		for slot in slots:
			if slot is TextureButton:
				var slot_index = slots.find(slot)
				var item_texture = InventoryManager.get_item(slot_index)
				slot.texture_normal = item_texture if item_texture else null
			else:
				print("Unexpected node in inventory slots:", slot.name)


# Debug z-indexes starting from a given node
#func debug_z_indexes_on_screen(node: Node = null, indent: int = 0) -> void:
	#if node == null:
		#node = self  # Start from the inventory scene root
#
	#if node is CanvasItem:
		#var z_index = node.z_index if node.has_method("z_index") else "N/A"
		#var debug_text = "%sNode: %s, z_index: %s\n" % [" ".repeat(indent), node.name, z_index]
		#print(debug_text)  # For console debugging
#
	##for child in node.get_children():
		##debug_z_indexes_on_screen(child, indent + 2)  # Recursive call for child nodes
