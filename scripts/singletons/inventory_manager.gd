extends Node

# NEW SYSTEM: Container registry (ensures one instance per container type)
# CRITICAL: Initialize immediately, not in _ready(), so containers can register during their _ready()
var containers: Dictionary = {} # {container_id: ContainerBase instance}
var toolkit_container = null # Will be ToolkitContainer instance
var player_inventory_container = null # Will be PlayerInventoryContainer instance

# LEGACY SYSTEM: Data dictionaries (DEPRECATED - DO NOT USE IN NEW CODE)
# Only kept for one-time migration from old save files
# All new code MUST use containers instead
var legacy_mode_enabled: bool = false # Set to true ONLY during save file migration
var toolkit_slots: Dictionary = {} # LEGACY - DO NOT USE
var inventory_slots: Dictionary = {} # LEGACY - DO NOT USE

# Reference to the inventory UI scene and instance
@export var inventory_scene: PackedScene
var inventory_instance: Control = null

# Use GameConfig Resource instead of magic number (follows .cursor/rules/godot.md)
var game_config: Resource = null
var max_inventory_slots: int = 12 # Default inventory size (will be overridden by GameConfig)
var max_toolkit_slots: int = 10 # Default toolkit size (will be overridden by GameConfig)

# Stack limits
const MAX_TOOLBELT_STACK = 9
const MAX_INVENTORY_STACK = 99


func _ready() -> void:
	# Load GameConfig Resource
	game_config = load("res://resources/data/game_config.tres")
	if game_config:
		max_inventory_slots = game_config.inventory_slot_count
		max_toolkit_slots = game_config.hud_slot_count

	# CRITICAL: Don't clear containers dict - it may already have registrations
	# from containers created before this autoload's _ready() runs
	# This is because scene nodes can create containers before singletons finish initializing
	
	# LEGACY SYSTEM: Only initialize if legacy_mode_enabled (for migration)
	# NEW CODE: Use containers instead
	if legacy_mode_enabled:
		for i in range(max_inventory_slots):
			if not inventory_slots.has(i):
				inventory_slots[i] = {"texture": null, "count": 0, "weight": 0.0}
		
		for i in range(max_toolkit_slots):
			if not toolkit_slots.has(i):
				toolkit_slots[i] = {"texture": null, "count": 0, "weight": 0.0}

	
	# Bootstrap containers early to prevent startup crashes from early API calls
	call_deferred("_bootstrap_containers")


func register_container(container: ContainerBase) -> void:
	"""Register a container to ensure only one instance per ID exists"""
	if not container:
		push_error("[InventoryManager] Attempted to register null container!")
		return
	
	var container_id = container.container_id
	
	# Initialize containers dict if needed (safety check)
	if containers == null:
		containers = {}
	
	# Check for duplicates
	if containers.has(container_id):
		# Check if it's the SAME instance (reusing) vs a NEW instance (duplicate)
		if containers[container_id] == container:
			return
		else:
			push_error("❌ DUPLICATE CONTAINER REGISTERED: %s" % container_id)
			push_error("❌ Existing: %s" % containers[container_id])
			push_error("❌ New: %s" % container)
			assert(false, "Duplicate container_id: " + container_id)
			return
	
	# Register container
	containers[container_id] = container
	
	# Set typed references
	if container_id == "player_toolkit":
		toolkit_container = container
	elif container_id == "player_inventory":
		player_inventory_container = container
	


func get_container(container_id: String) -> ContainerBase:
	"""Get a registered container by ID"""
	return containers.get(container_id, null)


func unregister_container(container_id: String) -> void:
	"""Unregister a container (e.g., on scene change)"""
	if containers.has(container_id):
		containers.erase(container_id)


func _bootstrap_containers() -> void:
	"""Bootstrap containers early to prevent startup crashes from early API calls"""
	await _bootstrap_containers_async()


func _bootstrap_containers_async() -> void:
	"""Async bootstrap - creates containers and waits for registration"""
	# Create ToolkitContainer if needed
	if not toolkit_container:
		var existing = get_container("player_toolkit")
		if existing:
			toolkit_container = existing
		else:
			await _create_toolkit_container_async()
	
	# Create PlayerInventoryContainer if needed
	if not player_inventory_container:
		var existing = get_container("player_inventory")
		if existing:
			player_inventory_container = existing
		else:
			await _create_player_inventory_container_async()


func get_or_create_toolkit_container() -> ContainerBase:
	"""Get or create ToolkitContainer singleton - synchronous check only"""
	# Return existing if already registered
	if toolkit_container:
		return toolkit_container
	
	# Check if already registered by ID
	var existing = get_container("player_toolkit")
	if existing:
		toolkit_container = existing
		return existing
	
	# Not created yet - return null (bootstrap will create it)
	return null


func get_or_create_player_inventory_container() -> ContainerBase:
	"""Get or create PlayerInventoryContainer singleton - creates if missing"""
	# Return existing if already registered
	if player_inventory_container:
		return player_inventory_container
	
	# Check if already registered by ID
	var existing = get_container("player_inventory")
	if existing:
		player_inventory_container = existing
		return existing
	
	# Not created yet - create it synchronously
	var container_script = load("res://scripts/ui/player_inventory_container.gd")
	if not container_script:
		push_error("[InventoryManager] Failed to load PlayerInventoryContainer script!")
		return null
	
	var container_instance = container_script.new()
	container_instance.name = "PlayerInventoryContainer"
	
	# Add to scene tree so _ready() runs and registration happens
	# Use call_deferred to avoid "Parent node is busy setting up children" error
	get_tree().root.add_child.call_deferred(container_instance)
	
	# Wait for add_child to complete
	await get_tree().process_frame
	
	# Wait one more frame for _ready() to complete and registration to happen
	await get_tree().process_frame
	
	# Return the registered container
	if player_inventory_container:
		return player_inventory_container
	else:
		push_error("[InventoryManager] PlayerInventoryContainer created but failed to register!")
		return null


func _create_toolkit_container_async() -> void:
	"""Create ToolkitContainer asynchronously"""
	var container_script = load("res://scripts/ui/toolkit_container.gd")
	if not container_script:
		push_error("[InventoryManager] Failed to load ToolkitContainer script!")
		return
	
	var container_instance = container_script.new()
	container_instance.name = "ToolkitContainer"
	
	# Add to scene tree so _ready() runs and registration happens
	get_tree().root.add_child(container_instance)
	
	# Wait one frame for _ready() to complete and registration to happen
	await get_tree().process_frame
	


func _create_player_inventory_container_async() -> void:
	"""Create PlayerInventoryContainer asynchronously"""
	var container_script = load("res://scripts/ui/player_inventory_container.gd")
	if not container_script:
		push_error("[InventoryManager] Failed to load PlayerInventoryContainer script!")
		return
	
	var container_instance = container_script.new()
	container_instance.name = "PlayerInventoryContainer"
	
	# Add to scene tree so _ready() runs and registration happens
	get_tree().root.add_child(container_instance)
	
	# Wait one frame for _ready() to complete and registration to happen
	await get_tree().process_frame
	

# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.add_item_to_slot() instead
func add_item(slot_index: int, item_texture: Texture, count: int = 1) -> bool:
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		return player_inventory_container.add_item_to_slot(slot_index, item_texture, count)
	
	# LEGACY SYSTEM: Should never reach here unless in migration mode
	assert(legacy_mode_enabled, "add_item() called but legacy_mode_enabled is false and no container exists")
	if not inventory_slots.has(slot_index):
		return false
	inventory_slots[slot_index] = {"texture": item_texture, "count": count, "weight": 0.0}
	return true


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.add_item_auto_stack() instead
func add_item_auto_stack(item_texture: Texture, count: int = 1) -> int:
	"""Add item to inventory with auto-stacking. Returns remaining count that couldn't be added."""
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		return player_inventory_container.add_item_auto_stack(item_texture, count)
	
	# LEGACY SYSTEM: Should never reach here unless in migration mode
	assert(legacy_mode_enabled, "add_item_auto_stack() called but legacy_mode_enabled is false and no container exists")
	
	if not item_texture:
		return count

	var remaining = count
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

	for i in range(max_inventory_slots):
		if remaining <= 0:
			break
		var slot_data = inventory_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			var add_amount = mini(remaining, MAX_INVENTORY_STACK)
			inventory_slots[i] = {"texture": item_texture, "count": add_amount, "weight": 0.0}
			remaining -= add_amount

	sync_inventory_ui()
	return remaining


# Add item to toolkit with auto-stacking
func add_item_to_toolkit_auto_stack(item_texture: Texture, count: int = 1) -> int:
	"""Add item to toolkit with auto-stacking. Returns remaining count that couldn't be added."""
	# NEW SYSTEM: Delegate to ToolkitContainer
	if toolkit_container:
		return toolkit_container.add_item_auto_stack(item_texture, count)
	
	# OLD SYSTEM: Fallback (DEPRECATED)
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

	return remaining # Return any overflow


func get_first_empty_slot() -> int:
	for i in range(inventory_slots.size()):
		var slot_data = inventory_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			return i
	return -1


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.remove_item_from_slot() instead
func remove_item(slot_index: int) -> void:
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		player_inventory_container.remove_item_from_slot(slot_index)
		return
	
	# LEGACY SYSTEM: Should never reach here unless in migration mode
	assert(legacy_mode_enabled, "remove_item() called but legacy_mode_enabled is false and no container exists")
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = {"texture": null, "count": 0, "weight": 0.0}


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.get_slot_data() instead
func get_item(slot_index: int) -> Texture:
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	# Ensure container exists first (safe read - don't crash on startup)
	# For read methods, just check - don't create (bootstrap or UI will create it)
	if not player_inventory_container:
		# Check registry in case it was registered but reference not set
		var existing = get_container("player_inventory")
		if existing:
			player_inventory_container = existing
	
	if player_inventory_container:
		var slot_data = player_inventory_container.get_slot_data(slot_index)
		return slot_data["texture"]
	
	# LEGACY SYSTEM: Only if legacy mode enabled
	if legacy_mode_enabled:
		var slot_data = inventory_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
		return slot_data["texture"]
	
	# Safe default for read methods (don't crash on startup)
	return null


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.get_slot_data() instead
func get_item_count(slot_index: int) -> int:
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	# Ensure container exists first (safe read - don't crash on startup)
	# For read methods, just check - don't create (bootstrap or UI will create it)
	if not player_inventory_container:
		# Check registry in case it was registered but reference not set
		var existing = get_container("player_inventory")
		if existing:
			player_inventory_container = existing
	
	if player_inventory_container:
		var slot_data = player_inventory_container.get_slot_data(slot_index)
		return slot_data["count"]
	
	# LEGACY SYSTEM: Only if legacy mode enabled
	if legacy_mode_enabled:
		var slot_data = inventory_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
		return slot_data["count"]
	
	# Safe default for read methods (don't crash on startup)
	return 0


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.remove_item_from_slot() instead
func remove_item_from_inventory(slot_index: int) -> void:
	"""Remove item from inventory slot (used when dragging to toolkit)"""
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		player_inventory_container.remove_item_from_slot(slot_index)
		return
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "remove_item_from_inventory() called but legacy_mode_enabled is false and no container exists")
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
		sync_inventory_ui()


# Instantiate the inventory UI and add it to the current scene tree
func instantiate_inventory_ui(parent_node: Node = null) -> void:
	if inventory_instance: # Prevent duplicates
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


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.add_item_auto_stack() instead
func add_item_to_first_empty_slot(item_data: Resource) -> bool:
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		var remaining = player_inventory_container.add_item_auto_stack(item_data.texture, 1)
		return remaining == 0
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "add_item_to_first_empty_slot() called but legacy_mode_enabled is false and no container exists")
	for slot_index in inventory_slots.keys():
		var slot_data = inventory_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			inventory_slots[slot_index] = {"texture": item_data.texture, "count": 1, "weight": 0.0}
			sync_inventory_ui()
			return true
	return false


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.add_item_to_slot() instead
func update_inventory_slots(slot_index: int, item_texture: Texture, count: int = 1) -> void:
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		player_inventory_container.add_item_to_slot(slot_index, item_texture, count)
		return
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "update_inventory_slots() called but legacy_mode_enabled is false and no container exists")
	if slot_index < 0 or slot_index >= max_inventory_slots:
		return
	if inventory_slots.has(slot_index):
		inventory_slots[slot_index] = {"texture": item_texture, "count": count, "weight": 0.0}


# LEGACY METHOD - DEPRECATED - Containers sync their own UI via sync_ui()
func sync_inventory_ui() -> void:
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		player_inventory_container.sync_ui()
		return
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "sync_inventory_ui() called but legacy_mode_enabled is false and no container exists")
	
	if not inventory_instance:
		return

	var grid_container = inventory_instance.get_node_or_null("CenterContainer/GridContainer")
	if not grid_container:
		grid_container = inventory_instance.get_node_or_null("InventoryGrid")
	if not grid_container and inventory_instance is GridContainer:
		grid_container = inventory_instance
	if not grid_container:
		return

	for i in range(inventory_slots.size()):
		if i >= grid_container.get_child_count():
			break
		var slot = grid_container.get_child(i)
		if slot and slot is TextureButton:
			var slot_data = inventory_slots.get(i, {"texture": null, "count": 0, "weight": 0.0})
			var item_texture = slot_data["texture"]
			var item_count = slot_data["count"]
			if slot.has_method("set_item"):
				slot.set_item(item_texture, item_count)
			else:
				slot.texture_normal = item_texture if item_texture != null else null


# LEGACY METHOD - DEPRECATED - Use PlayerInventoryContainer.add_item_to_slot() instead
func add_item_from_toolkit(slot_index: int, texture: Texture, count: int = 1) -> bool:
	"""Add item to inventory from toolkit slot"""
	# NEW SYSTEM: Delegate to PlayerInventoryContainer
	if player_inventory_container:
		return player_inventory_container.add_item_to_slot(slot_index, texture, count)
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "add_item_from_toolkit() called but legacy_mode_enabled is false and no container exists")
	if slot_index < 0 or slot_index >= max_inventory_slots:
		return false
	inventory_slots[slot_index] = {"texture": texture, "count": count, "weight": 0.0}
	sync_inventory_ui()
	return true


func remove_item_from_toolkit(slot_index: int) -> void:
	"""Remove item from toolkit slot (used when dragging to inventory)"""
	# NEW SYSTEM: Delegate to ToolkitContainer
	if toolkit_container:
		toolkit_container.remove_item_from_slot(slot_index)
		return
	
	# OLD SYSTEM: Fallback (DEPRECATED)
	if toolkit_slots.has(slot_index):
		toolkit_slots[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
		sync_toolkit_ui()


# LEGACY METHOD - DEPRECATED - Use ToolkitContainer directly
func decrement_toolkit_item_count(slot_index: int, amount: int = 1) -> void:
	"""Decrement item count in toolkit slot. Removes item if count reaches 0."""
	# NEW SYSTEM: Delegate to ToolkitContainer
	if toolkit_container:
		var slot_data = toolkit_container.get_slot_data(slot_index)
		var current_count = slot_data["count"]
		var texture = slot_data["texture"]
		if current_count <= 0 or texture == null:
			return
		var new_count = current_count - amount
		if new_count > 0:
			toolkit_container.add_item_to_slot(slot_index, texture, new_count)
		else:
			toolkit_container.remove_item_from_slot(slot_index)
		return
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "decrement_toolkit_item_count() called but legacy_mode_enabled is false and no container exists")
	if slot_index < 0 or slot_index >= max_toolkit_slots:
		return
	var slot_data = toolkit_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	var current_count = slot_data["count"]
	var texture = slot_data["texture"]
	if current_count <= 0 or texture == null:
		return
	var new_count = current_count - amount
	if new_count > 0:
		toolkit_slots[slot_index] = {"texture": texture, "count": new_count, "weight": 0.0}
	else:
		toolkit_slots[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
	sync_toolkit_ui()


# LEGACY METHOD - DEPRECATED - Use ToolkitContainer.get_slot_data() instead
func get_toolkit_item(slot_index: int) -> Texture:
	"""Get item texture from toolkit slot"""
	# NEW SYSTEM: Delegate to ToolkitContainer
	if toolkit_container:
		var slot_data = toolkit_container.get_slot_data(slot_index)
		return slot_data["texture"]
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "get_toolkit_item() called but legacy_mode_enabled is false and no container exists")
	var slot_data = toolkit_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	return slot_data["texture"]


# LEGACY METHOD - DEPRECATED - Use ToolkitContainer.get_slot_data() instead
func get_toolkit_item_count(slot_index: int) -> int:
	"""Get item count from toolkit slot"""
	# NEW SYSTEM: Delegate to ToolkitContainer
	if toolkit_container:
		var slot_data = toolkit_container.get_slot_data(slot_index)
		return slot_data["count"]
	
	# LEGACY SYSTEM
	assert(legacy_mode_enabled, "get_toolkit_item_count() called but legacy_mode_enabled is false and no container exists")
	var slot_data = toolkit_slots.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	return slot_data["count"]


func add_item_to_toolkit(slot_index: int, texture: Texture, count: int = 1) -> bool:
	"""Add item to toolkit slot (used when dragging from inventory)"""
	# NEW SYSTEM: Delegate to ToolkitContainer
	if toolkit_container:
		return toolkit_container.add_item_to_slot(slot_index, texture, count)
	
	# OLD SYSTEM: Fallback (DEPRECATED)
	if slot_index < 0 or slot_index >= max_toolkit_slots:
		return false

	toolkit_slots[slot_index] = {"texture": texture, "count": count, "weight": 0.0}
	return true


func sync_toolkit_ui(hud_instance: Node = null) -> void:
	"""Sync toolkit UI with toolkit_slots dictionary"""
	# NEW SYSTEM: Delegate to ToolkitContainer
	if toolkit_container:
		toolkit_container.sync_ui()
		return
	
	# OLD SYSTEM: Fallback (DEPRECATED)
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

			# CRITICAL: Don't overwrite slot if it's currently being dragged
			var is_dragging = false
			if texture_button and "is_dragging" in texture_button:
				is_dragging = texture_button.is_dragging
			
			if is_dragging:
				continue
			
			# CRITICAL: toolkit_slots is the source of truth - always update UI from it
			# Don't preserve UI state over dictionary state (causes infinite item bug)
			
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
			if slot.texture != null: # Skip if slot already has a item
				continue

			# Directly assign the droppable's texture
			if item_data and item_data.texture:
				inventory_slots[i] = item_data.texture # Update inventory slot for reference
				slot.texture = item_data.texture # Update HUD slot
				return true

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
			var slot_index = 0 # Declare slot_index before use
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


# LEGACY METHOD - DEPRECATED - ToolkitContainer migrates data automatically in its _ready()
func _sync_initial_toolkit_from_ui() -> void:
	"""Read initial tools from HUD scene and populate toolkit_slots dictionary - LEGACY ONLY"""
	# NEW SYSTEM: ToolkitContainer handles migration in its _migrate_from_inventory_manager()
	# This function should never be called in new system
	assert(legacy_mode_enabled, "_sync_initial_toolkit_from_ui() called but legacy_mode_enabled is false")
	
	var hud_root = _find_hud_root(get_tree().root)
	if not hud_root:
		return
	var hud_canvas = hud_root.get_node_or_null("HUD")
	if not hud_canvas:
		return
	var slots_container = hud_canvas.get_node_or_null("MarginContainer/HBoxContainer")
	if not slots_container:
		return

	for i in range(min(max_toolkit_slots, slots_container.get_child_count())):
		var texture_button = slots_container.get_child(i)
		if texture_button and texture_button is TextureButton:
			var slot_texture: Texture = null
			if texture_button.has_method("get_item"):
				slot_texture = texture_button.get_item()
			else:
				var hud_slot = texture_button.get_node_or_null("Hud_slot_" + str(i))
				if hud_slot and hud_slot is TextureRect:
					slot_texture = hud_slot.texture
			# Tools/chest/seeds are now spawned as droppables on Day 1, not initialized in HUD
			# Keep this code for legacy save file migration only
			if slot_texture:
				var seed_texture_path = "res://assets/tilesets/full version/tiles/FartSnipSeeds.png"
				var initial_count = 1
				if slot_texture.resource_path == seed_texture_path:
					initial_count = 10
				toolkit_slots[i] = {"texture": slot_texture, "count": initial_count, "weight": 0.0}
				if texture_button.has_method("set_item"):
					texture_button.set_item(slot_texture, initial_count)


# LEGACY METHOD - DEPRECATED - ToolkitContainer handles its own data
func _sync_toolkit_from_ui() -> void:
	"""Sync toolkit_slots dictionary FROM current UI state - LEGACY ONLY"""
	# NEW SYSTEM: ToolkitContainer owns its data, no need to sync from UI
	# This function should never be called in new system
	assert(legacy_mode_enabled, "_sync_toolkit_from_ui() called but legacy_mode_enabled is false")
	
	var hud_instance = null
	if HUD and HUD.hud_scene_instance:
		hud_instance = HUD.hud_scene_instance.get_node_or_null("HUD")
	if not hud_instance:
		var hud_root = _find_hud_root(get_tree().root)
		if hud_root:
			hud_instance = hud_root.get_node_or_null("HUD")
	if not hud_instance:
		return
	var slots_container = hud_instance.get_node_or_null("MarginContainer/HBoxContainer")
	if not slots_container:
		return

	for i in range(min(max_toolkit_slots, slots_container.get_child_count())):
		var texture_button = slots_container.get_child(i)
		if texture_button and texture_button is TextureButton:
			var slot_texture: Texture = null
			var slot_count: int = 0
			if texture_button.has_method("get_item"):
				slot_texture = texture_button.get_item()
				if texture_button.has_method("get_stack_count"):
					slot_count = texture_button.get_stack_count()
				elif slot_texture:
					slot_count = 1
			else:
				var hud_slot = texture_button.get_node_or_null("Hud_slot_" + str(i))
				if hud_slot and hud_slot is TextureRect:
					slot_texture = hud_slot.texture
					if slot_texture:
						slot_count = 1
			var final_count = slot_count
			if slot_texture:
				var seed_texture_path = "res://assets/tilesets/full version/tiles/FartSnipSeeds.png"
				var chest_texture_path = "res://assets/icons/chest_icon.png"
				if slot_texture.resource_path == seed_texture_path and (slot_count == 0 or slot_count == 1):
					final_count = 10
				elif i == 4 and slot_texture.resource_path == chest_texture_path and slot_count == 0:
					final_count = 1
			toolkit_slots[i] = {"texture": slot_texture, "count": final_count, "weight": 0.0}

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
