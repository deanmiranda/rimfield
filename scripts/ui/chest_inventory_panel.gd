# chest_inventory_panel.gd
# Chest inventory container using new DragManager system
# Extends ContainerBase for clean, extensible inventory management

extends ContainerBase

signal panel_closed()

# Scene references
@onready var chest_grid: GridContainer = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/ChestContainer/ChestInventoryGrid
@onready var player_grid: GridContainer = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/PlayerContainer/PlayerInventoryGrid
@onready var auto_sort_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/AutoSortButton
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/CloseButton

# Chest reference
var current_chest: Node = null
var current_chest_id: String = ""

# Chest slots (local array for UI-specific behavior)
var chest_slots: Array[SlotBase] = []

# Player inventory slots (NEW SYSTEM: using SlotBase with PlayerInventoryContainer)
var player_slots: Array = []
# Type will show linter error until Godot restarts - this is normal for new class_name
var player_inventory_container = null # Will be PlayerInventoryContainer instance

# Constants
const CHEST_INVENTORY_SIZE: int = 36


func _ready() -> void:
	# Set container config
	container_id = "chest_temp" # Will be set when opening specific chest
	container_type = "chest"
	slot_count = CHEST_INVENTORY_SIZE
	max_stack_size = ContainerBase.GLOBAL_MAX_STACK_SIZE
	
	# Call parent _ready
	super._ready()
	
	# Hide initially
	visible = false
	
	# Add to group for easy finding
	add_to_group("chest_panel")
	
	# Connect button signals
	if auto_sort_button:
		auto_sort_button.pressed.connect(_on_auto_sort_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Set up chest slots using new SlotBase system
	_setup_chest_slots()
	
	# Set up player inventory slots
	_setup_player_slots()
	
	print("[ChestPanel] Ready: %d chest slots created, max stack %d" % [chest_slots.size(), max_stack_size])


func _setup_chest_slots() -> void:
	"""Create 36 chest slots using SlotBase"""
	if not chest_grid:
		return
	
	# Clear existing slots
	for child in chest_grid.get_children():
		chest_grid.remove_child(child)
		child.queue_free()
	chest_slots.clear()
	
	# Load empty slot texture
	var empty_texture = preload("res://assets/ui/tile_outline.png")
	
	# Create 36 slots (6 columns x 6 rows)
	for i in range(CHEST_INVENTORY_SIZE):
		var slot = SlotBase.new()
		slot.slot_index = i
		slot.empty_texture = empty_texture
		slot.container_ref = self
		slot.name = "ChestSlot_%d" % i
		
		chest_grid.add_child(slot)
		
		# Register slot with container using API (for data sync)
		register_slot(slot)
		
		# Store in local array for UI-specific behavior (if needed later)
		chest_slots.append(slot)
		
		# Initialize slot
		slot._ready()
		
		# Sync slot UI from container data
		sync_slot_ui(i)


func _setup_player_slots() -> void:
	"""Create player inventory slots using NEW SlotBase system"""
	if not player_grid:
		return
	
	# Clear existing slots
	for child in player_grid.get_children():
		player_grid.remove_child(child)
		child.queue_free()
	player_slots.clear()
	
	var empty_texture = preload("res://assets/ui/tile_outline.png")
	
	if not InventoryManager:
		return
	
	# NEW SYSTEM: Use PlayerInventoryContainer singleton from InventoryManager
	# Use get_or_create to ensure single instance
	if InventoryManager:
		player_inventory_container = await InventoryManager.get_or_create_player_inventory_container()
		
		if player_inventory_container:
			pass
		else:
			push_error("[ChestPanel] Failed to get PlayerInventoryContainer from InventoryManager!")
			return
	else:
		push_error("[ChestPanel] InventoryManager not found!")
		return
	
	# Use container's slot_count to ensure consistency
	var player_inventory_size = player_inventory_container.slot_count
	
	# Create player inventory slots using SlotBase
	# Maintain local player_slots array for UI-specific behavior
	for i in range(player_inventory_size):
		var slot = SlotBase.new()
		slot.slot_index = i
		slot.empty_texture = empty_texture
		slot.container_ref = player_inventory_container
		slot.name = "PlayerSlot_%d" % i
		
		# Optional: tag slot for logging (helps identify which UI owns it)
		if not "ui_owner_tag" in slot:
			slot.set_meta("ui_owner_tag", "ChestPanel")
		
		slot.custom_minimum_size = Vector2(64, 64)
		slot.ignore_texture_size = true
		slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		player_grid.add_child(slot)
		
		# Register slot with container using API (for data sync)
		player_inventory_container.register_slot(slot)
		
		# Store in local array for UI-specific behavior (if needed later)
		player_slots.append(slot)
		
		slot._ready()
		
		# Sync slot UI from container data
		player_inventory_container.sync_slot_ui(i)
	
	# Sync UI
	player_inventory_container.sync_ui()


func open_chest_ui(chest_node: Node, chest_id: String) -> void:
	"""Open the chest UI for a specific chest"""
	current_chest = chest_node
	current_chest_id = chest_id
	container_id = chest_id
	
	# Load chest inventory from ChestManager
	_load_chest_inventory()
	
	# Sync chest UI
	sync_ui()
	
	# Refresh player inventory view (ensures latest state is shown)
	_refresh_player_inventory_view()
	
	# Open container (shows UI, emits signal)
	open_container()
	
	# Pause game
	get_tree().paused = true


func close_chest_ui() -> void:
	"""Close the chest UI"""
	# Save chest inventory to ChestManager
	_save_chest_inventory()
	
	# Close container (hides UI, emits signal, cancels drags)
	close_container()
	
	# Close chest sprite animation
	if current_chest and current_chest.has_method("close_chest"):
		current_chest.close_chest()
	
	# Clear reference
	current_chest = null
	current_chest_id = ""
	
	# Unpause game
	get_tree().paused = false
	
	emit_signal("panel_closed")


func _input(event: InputEvent) -> void:
	"""Handle ESC key and E key to close chest"""
	if not is_open:
		return
	
	if event.is_action_pressed("ui_cancel"):
		close_chest_ui()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_interact"):
		# E key also closes chest (same as pause menu behavior)
		close_chest_ui()
		get_viewport().set_input_as_handled()


func _load_chest_inventory() -> void:
	"""Load chest inventory data from ChestManager"""
	if not ChestManager or current_chest_id == "":
		return
	
	var saved_inventory = ChestManager.get_chest_inventory(current_chest_id)
	
	# Always initialize with empty slots first
	for i in range(CHEST_INVENTORY_SIZE):
		inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	# If we have saved inventory data, copy it (only valid slot indices 0-35)
	if saved_inventory and saved_inventory.size() > 0:
		for i in range(CHEST_INVENTORY_SIZE):
			if saved_inventory.has(i):
				# Deep copy the slot data to avoid reference issues
				var slot_data = saved_inventory[i]
				if slot_data is Dictionary:
					inventory_data[i] = {
						"texture": slot_data.get("texture"),
						"count": slot_data.get("count", 0),
						"weight": slot_data.get("weight", 0.0)
					}


func _save_chest_inventory() -> void:
	"""Save chest inventory data to ChestManager"""
	if not ChestManager or current_chest_id == "":
		return
	
	ChestManager.update_chest_inventory(current_chest_id, inventory_data)


func _refresh_player_inventory_view() -> void:
	"""Refresh player inventory view - ensures latest container state is shown"""
	if not player_inventory_container:
		return
	
	# Ensure all player slots are registered with container
	for slot in player_slots:
		if slot and is_instance_valid(slot):
			# Re-register to ensure container knows about this view
			player_inventory_container.register_slot(slot)
	
	# Sync UI from container (single source of truth)
	player_inventory_container.sync_ui()


func sync_player_ui() -> void:
	"""Sync player inventory UI in our panel (NEW SYSTEM) - DEPRECATED, use _refresh_player_inventory_view()"""
	_refresh_player_inventory_view()


func _on_auto_sort_pressed() -> void:
	"""Auto-sort chest inventory: stack identical items, then sort by texture path."""
	print("[ChestPanel] Auto-sorting chest inventory...")
	
	# Collect all non-empty items
	var items: Array = []
	for slot_index in range(CHEST_INVENTORY_SIZE):
		var slot_data = inventory_data.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] and slot_data["count"] > 0:
			items.append({
				"texture": slot_data["texture"],
				"count": slot_data["count"],
				"weight": slot_data.get("weight", 0.0)
			})
	
	# Clear inventory
	for i in range(CHEST_INVENTORY_SIZE):
		inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	# Stack identical items
	var stacked_items: Array = []
	for item in items:
		var found_stack = false
		for stacked_item in stacked_items:
			if stacked_item["texture"] == item["texture"]:
				stacked_item["count"] += item["count"]
				found_stack = true
				break
		if not found_stack:
			stacked_items.append(item.duplicate())
	
	# Sort by texture path
	stacked_items.sort_custom(func(a, b):
		var path_a = a["texture"].resource_path if a["texture"] else ""
		var path_b = b["texture"].resource_path if b["texture"] else ""
		return path_a < path_b
	)
	
	# Place sorted items back into slots
	var slot_index = 0
	for item in stacked_items:
		while item["count"] > 0 and slot_index < CHEST_INVENTORY_SIZE:
			var stack_size = min(item["count"], max_stack_size)
			inventory_data[slot_index] = {
				"texture": item["texture"],
				"count": stack_size,
				"weight": item["weight"]
			}
			item["count"] -= stack_size
			slot_index += 1
	
	# Sync UI
	sync_ui()


func _on_close_pressed() -> void:
	"""Handle close button press"""
	close_chest_ui()


# Override removed - use ContainerBase.handle_drop_on_slot() which routes to _handle_external_drop()
# This ensures source removal via ContainerBase API


# Override handle_shift_click for chest-specific behavior
func handle_shift_click(slot_index: int) -> void:
	"""Handle shift-click to quick-transfer from chest to player inventory"""
	var slot_data = inventory_data[slot_index]
	
	if not slot_data["texture"] or slot_data["count"] <= 0:
		return
	
	# Try to add to player inventory
	if InventoryManager:
		var remaining = InventoryManager.add_item_auto_stack(slot_data["texture"], slot_data["count"])
		
		if remaining < slot_data["count"]:
			# Some or all items transferred
			if remaining > 0:
				inventory_data[slot_index]["count"] = remaining
			else:
				inventory_data[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
			
			sync_slot_ui(slot_index)
			sync_player_ui()


func handle_ctrl_left_click(slot_index: int) -> void:
	"""Handle ctrl-left-click to transfer half stack from chest to player inventory"""
	var slot_data = inventory_data[slot_index]
	
	if not slot_data["texture"] or slot_data["count"] <= 0:
		return
	
	# Calculate half stack (round up for odd numbers, minimum 1)
	var half_stack_float = slot_data["count"] / 2.0
	var half_stack = max(1, int(ceil(half_stack_float)))
	
	# Try to add half stack to player inventory
	if InventoryManager:
		var remaining = InventoryManager.add_item_auto_stack(slot_data["texture"], half_stack)
		
		# Calculate how many were actually transferred
		var transferred = half_stack - remaining
		if transferred > 0:
			# Update source slot with remaining count
			var new_count = slot_data["count"] - transferred
			if new_count > 0:
				inventory_data[slot_index]["count"] = new_count
			else:
				inventory_data[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
			
			sync_slot_ui(slot_index)
			sync_player_ui()
