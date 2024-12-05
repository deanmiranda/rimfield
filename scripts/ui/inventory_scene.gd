extends Control

@export var grid_container_path: NodePath  # Path to GridContainer
@export var slot_size: Vector2 = Vector2(64, 64)  # Default slot size
@onready var debug_label: TextEdit = $DebugLabel

var is_open: bool = false  # Tracks if the inventory is open
var slots: Array  # Stores references to slot nodes

func _ready() -> void:
	var grid_container = get_node_or_null(grid_container_path)
	if not grid_container:
		print("GridContainer node not found in inventory scene!")
		return
	
	slots = grid_container.get_children()
	visualize_inventory()

	# Initialize debug label
	if debug_label:
		debug_label.text = "Debug initialized.\n"
		debug_label.z_index = 1000
		debug_label.visible = true
	else:
		append_debug_message("DebugLabel node not found or inaccessible.", true)

	debug_z_indexes_on_screen()

func open_inventory() -> void:
	is_open = true
	visualize_inventory()
	print("Inventory opened. Triggering z-index debug...")
	debug_z_indexes_on_screen()  # Trigger debug method
	print("Z-index debug process completed.")
	
func visualize_inventory() -> void:
	if InventoryManager:
		for slot in slots:
			if slot is TextureButton:
				var slot_index = slots.find(slot)
				var item_texture = InventoryManager.get_item(slot_index)
				slot.texture_normal = item_texture if item_texture else null
			else:
				print("Unexpected node in inventory slots:", slot.name)

# Append debug information to the label
func append_debug_message(message: String, is_error: bool = false) -> void:
	if debug_label:
		var prefix = "[ERROR] " if is_error else "[DEBUG] "
		var formatted_message = prefix + message
		debug_label.text += formatted_message + "\n"
		debug_label.queue_redraw()
		print(formatted_message)  # Also print to console for convenience
	else:
		print("DebugLabel node is missing! Message:", message)

# Debug z-indexes starting from a given node
func debug_z_indexes_on_screen(node: Node = null, indent: int = 0) -> void:
	if node == null:
		node = self  # Start from the inventory scene root

	print("Inspecting node:", node.name)  # Log the node being inspected
	
	if node is CanvasItem:
		var z_index = node.z_index if node.has_method("z_index") else "N/A"
		var debug_text = "%sNode: %s, z_index: %s\n" % [" ".repeat(indent), node.name, z_index]
		append_debug_message(debug_text)
		print(debug_text)  # For console debugging

	for child in node.get_children():
		debug_z_indexes_on_screen(child, indent + 2)  # Recursive call for child nodes
