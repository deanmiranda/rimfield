extends Node

# ChestManager - Manages all chests in the game, handles registration, inventory, and persistence
# Chest registry: chest_id: String → {"node": Chest, "inventory": Dictionary, "position": Vector2, "scene_name": String}

var chest_registry: Dictionary = {}
var chest_id_counter: int = 0
var pending_restore_data: Array = [] # Store chest data to restore when chests are instantiated

# Make pending_restore_data accessible for farm scene restoration
func get_pending_restore_data() -> Array:
	return pending_restore_data


func restore_chests_for_scene(scene_name: String) -> void:
	"""Restore chests for a specific scene when it loads."""
	if not scene_name:
		return
	
	# Get chest scene
	var chest_scene = load("res://scenes/world/chest.tscn")
	if not chest_scene:
		push_error("ChestManager: Could not load chest scene")
		return
	
	# Find chests for this scene in the registry
	for chest_id in chest_registry.keys():
		var chest_data = chest_registry[chest_id]
		var saved_scene_name = chest_data.get("scene_name", "")
		
		# Only restore if this chest belongs to the current scene and doesn't have a node
		if saved_scene_name == scene_name and not chest_data.get("node"):
			var position = chest_data.get("position", Vector2.ZERO)
			
			# Create chest at position
			var chest_instance = create_chest_at_position(position)
			if chest_instance and chest_instance.has_method("set_chest_id"):
				chest_instance.set_chest_id(chest_id)


func _get_current_scene_name() -> String:
	"""Get the current scene name for tracking which scene the chest belongs to."""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.name
	return ""

const CHEST_INVENTORY_SIZE: int = 24
const MAX_INVENTORY_STACK: int = 99


func _ready() -> void:
	# Initialize empty registry
	chest_registry = {}


func reset_all() -> void:
	"""Reset all chest data (for new game)."""
	# Remove all chest nodes from scene
	for chest_id in chest_registry.keys():
		var chest_data = chest_registry[chest_id]
		var chest_node = chest_data.get("node")
		if chest_node and is_instance_valid(chest_node):
			if chest_node.get_parent():
				chest_node.get_parent().remove_child(chest_node)
			chest_node.queue_free()
	
	# Clear registries
	chest_registry = {}
	pending_restore_data = []
	chest_id_counter = 0
	print("[ChestManager] Reset complete - all chests cleared")


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
	
	# Get scene name
	var scene_name = _get_current_scene_name()
	
	# Register chest
	chest_registry[chest_id] = {
		"node": chest,
		"inventory": inventory,
		"position": position,
		"scene_name": scene_name
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
			var scene_name = chest_data.get("scene_name", "")
			chest_data_array.append({
				"chest_id": chest_id,
				"position": {"x": position.x, "y": position.y},
				"scene_name": scene_name,
				"inventory": inventory_array
			})
	
	return chest_data_array


func restore_chests_from_save(chest_data: Array) -> void:
	"""Restore chests from save data. Stores chest data in registry for scene restoration."""
	pending_restore_data = chest_data
	
	# Add chest data to registry (without nodes yet - those will be created when scenes load)
	for save_data in chest_data:
		var chest_id = save_data.get("chest_id", "")
		var position_data = save_data.get("position", {"x": 0, "y": 0})
		var position = Vector2(position_data["x"], position_data["y"])
		var scene_name = save_data.get("scene_name", "")
		
		# Convert inventory array to dictionary
		var inventory: Dictionary = {}
		for i in range(CHEST_INVENTORY_SIZE):
			inventory[i] = {"texture": null, "count": 0, "weight": 0.0}
		
		var inventory_array = save_data.get("inventory", [])
		for item_data in inventory_array:
			var slot_index = item_data.get("slot_index", -1)
			var texture_path = item_data.get("texture_path", "")
			var count = item_data.get("count", 1)
			var weight = item_data.get("weight", 0.0)
			
			if slot_index >= 0 and slot_index < CHEST_INVENTORY_SIZE and texture_path != "":
				var texture = load(texture_path)
				if texture:
					inventory[slot_index] = {"texture": texture, "count": count, "weight": weight}
		
		# Store in registry (without node - will be created when scene loads)
		chest_registry[chest_id] = {
			"node": null,
			"inventory": inventory,
			"position": position,
			"scene_name": scene_name
		}


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


func find_chest_at_position(world_pos: Vector2, radius: float = 8.0) -> Node:
	"""Find a chest near the given world position. Returns chest node or null."""
	for chest_id in chest_registry.keys():
		var chest_data = chest_registry[chest_id]
		var chest_node = chest_data.get("node")
		
		if chest_node and is_instance_valid(chest_node):
			var chest_pos = chest_node.global_position if chest_node is Node2D else Vector2.ZERO
			var distance = chest_pos.distance_to(world_pos)
			
			if distance <= radius:
				return chest_node
	
	return null


func remove_chest_and_spawn_drop(chest_node: Node, hud: Node) -> bool:
	"""Remove a chest from the world and spawn a droppable. Returns true if successful."""
	if not chest_node:
		return false
	
	# Get chest ID
	var chest_id: String = ""
	if chest_node.has_method("get_chest_id"):
		chest_id = chest_node.get_chest_id()
	
	if chest_id.is_empty():
		print("[CHEST PICKAXE] ERROR: Chest has no ID")
		return false
	
	# Check if chest is empty
	var inventory = get_chest_inventory(chest_id)
	var is_empty = true
	for slot_index in range(CHEST_INVENTORY_SIZE):
		var slot_data = inventory.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] != null and slot_data["count"] > 0:
			is_empty = false
			break
	
	if not is_empty:
		print("[CHEST PICKAXE] BLOCKED: Chest is not empty")
		# Play shake animation if chest has that method
		if chest_node.has_method("_shake_animation"):
			chest_node._shake_animation()
		return false
	
	# Get chest position before removing
	var chest_pos = chest_node.global_position if chest_node is Node2D else Vector2.ZERO
	
	print("[CHEST PICKAXE] Removing chest and spawning droppable at pos=%s" % [chest_pos])
	
	# Unregister from ChestManager
	unregister_chest(chest_id)
	
	# Remove from scene
	if chest_node.get_parent():
		chest_node.get_parent().remove_child(chest_node)
	chest_node.queue_free()
	
	# Spawn droppable
	if DroppableFactory and hud:
		var chest_texture = load("res://assets/icons/chest_icon.png")
		print("[CHEST PICKAXE] chest_texture loaded: ", chest_texture.resource_path if chest_texture else "null")
		var droppable = DroppableFactory.spawn_droppable_from_texture(chest_texture, chest_pos, hud, Vector2.ZERO)
		if droppable:
			print("[CHEST PICKAXE] Droppable spawned successfully at: ", droppable.global_position)
			print("[CHEST PICKAXE] Droppable is in groups: ", droppable.get_groups())
			print("[CHEST PICKAXE] Droppable has item_data: ", droppable.item_data != null)
		else:
			push_error("[CHEST PICKAXE] ERROR: spawn_droppable_from_texture returned null!")
			push_error("[CHEST PICKAXE] Available item_ids: " + str(DroppableFactory.droppable_item_resources.keys()))
	
	return true
