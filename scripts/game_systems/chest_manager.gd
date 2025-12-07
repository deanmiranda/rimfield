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
			
			# Create chest at position with existing chest_id
			# CRITICAL: Pass chest_id so it's set BEFORE adding to scene tree
			# This ensures register_chest() uses the existing ID and restores inventory
			create_chest_at_position(position, chest_id)


func _get_current_scene_name() -> String:
	"""Get the current scene name for tracking which scene the chest belongs to."""
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.name
	return ""

const CHEST_INVENTORY_SIZE: int = 36
const MAX_INVENTORY_STACK: int = 99


func _ready() -> void:
	# Registry is already initialized at class level (line 6)
	# Do NOT clear it here - that would wipe saved data during scene rebuilds on load_game()
	# Only reset_all() should clear the registry (for new_game())
	pass


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


func register_chest(chest: Node) -> String:
	"""Register a chest and assign it a unique ID. Returns the chest_id."""
	if not chest:
		push_error("ChestManager: Cannot register null chest")
		return ""
	
	# Check if chest already has an ID (from save/load)
	var chest_id: String = ""
	if chest.has_method("get_chest_id"):
		chest_id = chest.get_chest_id()
	
	# If no ID, check if a chest at this position already exists in registry
	# This helps restore chests when ID wasn't set before _ready() ran
	if chest_id == "":
		var position: Vector2 = chest.global_position if chest is Node2D else Vector2.ZERO
		var scene_name = _get_current_scene_name()
		
		# Check for existing chest at same position in same scene
		for existing_id in chest_registry.keys():
			var existing_data = chest_registry[existing_id]
			var existing_pos = existing_data.get("position", Vector2.ZERO)
			var existing_scene = existing_data.get("scene_name", "")
			
			# Match if position is very close (within 1 pixel) and same scene
			if existing_pos.distance_to(position) < 1.0 and existing_scene == scene_name:
				# Found existing chest - reuse its ID
				chest_id = existing_id
				print("[ChestManager] Matched chest by position: %s at %s (scene: %s)" % [chest_id, position, scene_name])
				break
		
		# If still no ID, generate new one
		if chest_id == "":
			chest_id_counter += 1
			chest_id = "chest_%d" % chest_id_counter
	
	# Initialize chest inventory if not already set
	var inventory: Dictionary = {}
	if not chest_registry.has(chest_id):
		# Initialize empty slots for new chest
		for i in range(CHEST_INVENTORY_SIZE):
			inventory[i] = {"texture": null, "count": 0, "weight": 0.0}
		print("[ChestManager] Registering new chest: %s (no existing registry entry)" % chest_id)
	else:
		# Use existing inventory from registry (preserves saved inventory from restore_chests_from_save)
		var existing_data = chest_registry[chest_id]
		var existing_inventory = existing_data.get("inventory", {})
		
		# Count items in existing inventory for logging
		var item_count = 0
		for i in range(CHEST_INVENTORY_SIZE):
			if existing_inventory.has(i):
				var slot_data = existing_inventory[i]
				if slot_data.get("texture") != null and slot_data.get("count", 0) > 0:
					item_count += 1
		
		print("[ChestManager] Registering existing chest: %s (registry has %d items)" % [chest_id, item_count])
		
		# CRITICAL: Deep copy the inventory to avoid reference issues
		# If we use a reference, changes elsewhere could affect the registry
		# This is especially important during scene rebuilds on load_game()
		inventory = {}
		for i in range(CHEST_INVENTORY_SIZE):
			if existing_inventory.has(i):
				var slot_data = existing_inventory[i]
				inventory[i] = {
					"texture": slot_data.get("texture"),
					"count": slot_data.get("count", 0),
					"weight": slot_data.get("weight", 0.0)
				}
			else:
				inventory[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	# Get chest position
	var position: Vector2 = chest.global_position if chest is Node2D else Vector2.ZERO
	
	# Get scene name
	var scene_name = _get_current_scene_name()
	
	chest_registry[chest_id] = {
		"node": chest,
		"inventory": inventory,
		"position": position,
		"scene_name": scene_name
	}
	
	# Set chest ID on the chest node
	if chest.has_method("set_chest_id"):
		chest.set_chest_id(chest_id)
	
	# Check if there's pending restore data for this chest (restores inventory if needed)
	# This should only run if inventory wasn't already restored from registry
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
	
	# CRITICAL: Deep copy the inventory dictionary to avoid reference issues
	# If we just assign the dictionary, changes to the source will affect the registry
	var inventory_copy: Dictionary = {}
	for i in range(CHEST_INVENTORY_SIZE):
		if inventory.has(i):
			var slot_data = inventory[i]
			inventory_copy[i] = {
				"texture": slot_data.get("texture"),
				"count": slot_data.get("count", 0),
				"weight": slot_data.get("weight", 0.0)
			}
		else:
			inventory_copy[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	chest_registry[chest_id]["inventory"] = inventory_copy
	
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
			slot_index = int(slot_index)
			var texture_path = item_data.get("texture_path", "")
			var count = item_data.get("count", 1)
			var weight = item_data.get("weight", 0.0)
			
			if slot_index >= 0 and slot_index < CHEST_INVENTORY_SIZE and texture_path != "":
				var texture = load(texture_path)
				if texture:
					var float_key = float(slot_index)
					if inventory.has(float_key):
						inventory.erase(float_key)
					inventory[slot_index] = {"texture": texture, "count": int(count), "weight": float(weight)}
		
		# Store in registry (without node - will be created when scene loads)
		chest_registry[chest_id] = {
			"node": null,
			"inventory": inventory,
			"position": position,
			"scene_name": scene_name
		}


func _restore_chest_if_pending(chest_id: String) -> void:
	"""Restore a chest's inventory if there's pending restore data for it."""
	# Check if chest already has inventory in registry (from restore_chests_from_save)
	# If so, don't overwrite it - it's already been restored
	if chest_registry.has(chest_id):
		var existing_inventory = chest_registry[chest_id].get("inventory", {})
		var has_items = false
		for slot_index in range(CHEST_INVENTORY_SIZE):
			var slot_data = existing_inventory.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
			if slot_data["texture"] != null and slot_data["count"] > 0:
				has_items = true
				break
		
		# If registry already has inventory with items, it was restored from save - don't overwrite
		if has_items:
			return
	
	# Otherwise, check pending_restore_data for this chest
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
				slot_index = int(slot_index)
				var texture_path = item_data.get("texture_path", "")
				var count = item_data.get("count", 1)
				var weight = item_data.get("weight", 0.0)
				
				if slot_index >= 0 and slot_index < CHEST_INVENTORY_SIZE and texture_path != "":
					var texture = load(texture_path)
					if texture:
						var float_key = float(slot_index)
						if inventory.has(float_key):
							inventory.erase(float_key)
						inventory[slot_index] = {"texture": texture, "count": int(count), "weight": float(weight)}
			
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


func create_chest_at_position(pos: Vector2, chest_id: String = "") -> Node:
	"""Create a new chest at the specified position. Returns the chest node.
	
	Args:
		pos: World position where the chest should be placed
		chest_id: Optional chest ID to set before adding to scene tree (prevents race condition)
	"""
	
	var chest_scene = preload("res://scenes/world/chest.tscn")
	if not chest_scene:
		push_error("ChestManager: Could not load chest scene")
		return null
	
	var chest_instance = chest_scene.instantiate()
	if not chest_instance:
		push_error("ChestManager: Could not instantiate chest scene")
		return null
	
	# Set position
	if chest_instance is Node2D:
		chest_instance.global_position = pos
	
	# CRITICAL: Set chest ID BEFORE adding to scene tree (so _ready() can use it)
	# This prevents register_chest() from generating a new ID when restoring existing chests
	if chest_id != "" and chest_instance.has_method("set_chest_id"):
		chest_instance.set_chest_id(chest_id)
	
	# Add to current scene (triggers _ready() which calls register_chest())
	# Works for both FarmScene and HouseScene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(chest_instance)
	else:
		return null
	
	# Chest will register itself in _ready() using the ID we set above
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
		# Play shake animation if chest has that method
		if chest_node.has_method("_shake_animation"):
			chest_node._shake_animation()
		return false
	
	# Get chest position before removing
	var chest_pos = chest_node.global_position if chest_node is Node2D else Vector2.ZERO
	
	
	# Unregister from ChestManager
	unregister_chest(chest_id)
	
	# Remove from scene
	if chest_node.get_parent():
		chest_node.get_parent().remove_child(chest_node)
	chest_node.queue_free()
	
	# Spawn droppable
	if DroppableFactory and hud:
		var chest_texture = load("res://assets/icons/chest_icon.png")
		var droppable = DroppableFactory.spawn_droppable_from_texture(chest_texture, chest_pos, hud, Vector2.ZERO)
		if droppable:
			print("[CHEST PICKAXE] Droppable has item_data: ", droppable.item_data != null)
		else:
			push_error("[CHEST PICKAXE] ERROR: spawn_droppable_from_texture returned null!")
			push_error("[CHEST PICKAXE] Available item_ids: " + str(DroppableFactory.droppable_item_resources.keys()))
	
	return true
