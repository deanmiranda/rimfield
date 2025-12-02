extends Node

# ChestManager - Manages all chests in the game, handles registration, inventory, and persistence
# Chest registry: chest_id: String → {"node": Chest, "inventory": Dictionary, "position": Vector2}

var chest_registry: Dictionary = {}
var chest_id_counter: int = 0
var pending_restore_data: Array = [] # Store chest data to restore when chests are instantiated

# Make pending_restore_data accessible for farm scene restoration
func get_pending_restore_data() -> Array:
	return pending_restore_data

const CHEST_INVENTORY_SIZE: int = 24
const MAX_INVENTORY_STACK: int = 99


func _ready() -> void:
	# Initialize empty registry
	chest_registry = {}


func register_chest(chest: Node) -> String:
	"""Register a chest and assign it a unique ID. Returns the chest_id."""
	if not chest:
		push_error("ChestManager: Cannot register null chest")
		return ""
	
	# Check if chest already has an ID (from save/load)
	var chest_id: String = ""
	if chest.has_method("get_chest_id"):
		chest_id = chest.get_chest_id()
	
	# If no ID, generate a new one
	if chest_id == "":
		chest_id_counter += 1
		chest_id = "chest_%d" % chest_id_counter
	
	# Initialize chest inventory if not already set
	var inventory: Dictionary = {}
	if not chest_registry.has(chest_id):
		# Initialize 24 empty slots
		for i in range(CHEST_INVENTORY_SIZE):
			inventory[i] = {"texture": null, "count": 0, "weight": 0.0}
	else:
		# Use existing inventory from registry
		inventory = chest_registry[chest_id].get("inventory", {})
	
	# Get chest position
	var position: Vector2 = chest.global_position if chest is Node2D else Vector2.ZERO
	
	# Register chest
	chest_registry[chest_id] = {
		"node": chest,
		"inventory": inventory,
		"position": position
	}
	
	# Set chest ID on the chest node
	if chest.has_method("set_chest_id"):
		chest.set_chest_id(chest_id)
	
	# Check if there's pending restore data for this chest
	_restore_chest_if_pending(chest_id)
	
	return chest_id


func get_chest_inventory(chest_id: String) -> Dictionary:
	"""Get the inventory dictionary for a chest. Returns empty dict if chest not found."""
	if not chest_registry.has(chest_id):
		push_error("ChestManager: Chest ID not found: %s" % chest_id)
		return {}
	
	return chest_registry[chest_id].get("inventory", {})


func update_chest_inventory(chest_id: String, inventory: Dictionary) -> void:
	"""Update the inventory for a chest."""
	if not chest_registry.has(chest_id):
		push_error("ChestManager: Cannot update inventory for unknown chest: %s" % chest_id)
		return
	
	chest_registry[chest_id]["inventory"] = inventory
	
	# Also update position if chest node exists
	var chest_node = chest_registry[chest_id].get("node")
	if chest_node and chest_node is Node2D:
		chest_registry[chest_id]["position"] = chest_node.global_position


func serialize_all_chests() -> Array:
	"""Serialize all chests for save. Returns array of chest data dictionaries."""
	var chest_data_array: Array = []
	
	for chest_id in chest_registry.keys():
		var chest_data = chest_registry[chest_id]
		var chest_node = chest_data.get("node")
		var inventory = chest_data.get("inventory", {})
		var position = chest_data.get("position", Vector2.ZERO)
		
		# Convert inventory to save format
		var inventory_array: Array = []
		for slot_index in range(CHEST_INVENTORY_SIZE):
			var slot_data = inventory.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
			if slot_data["texture"] and slot_data["count"] > 0:
				var texture_path = slot_data["texture"].resource_path if slot_data["texture"] else ""
				if texture_path != "":
					inventory_array.append({
						"slot_index": slot_index,
						"texture_path": texture_path,
						"count": slot_data["count"],
						"weight": slot_data.get("weight", 0.0)
					})
		
		# Only save chest if it has items or if node still exists
		if inventory_array.size() > 0 or (chest_node and is_instance_valid(chest_node)):
			chest_data_array.append({
				"chest_id": chest_id,
				"position": {"x": position.x, "y": position.y},
				"inventory": inventory_array
			})
	
	return chest_data_array


func restore_chests_from_save(chest_data: Array) -> void:
	"""Restore chests from save data. Stores data temporarily until chests are registered."""
	pending_restore_data = chest_data
	
	# Try to restore any already-registered chests
	for chest_id in chest_registry.keys():
		_restore_chest_if_pending(chest_id)


func _restore_chest_if_pending(chest_id: String) -> void:
	"""Restore a chest's inventory if there's pending restore data for it."""
	for chest_save_data in pending_restore_data:
		if chest_save_data.get("chest_id") == chest_id:
			# Found matching chest - restore inventory
			var inventory: Dictionary = {}
			# Initialize empty slots
			for i in range(CHEST_INVENTORY_SIZE):
				inventory[i] = {"texture": null, "count": 0, "weight": 0.0}
			
			# Restore items from save data
			var inventory_array = chest_save_data.get("inventory", [])
			for item_data in inventory_array:
				var slot_index = item_data.get("slot_index", -1)
				var texture_path = item_data.get("texture_path", "")
				var count = item_data.get("count", 1)
				var weight = item_data.get("weight", 0.0)
				
				if slot_index >= 0 and slot_index < CHEST_INVENTORY_SIZE and texture_path != "":
					var texture = load(texture_path)
					if texture:
						inventory[slot_index] = {"texture": texture, "count": count, "weight": weight}
			
			# Update chest registry
			if chest_registry.has(chest_id):
				chest_registry[chest_id]["inventory"] = inventory
				
				# Notify chest node to update its UI if it has a method for that
				var chest_node = chest_registry[chest_id].get("node")
				if chest_node and chest_node.has_method("on_inventory_restored"):
					chest_node.on_inventory_restored()
			
			# Remove from pending restore data
			pending_restore_data.erase(chest_save_data)
			break


func create_chest_at_position(pos: Vector2) -> Node:
	"""Create a new chest at the specified position. Returns the chest node."""
	print("[ChestManager] create_chest_at_position called with pos: ", pos)
	
	var chest_scene = preload("res://scenes/world/chest.tscn")
	if not chest_scene:
		print("[ChestManager] ERROR: Could not load chest scene")
		push_error("ChestManager: Could not load chest scene")
		return null
	
	var chest_instance = chest_scene.instantiate()
	if not chest_instance:
		print("[ChestManager] ERROR: Could not instantiate chest scene")
		push_error("ChestManager: Could not instantiate chest scene")
		return null
	
	print("[ChestManager] Chest instance created: ", chest_instance)
	
	# Set position
	if chest_instance is Node2D:
		chest_instance.global_position = pos
		print("[ChestManager] Set chest position to: ", chest_instance.global_position)
	else:
		print("[ChestManager] WARNING: Chest instance is not Node2D")
	
	# Add to current scene (works for both FarmScene and HouseScene)
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(chest_instance)
	else:
		print("[ChestManager] ERROR: No scene to add chest to!")
		return null
	
	print("[ChestManager] Chest added to scene tree, will register in _ready()")
	# Chest will register itself in _ready()
	return chest_instance


func get_chest_by_id(chest_id: String) -> Node:
	"""Get a chest node by its ID. Returns null if not found."""
	if chest_registry.has(chest_id):
		return chest_registry[chest_id].get("node")
	return null


func unregister_chest(chest_id: String) -> void:
	"""Unregister a chest (e.g., when it's destroyed)."""
	if chest_registry.has(chest_id):
		chest_registry.erase(chest_id)
