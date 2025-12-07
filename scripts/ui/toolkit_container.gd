# toolkit_container.gd
# Container for the player's HUD/toolkit (hotbar) - 10 slots, max stack 10
# Extends ContainerBase for consistent inventory management

extends ContainerBase

class_name ToolkitContainer

# Singleton instance for global access
static var instance: ToolkitContainer = null

# Active tool tracking
signal active_slot_changed(slot_index: int)
signal tool_equipped(slot_index: int, texture: Texture)

var active_slot_index: int = 0
var active_tool_texture: Texture = null


func _ready() -> void:
	# CRITICAL: Check for duplicate BEFORE doing anything
	# Check both static instance AND InventoryManager registry
	if instance != null and instance != self:
		push_error("❌ DUPLICATE ToolkitContainer instance! Only one should exist.")
		push_error("❌ Existing: %s" % instance)
		push_error("❌ New: %s" % self)
		queue_free() # Delete this duplicate
		return
	
	# Check InventoryManager registry BEFORE registering
	if InventoryManager:
		if InventoryManager.toolkit_container and InventoryManager.toolkit_container != self:
			push_error("❌ ToolkitContainer already registered in InventoryManager!")
			push_error("❌ Existing: %s" % InventoryManager.toolkit_container)
			push_error("❌ New: %s" % self)
			queue_free() # Delete this duplicate
			return
		# If we're the registered one, reuse it
		if InventoryManager.toolkit_container == self:
			return
	
	# Set singleton instance
	instance = self
	
	# Configure container BEFORE calling super (so registration works)
	container_id = "player_toolkit"
	container_type = "toolkit"
	slot_count = 10
	max_stack_size = ContainerBase.GLOBAL_MAX_STACK_SIZE
	
	# Call parent _ready (will register with InventoryManager)
	super._ready()
	
	# Migrate existing data from InventoryManager (only once)
	_migrate_from_inventory_manager()


func _migrate_from_inventory_manager() -> void:
	"""Migrate existing toolkit data from InventoryManager to this container (ONE TIME ONLY)"""
	if not InventoryManager:
		return
	
	# Check if we already have data (prevent duplicate migration)
	var has_data = false
	for i in range(slot_count):
		if inventory_data[i]["texture"]:
			has_data = true
			break
	
	if has_data:
		return
	
	if InventoryManager.toolkit_slots:
		for i in range(min(slot_count, InventoryManager.toolkit_slots.size())):
			var data = InventoryManager.toolkit_slots.get(i, {})
			if data.has("texture") and data["texture"]:
				inventory_data[i] = {
					"texture": data["texture"],
					"count": data.get("count", 1),
					"weight": data.get("weight", 0.0)
				}


func set_active_slot(slot_index: int) -> void:
	"""Set the active/selected tool slot"""
	if slot_index < 0 or slot_index >= slot_count:
		return
	
	active_slot_index = slot_index
	var slot_data = get_slot_data(slot_index)
	active_tool_texture = slot_data["texture"]
	
	emit_signal("active_slot_changed", slot_index)
	emit_signal("tool_equipped", slot_index, active_tool_texture)


func get_active_slot_index() -> int:
	"""Get currently active slot index"""
	return active_slot_index


func get_active_tool() -> Texture:
	"""Get currently active tool texture"""
	return active_tool_texture


func can_throw_to_world(texture: Texture) -> bool:
	"""Check if item can be thrown to world (tools and seeds cannot)"""
	if not texture:
		return false
	
	var texture_path = texture.resource_path
	# Tools cannot be dropped
	if "tools/shovel.png" in texture_path or "tools/watering-can.png" in texture_path or "tools/pick-axe.png" in texture_path:
		return false
	# Seeds cannot be dropped
	if "FartSnipSeeds.png" in texture_path:
		return false
	# Other items can be dropped
	return true


# Override handle_shift_click for toolkit-specific behavior
func handle_shift_click(slot_index: int) -> void:
	"""Handle shift-click to transfer from toolkit to open container or player inventory"""
	var slot_data = inventory_data[slot_index]
	
	if not slot_data["texture"] or slot_data["count"] <= 0:
		return
	
	# Find target container (chest if open, player inventory otherwise)
	var target_container = _find_transfer_target()
	
	if target_container:
		# Try to add to target container
		var remaining = target_container.add_item_auto_stack(slot_data["texture"], slot_data["count"])
		
		if remaining < slot_data["count"]:
			# Some or all items transferred
			if remaining > 0:
				inventory_data[slot_index]["count"] = remaining
			else:
				inventory_data[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
			
			sync_slot_ui(slot_index)


func _find_transfer_target() -> ContainerBase:
	"""Find the target container for shift-click transfers"""
	# Check if chest panel is open (highest priority)
	var chest_panel = get_tree().get_first_node_in_group("chest_panel")
	if chest_panel and chest_panel.visible and chest_panel is ContainerBase:
		return chest_panel
	
	# Otherwise, transfer to player inventory (when PauseMenu is open or always available)
	if InventoryManager and InventoryManager.player_inventory_container:
		return InventoryManager.player_inventory_container
	
	return null


func add_item_auto_stack(texture: Texture, count: int) -> int:
	"""Add item with auto-stacking, returns remaining count that couldn't be added"""
	var remaining = count
	
	# First pass: try to stack with existing items
	for i in range(slot_count):
		var slot_data = inventory_data[i]
		if slot_data["texture"] == texture and slot_data["count"] < max_stack_size:
			var space = max_stack_size - slot_data["count"]
			var to_add = min(remaining, space)
			slot_data["count"] += to_add
			remaining -= to_add
			sync_slot_ui(i)
			
			if remaining <= 0:
				return 0
	
	# Second pass: fill empty slots
	for i in range(slot_count):
		var slot_data = inventory_data[i]
		if not slot_data["texture"]:
			var to_add = min(remaining, max_stack_size)
			inventory_data[i] = {"texture": texture, "count": to_add, "weight": 0.0}
			remaining -= to_add
			sync_slot_ui(i)
			
			if remaining <= 0:
				return 0
	
	return remaining
