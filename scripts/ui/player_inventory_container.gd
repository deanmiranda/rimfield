# player_inventory_container.gd
# Container for the player's main inventory (backpack) - 36 slots, max stack 10
# Extends ContainerBase for consistent inventory management

extends ContainerBase

class_name PlayerInventoryContainer

# Singleton instance for global access
static var instance: PlayerInventoryContainer = null


func _ready() -> void:
	# Check for duplicate instance
	if instance != null:
		push_error("❌ DUPLICATE PlayerInventoryContainer instance! Only one should exist.")
		push_error("❌ Existing: %s" % instance)
		push_error("❌ New: %s" % self)
		assert(false, "Duplicate PlayerInventoryContainer")
		return
	
	# Set singleton instance
	instance = self
	
	# Configure container BEFORE calling super (so registration works)
	container_id = "player_inventory"
	container_type = "inventory"
	
	# Get size from GameConfig or InventoryManager
	# Use pause menu's INVENTORY_SLOTS_TOTAL constant (36) to match UI
	# This ensures container slot_count matches the UI grid
	# Pause menu creates 36 slots, so container must have 36 slots
	slot_count = 36 # Match pause menu UI grid (INVENTORY_SLOTS_TOTAL)
	
	max_stack_size = ContainerBase.GLOBAL_MAX_STACK_SIZE
	
	# Call parent _ready (will register with InventoryManager)
	super._ready()
	
	# Migrate existing data from InventoryManager (one-time only)
	_migrate_from_inventory_manager()
	
	print("[PlayerInventoryContainer] Initialized: %d slots, max stack %d" % [slot_count, max_stack_size])


func _migrate_from_inventory_manager() -> void:
	"""Migrate existing inventory data from InventoryManager to this container (ONE TIME ONLY)"""
	if not InventoryManager:
		return
	
	# Check if we already have data (prevent duplicate migration)
	var has_data = false
	for i in range(slot_count):
		if inventory_data[i]["texture"]:
			has_data = true
			break
	
	if has_data:
		print("[PlayerInventoryContainer] Already has data - skipping migration")
		return
	
	if InventoryManager.inventory_slots:
		print("[PlayerInventoryContainer] Migrating data from InventoryManager...")
		var migrated_count = 0
		for i in range(min(slot_count, InventoryManager.inventory_slots.size())):
			var data = InventoryManager.inventory_slots.get(i, {})
			if data.has("texture") and data["texture"]:
				inventory_data[i] = {
					"texture": data["texture"],
					"count": data.get("count", 1),
					"weight": data.get("weight", 0.0)
				}
				migrated_count += 1
				print("[PlayerInventoryContainer] Migrated slot %d: %s x%d" % [
					i,
					data["texture"].resource_path if data["texture"] else "null",
					data.get("count", 1)
				])
		
		if migrated_count == 0:
			print("[PlayerInventoryContainer] No data to migrate")


# Override handle_shift_click for player inventory-specific behavior
func handle_shift_click(slot_index: int) -> void:
	"""Handle shift-click to transfer from player inventory to open container or toolkit"""
	var slot_data = inventory_data[slot_index]
	
	if not slot_data["texture"] or slot_data["count"] <= 0:
		return
	
	print("[PlayerInventoryContainer] Shift-click transfer: inventory slot %d" % slot_index)
	
	# Find target container (chest if open, toolkit otherwise)
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
			print("[PlayerInventoryContainer] Transferred %d items (remaining: %d)" % [
				slot_data["count"] - remaining,
				remaining
			])


func _find_transfer_target() -> ContainerBase:
	"""Find the target container for shift-click transfers"""
	# Check if chest panel is open
	var chest_panel = get_tree().get_first_node_in_group("chest_panel")
	if chest_panel and chest_panel.visible and chest_panel is ContainerBase:
		return chest_panel
	
	# Otherwise, transfer to toolkit
	if ToolkitContainer and ToolkitContainer.instance:
		return ToolkitContainer.instance
	
	return null
