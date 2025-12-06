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

# Player inventory slots (NEW SYSTEM: using SlotBase)
var player_slots: Array = []
var temp_player_container: ContainerBase = null # Temporary until Phase 2 PlayerInventoryContainer

# Constants
const CHEST_INVENTORY_SIZE: int = 24


func _ready() -> void:
	# Set container config
	container_id = "chest_temp" # Will be set when opening specific chest
	container_type = "chest"
	slot_count = CHEST_INVENTORY_SIZE
	max_stack_size = 99
	
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
	
	# Set up player inventory slots (still using old system for now)
	_setup_player_slots()
	
	print("[ChestPanel] Ready: %d chest slots created" % slots.size())


func _setup_chest_slots() -> void:
	"""Create 24 chest slots using SlotBase"""
	if not chest_grid:
		return
	
	# Clear existing slots
	for child in chest_grid.get_children():
		chest_grid.remove_child(child)
		child.queue_free()
	slots.clear()
	
	# Load empty slot texture
	var empty_texture = preload("res://assets/ui/tile_outline.png")
	
	# Create 24 slots (6 columns x 4 rows)
	for i in range(CHEST_INVENTORY_SIZE):
		var slot = SlotBase.new()
		slot.slot_index = i
		slot.empty_texture = empty_texture
		slot.container_ref = self
		slot.name = "ChestSlot_%d" % i
		
		chest_grid.add_child(slot)
		slots.append(slot)
		
		# Initialize slot
		slot._ready()
	
	print("[ChestPanel] Created %d chest slots" % slots.size())


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
	
	var player_inventory_size = InventoryManager.max_inventory_slots
	
	# NEW SYSTEM: Create SlotBase slots for player inventory
	# TODO Phase 2: These should reference PlayerInventoryContainer.instance
	# For now, create temporary wrapper container
	temp_player_container = ContainerBase.new()
	temp_player_container.container_id = "temp_player_inventory"
	temp_player_container.container_type = "inventory"
	temp_player_container.slot_count = player_inventory_size
	temp_player_container.max_stack_size = 99
	add_child(temp_player_container)
	temp_player_container._ready()
	
	# Migrate data from InventoryManager
	for i in range(player_inventory_size):
		var data = InventoryManager.inventory_slots.get(i, {})
		if data.has("texture"):
			temp_player_container.inventory_data[i] = data.duplicate()
	
	# Create player inventory slots using SlotBase
	for i in range(player_inventory_size):
		var slot = SlotBase.new()
		slot.slot_index = i
		slot.empty_texture = empty_texture
		slot.container_ref = temp_player_container
		slot.name = "PlayerSlot_%d" % i
		
		slot.custom_minimum_size = Vector2(64, 64)
		slot.ignore_texture_size = true
		slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		player_grid.add_child(slot)
		player_slots.append(slot)
		temp_player_container.slots.append(slot)
		
		slot._ready()
	
	# Sync UI
	temp_player_container.sync_ui()
	
	print("[ChestPanel] Created %d player slots (SlotBase)" % player_slots.size())


func open_chest_ui(chest_node: Node, chest_id: String) -> void:
	"""Open the chest UI for a specific chest"""
	current_chest = chest_node
	current_chest_id = chest_id
	container_id = chest_id
	
	print("[ChestPanel] Opening chest UI for: %s" % chest_id)
	
	# Load chest inventory from ChestManager
	_load_chest_inventory()
	
	# Sync chest UI
	sync_ui()
	
	# Sync player UI
	sync_player_ui()
	
	# Open container (shows UI, emits signal)
	open_container()
	
	# Pause game
	get_tree().paused = true


func close_chest_ui() -> void:
	"""Close the chest UI"""
	print("[ChestPanel] Closing chest UI")
	
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
	"""Handle ESC key to close chest"""
	if not is_open:
		return
	
	if event.is_action_pressed("ui_cancel"):
		print("[ChestPanel] ESC pressed - closing chest")
		close_chest_ui()
		get_viewport().set_input_as_handled()


func _load_chest_inventory() -> void:
	"""Load chest inventory data from ChestManager"""
	if not ChestManager or current_chest_id == "":
		return
	
	var saved_inventory = ChestManager.get_chest_inventory(current_chest_id)
	
	if saved_inventory and saved_inventory.size() > 0:
		print("[ChestPanel] Loaded chest inventory: %d slots" % saved_inventory.size())
		inventory_data = saved_inventory.duplicate(true)
	else:
		# Initialize empty inventory
		for i in range(CHEST_INVENTORY_SIZE):
			inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}


func _save_chest_inventory() -> void:
	"""Save chest inventory data to ChestManager"""
	if not ChestManager or current_chest_id == "":
		return
	
	print("[ChestPanel] Saving chest inventory to ChestManager: %s" % current_chest_id)
	ChestManager.update_chest_inventory(current_chest_id, inventory_data)


func sync_player_ui() -> void:
	"""Sync player inventory UI in our panel (NEW SYSTEM)"""
	if not player_grid or not InventoryManager:
		return
	
	# NEW SYSTEM: Sync from temp container or InventoryManager
	if temp_player_container:
		# Sync container data from InventoryManager first
		for i in range(min(player_slots.size(), InventoryManager.max_inventory_slots)):
			var slot_data = InventoryManager.inventory_slots.get(i, {"texture": null, "count": 0})
			temp_player_container.inventory_data[i] = slot_data.duplicate()
		
		# Sync UI from container
		temp_player_container.sync_ui()
	else:
		# Fallback: direct sync (shouldn't happen)
		for i in range(min(player_slots.size(), InventoryManager.max_inventory_slots)):
			var slot = player_slots[i]
			var slot_data = InventoryManager.inventory_slots.get(i, {"texture": null, "count": 0})
			var item_texture = slot_data["texture"]
			var item_count = slot_data["count"]
			
			if slot.has_method("set_item"):
				slot.set_item(item_texture, item_count)


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
	print("[ChestPanel] Auto-sort complete")


func _on_close_pressed() -> void:
	"""Handle close button press"""
	close_chest_ui()


# Override handle_drop_on_slot to support drops from HUD/toolkit (external to chest system)
func handle_drop_on_slot(target_slot_index: int) -> void:
	"""Handle drop from DragManager onto a chest slot"""
	var drag_data = DragManager.end_drag()
	var source_container = drag_data["source_container"]
	var source_slot_index = drag_data["slot_index"]
	var drag_texture = drag_data["texture"]
	var drag_count = drag_data["count"]
	
	print("[ChestPanel] Drop on slot %d: from=%s source_slot=%d texture=%s count=%d" % [
		target_slot_index,
		source_container.name if source_container else "unknown",
		source_slot_index,
		drag_texture.resource_path if drag_texture else "null",
		drag_count
	])
	
	# Check if drop is from within chest
	if source_container == self:
		var is_right_click = drag_data.get("is_right_click", false)
		_handle_internal_drop(source_slot_index, target_slot_index, drag_texture, drag_count, is_right_click)
	else:
		# External drop (from HUD or player inventory)
		_handle_external_drop_to_chest(source_container, source_slot_index, target_slot_index, drag_texture, drag_count)


func _handle_external_drop_to_chest(source_container: Node, source_slot: int, target_slot: int, texture: Texture, count: int) -> void:
	"""Handle drop from HUD/toolkit or player inventory to chest"""
	var target_data = inventory_data[target_slot]
	
	if not target_data["texture"]:
		# Empty target - transfer item
		print("[ChestPanel] Placing in empty slot %d" % target_slot)
		inventory_data[target_slot] = {"texture": texture, "count": count, "weight": 0.0}
		
		# Remove from source (HUD/toolkit or player inventory)
		_remove_from_source(source_container, source_slot)
		
	elif target_data["texture"] == texture:
		# Same texture - stack
		print("[ChestPanel] Stacking in slot %d" % target_slot)
		var combined = target_data["count"] + count
		var new_count = min(combined, max_stack_size)
		var overflow = combined - new_count
		
		inventory_data[target_slot]["count"] = new_count
		
		if overflow > 0:
			# Update source with overflow
			_update_source_count(source_container, source_slot, overflow)
		else:
			# Remove from source
			_remove_from_source(source_container, source_slot)
	else:
		# Different texture - swap
		print("[ChestPanel] Swapping with slot %d" % target_slot)
		var temp_texture = target_data["texture"]
		var temp_count = target_data["count"]
		
		inventory_data[target_slot] = {"texture": texture, "count": count, "weight": 0.0}
		
		# Put chest item into source
		_update_source(source_container, source_slot, temp_texture, temp_count)
	
	sync_slot_ui(target_slot)


func _remove_from_source(source_container: Node, source_slot: int) -> void:
	"""Remove item from source (HUD/toolkit or player inventory)"""
	# Check if source is HUD/toolkit
	if source_container and source_container.has_method("get_item"):
		# This is a HUD slot
		if InventoryManager:
			InventoryManager.toolkit_slots[source_slot] = {"texture": null, "count": 0, "weight": 0.0}
			InventoryManager.sync_toolkit_ui()
		
		# Also clean up HUD slot's visual state
		if source_container.has_method("_cleanup_drag_manager_state"):
			source_container._cleanup_drag_manager_state()
		else:
			# Fallback: restore slot visual
			var hud_slot_rect = source_container.get_node_or_null("Hud_slot_" + str(source_slot))
			if hud_slot_rect:
				hud_slot_rect.modulate = Color.WHITE
	elif InventoryManager:
		# Player inventory
		InventoryManager.inventory_slots[source_slot] = {"texture": null, "count": 0, "weight": 0.0}
		sync_player_ui()


func _update_source_count(source_container: Node, source_slot: int, new_count: int) -> void:
	"""Update source slot count (for overflow from stacking)"""
	# Check if source is HUD/toolkit
	if source_container and source_container.has_method("get_item"):
		# This is a HUD slot
		if InventoryManager:
			var existing = InventoryManager.toolkit_slots.get(source_slot, {})
			existing["count"] = new_count
			InventoryManager.toolkit_slots[source_slot] = existing
			InventoryManager.sync_toolkit_ui()
		
		# Clean up HUD slot's visual state
		if source_container.has_method("_cleanup_drag_manager_state"):
			source_container._cleanup_drag_manager_state()
		else:
			# Fallback: restore slot visual
			var hud_slot_rect = source_container.get_node_or_null("Hud_slot_" + str(source_slot))
			if hud_slot_rect:
				hud_slot_rect.modulate = Color.WHITE
	elif InventoryManager:
		# Player inventory
		var existing = InventoryManager.inventory_slots.get(source_slot, {})
		existing["count"] = new_count
		InventoryManager.inventory_slots[source_slot] = existing
		sync_player_ui()


func _update_source(source_container: Node, source_slot: int, texture: Texture, count: int) -> void:
	"""Update source slot with new item (for swaps)"""
	# Check if source is HUD/toolkit
	if source_container and source_container.has_method("get_item"):
		# This is a HUD slot
		if InventoryManager:
			InventoryManager.toolkit_slots[source_slot] = {"texture": texture, "count": count, "weight": 0.0}
			InventoryManager.sync_toolkit_ui()
		
		# Clean up HUD slot's visual state
		if source_container.has_method("_cleanup_drag_manager_state"):
			source_container._cleanup_drag_manager_state()
		else:
			# Fallback: restore slot visual
			var hud_slot_rect = source_container.get_node_or_null("Hud_slot_" + str(source_slot))
			if hud_slot_rect:
				hud_slot_rect.modulate = Color.WHITE
	elif InventoryManager:
		# Player inventory
		InventoryManager.inventory_slots[source_slot] = {"texture": texture, "count": count, "weight": 0.0}
		sync_player_ui()


# Override handle_shift_click for chest-specific behavior
func handle_shift_click(slot_index: int) -> void:
	"""Handle shift-click to quick-transfer from chest to player inventory"""
	var slot_data = inventory_data[slot_index]
	
	if not slot_data["texture"] or slot_data["count"] <= 0:
		return
	
	print("[ChestPanel] Shift-click transfer: chest slot %d → player inventory" % slot_index)
	
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
			print("[ChestPanel] Transferred %d items (remaining: %d)" % [slot_data["count"] - remaining, remaining])
		else:
			print("[ChestPanel] Transfer failed - player inventory full")
