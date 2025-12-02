extends Control

# ChestInventoryPanel - UI for chest storage with 24 slots and player inventory side-by-side

signal panel_closed()

@onready var chest_grid: GridContainer = $CenterContainer/PanelContainer/VBoxContainer/HBoxContainer/ChestContainer/ChestInventoryGrid
@onready var player_grid: GridContainer = null # Will be set to reference pause menu grid
@onready var auto_sort_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/AutoSortButton
@onready var close_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ButtonContainer/CloseButton

var current_chest: Node = null
var chest_inventory: Dictionary = {} # 24 slots: {slot_index: {"texture": Texture, "count": int, "weight": float}}
var chest_slots: Array = [] # Array of inventory_menu_slot nodes
const CHEST_INVENTORY_SIZE: int = 24
const MAX_INVENTORY_STACK: int = 99


func _ready() -> void:
	# Hide panel initially
	visible = false
	
	# Add to group for easy finding
	add_to_group("chest_panel")
	
	# Connect button signals
	if auto_sort_button:
		auto_sort_button.pressed.connect(_on_auto_sort_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Set up chest inventory grid
	_setup_chest_slots()
	
	# Find player inventory grid from pause menu
	_find_player_inventory_grid()
	
	# Connect to player inventory slots for shift-click
	_connect_to_player_inventory_slots()


func _setup_chest_slots() -> void:
	"""Create 24 inventory slots for the chest."""
	if not chest_grid:
		return
	
	# Clear existing slots
	for child in chest_grid.get_children():
		child.queue_free()
	chest_slots.clear()
	
	# Load empty slot texture and slot script
	var empty_texture = preload("res://assets/ui/tile_outline.png")
	var slot_script = load("res://scripts/ui/inventory_menu_slot.gd")
	
	if not slot_script:
		push_error("ChestInventoryPanel: Could not load inventory_menu_slot.gd")
		return
	
	# Create 24 slots (6 columns x 4 rows)
	for i in range(CHEST_INVENTORY_SIZE):
		var slot = TextureButton.new()
		slot.set_script(slot_script)
		slot.slot_index = i
		slot.empty_texture = empty_texture
		slot.is_locked = false
		slot.name = "ChestSlot_%d" % i
		
		# Connect signals for drag-drop and shift-click
		if slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_chest_slot_clicked.bind(i))
		if slot.has_signal("slot_drag_started"):
			slot.slot_drag_started.connect(_on_chest_slot_drag_started.bind(i))
		if slot.has_signal("slot_drop_received"):
			slot.slot_drop_received.connect(_on_chest_slot_drop_received.bind(i))
		
		# Mark slot as chest slot for identification
		slot.set_meta("is_chest_slot", true)
		
		chest_grid.add_child(slot)
		chest_slots.append(slot)
		
		# Initialize slot
		slot._ready()


func _find_player_inventory_grid() -> void:
	"""Find the player inventory grid from the pause menu."""
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if not pause_menu:
		# Try to find it by path
		pause_menu = get_node_or_null("/root/PauseMenu")
	
	if pause_menu:
		player_grid = pause_menu.get_node_or_null("Control/CenterContainer/PanelContainer/VBoxContainer/TabContainer/InventoryTab/VBoxContainer/InventoryGrid")
	
	if not player_grid:
		push_warning("ChestInventoryPanel: Could not find player inventory grid")


func _connect_to_player_inventory_slots() -> void:
	"""Connect to player inventory slots for shift-click handling."""
	if not player_grid:
		return
	
	# Wait a frame for slots to be ready
	await get_tree().process_frame
	
	for i in range(player_grid.get_child_count()):
		var slot = player_grid.get_child(i)
		if slot and slot.has_signal("shift_clicked"):
			if not slot.shift_clicked.is_connected(_on_player_shift_clicked):
				slot.shift_clicked.connect(_on_player_shift_clicked)


func _on_player_shift_clicked(slot_index: int, item_texture: Texture, stack_count: int, source_type: String) -> void:
	"""Handle shift-click from player inventory - transfer to chest."""
	if source_type == "player":
		# Try to add to chest inventory
		var remaining = _add_to_chest_inventory(item_texture, stack_count)
		# Update player inventory
		if InventoryManager:
			if remaining > 0:
				InventoryManager.update_inventory_slots(slot_index, item_texture, remaining)
			else:
				InventoryManager.update_inventory_slots(slot_index, null, 0)
		sync_chest_ui()
		sync_player_ui()


func _add_to_chest_inventory(texture: Texture, count: int) -> int:
	"""Add item to chest inventory with auto-stacking. Returns remaining count."""
	var remaining = count
	
	# First pass: Try to add to existing stacks
	for i in range(CHEST_INVENTORY_SIZE):
		if remaining <= 0:
			break
		var slot_data = chest_inventory.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == texture and slot_data["count"] > 0:
			var space = MAX_INVENTORY_STACK - slot_data["count"]
			var add_amount = min(remaining, space)
			slot_data["count"] += add_amount
			chest_inventory[i] = slot_data
			remaining -= add_amount
	
	# Second pass: Use empty slots for remaining items
	for i in range(CHEST_INVENTORY_SIZE):
		if remaining <= 0:
			break
		var slot_data = chest_inventory.get(i, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] == null or slot_data["count"] == 0:
			var add_amount = min(remaining, MAX_INVENTORY_STACK)
			chest_inventory[i] = {"texture": texture, "count": add_amount, "weight": 0.0}
			remaining -= add_amount
	
	return remaining


func open_chest_ui(chest: Node) -> void:
	"""Open the chest UI and load chest inventory."""
	if not chest:
		return
	
	current_chest = chest
	var chest_id = ""
	if chest.has_method("get_chest_id"):
		chest_id = chest.get_chest_id()
	
	# Load chest inventory from ChestManager
	if ChestManager and chest_id != "":
		chest_inventory = ChestManager.get_chest_inventory(chest_id)
	else:
		# Initialize empty inventory
		chest_inventory = {}
		for i in range(CHEST_INVENTORY_SIZE):
			chest_inventory[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	# Sync UI
	sync_chest_ui()
	sync_player_ui()
	
	# Show panel and pause game
	visible = true
	get_tree().paused = true
	if GameTimeManager:
		GameTimeManager.set_paused(true)


func close_chest_ui() -> void:
	"""Close the chest UI and save chest inventory."""
	# Save chest inventory to ChestManager
	if current_chest and ChestManager:
		var chest_id = ""
		if current_chest.has_method("get_chest_id"):
			chest_id = current_chest.get_chest_id()
		
		if chest_id != "":
			ChestManager.update_chest_inventory(chest_id, chest_inventory)
	
	# Hide panel and unpause game
	visible = false
	get_tree().paused = false
	if GameTimeManager:
		GameTimeManager.set_paused(false)
	
	# Emit signal
	panel_closed.emit()
	current_chest = null


func sync_chest_ui() -> void:
	"""Update chest grid slots from chest_inventory dictionary."""
	if not chest_grid:
		return
	
	for i in range(min(chest_slots.size(), CHEST_INVENTORY_SIZE)):
		var slot = chest_slots[i]
		var slot_data = chest_inventory.get(i, {"texture": null, "count": 0, "weight": 0.0})
		var item_texture = slot_data["texture"]
		var item_count = slot_data["count"]
		
		if slot.has_method("set_item"):
			slot.set_item(item_texture, item_count)


func sync_player_ui() -> void:
	"""Sync player inventory UI."""
	if InventoryManager:
		InventoryManager.sync_inventory_ui()


func _on_auto_sort_pressed() -> void:
	"""Auto-sort chest inventory: stack identical items, then sort by texture path."""
	# TODO: Refine sorting when item_id system is fully implemented
	# For now, use texture resource_path as sorting key
	
	# Step 1: Collect all items with their slot indices
	var items: Array = []
	for slot_index in range(CHEST_INVENTORY_SIZE):
		var slot_data = chest_inventory.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
		if slot_data["texture"] and slot_data["count"] > 0:
			items.append({
				"slot_index": slot_index,
				"texture": slot_data["texture"],
				"count": slot_data["count"],
				"weight": slot_data.get("weight", 0.0)
			})
	
	# Step 2: Group by texture and stack
	var grouped_items: Dictionary = {}
	for item in items:
		var texture = item["texture"]
		var texture_path = texture.resource_path if texture else ""
		
		if not grouped_items.has(texture_path):
			grouped_items[texture_path] = {
				"texture": texture,
				"count": 0,
				"weight": item["weight"]
			}
		
		# Stack up to MAX_INVENTORY_STACK
		var current_count = grouped_items[texture_path]["count"]
		var add_count = min(item["count"], MAX_INVENTORY_STACK - current_count)
		grouped_items[texture_path]["count"] += add_count
	
	# Step 3: Sort by texture path
	var sorted_paths = grouped_items.keys()
	sorted_paths.sort()
	
	# Step 4: Rebuild chest_inventory
	# Clear all slots
	for i in range(CHEST_INVENTORY_SIZE):
		chest_inventory[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	# Fill slots with sorted items
	var slot_index = 0
	for texture_path in sorted_paths:
		if slot_index >= CHEST_INVENTORY_SIZE:
			break
		
		var item_data = grouped_items[texture_path]
		var remaining_count = item_data["count"]
		
		# Split into multiple slots if count exceeds MAX_INVENTORY_STACK
		while remaining_count > 0 and slot_index < CHEST_INVENTORY_SIZE:
			var slot_count = min(remaining_count, MAX_INVENTORY_STACK)
			chest_inventory[slot_index] = {
				"texture": item_data["texture"],
				"count": slot_count,
				"weight": item_data["weight"]
			}
			remaining_count -= slot_count
			slot_index += 1
	
	# Step 5: Sync UI
	sync_chest_ui()


func _on_close_pressed() -> void:
	"""Close button pressed."""
	close_chest_ui()


func _on_chest_slot_clicked(slot_index: int) -> void:
	"""Handle chest slot click (for shift-click transfer)."""
	# Check if shift is held
	if Input.is_key_pressed(KEY_SHIFT):
		_handle_shift_click_transfer(slot_index, "chest")


func _on_chest_slot_drag_started(slot_index: int, item_texture: Texture) -> void:
	"""Handle drag start from chest slot."""
	pass


func _on_chest_slot_drop_received(slot_index: int, data: Dictionary) -> void:
	"""Handle drop on chest slot."""
	var source_slot_index = data.get("slot_index", -1)
	var source_texture = data.get("item_texture")
	var source_count = data.get("stack_count", 0)
	var source_type = data.get("source", "unknown")
	var source_type_alt = data.get("source_type", "unknown")
	
	# Use source_type_alt if source_type is not set
	if source_type == "unknown" and source_type_alt != "unknown":
		source_type = source_type_alt
	
	# Check if source is from chest slot (has is_chest_slot meta)
	var source_node = data.get("source_node", null)
	if source_node and source_node.has_meta("is_chest_slot"):
		source_type = "chest"
	
	if source_type == "player" or source_type == "inventory":
		# Transfer from player inventory to chest
		_transfer_to_chest(slot_index, source_slot_index, source_texture, source_count)
	elif source_type == "chest":
		# Transfer within chest (swap)
		_swap_chest_slots(slot_index, source_slot_index)


func _handle_shift_click_transfer(slot_index: int, source_type: String) -> void:
	"""Handle shift-click quick transfer."""
	if source_type == "chest":
		# Transfer from chest to player inventory
		var slot_data = chest_inventory.get(slot_index, {"texture": null, "count": 0})
		if slot_data["texture"] and slot_data["count"] > 0:
			# Try to add to player inventory
			if InventoryManager:
				var remaining = InventoryManager.add_item_auto_stack(slot_data["texture"], slot_data["count"])
				# Update chest slot
				if remaining < slot_data["count"]:
					var new_count = remaining
					chest_inventory[slot_index] = {
						"texture": slot_data["texture"] if new_count > 0 else null,
						"count": new_count,
						"weight": slot_data.get("weight", 0.0)
					}
					sync_chest_ui()
					sync_player_ui()


func _transfer_to_chest(chest_slot_index: int, player_slot_index: int, texture: Texture, count: int) -> void:
	"""Transfer item from player inventory to chest."""
	var chest_slot_data = chest_inventory.get(chest_slot_index, {"texture": null, "count": 0})
	
	# Check if chest slot is empty or has same texture
	if not chest_slot_data["texture"]:
		# Empty slot - place item
		chest_inventory[chest_slot_index] = {"texture": texture, "count": count, "weight": 0.0}
		# Remove from player inventory
		if InventoryManager:
			InventoryManager.update_inventory_slots(player_slot_index, null, 0)
	elif chest_slot_data["texture"] == texture:
		# Same texture - stack
		var new_count = min(chest_slot_data["count"] + count, MAX_INVENTORY_STACK)
		var remaining = (chest_slot_data["count"] + count) - new_count
		chest_inventory[chest_slot_index] = {
			"texture": texture,
			"count": new_count,
			"weight": chest_slot_data.get("weight", 0.0)
		}
		# Update player inventory
		if InventoryManager:
			if remaining > 0:
				InventoryManager.update_inventory_slots(player_slot_index, texture, remaining)
			else:
				InventoryManager.update_inventory_slots(player_slot_index, null, 0)
	else:
		# Different texture - swap
		var temp_texture = chest_slot_data["texture"]
		var temp_count = chest_slot_data["count"]
		chest_inventory[chest_slot_index] = {"texture": texture, "count": count, "weight": 0.0}
		if InventoryManager:
			InventoryManager.update_inventory_slots(player_slot_index, temp_texture, temp_count)
	
	sync_chest_ui()
	sync_player_ui()


func _swap_chest_slots(slot_index_1: int, slot_index_2: int) -> void:
	"""Swap items between two chest slots."""
	var slot_data_1 = chest_inventory.get(slot_index_1, {"texture": null, "count": 0})
	var slot_data_2 = chest_inventory.get(slot_index_2, {"texture": null, "count": 0})
	
	chest_inventory[slot_index_1] = slot_data_2
	chest_inventory[slot_index_2] = slot_data_1
	
	sync_chest_ui()


func _handle_chest_to_player_swap(chest_slot_index: int, player_slot_index: int, swapped_texture: Texture, swapped_count: int) -> void:
	"""Handle swap when dropping from chest to player inventory (player slot had items)."""
	# Update chest slot with swapped item from player (swapped_texture and swapped_count are what was in player slot)
	chest_inventory[chest_slot_index] = {"texture": swapped_texture, "count": swapped_count, "weight": 0.0}
	sync_chest_ui()
	sync_player_ui()


func _handle_chest_to_player_transfer(chest_slot_index: int, player_slot_index: int, texture: Texture, count: int) -> void:
	"""Handle transfer when dropping from chest to empty player inventory slot."""
	# Clear chest slot
	chest_inventory[chest_slot_index] = {"texture": null, "count": 0, "weight": 0.0}
	sync_chest_ui()
	sync_player_ui()


func _handle_chest_slot_dropped_to_player(chest_slot_index: int, player_slot_index: int, swapped_texture: Texture, swapped_count: int) -> void:
	"""Handle when chest slot drops to player inventory slot (swap scenario)."""
	# Update chest slot with swapped item from player (swapped_texture and swapped_count are what was in player slot)
	chest_inventory[chest_slot_index] = {"texture": swapped_texture, "count": swapped_count, "weight": 0.0}
	sync_chest_ui()
	sync_player_ui()


func _input(event: InputEvent) -> void:
	"""Handle input for closing panel (ESC key)."""
	if visible and event.is_action_pressed("ui_cancel"):
		close_chest_ui()
		get_viewport().set_input_as_handled()
