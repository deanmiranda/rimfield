# container_base.gd
# Abstract base class for all inventory containers (chests, fridges, traders, etc.)
# Provides common interface and data management

extends Control

class_name ContainerBase

# Signals
signal container_opened
signal container_closed
signal item_added(slot_index: int, texture: Texture, count: int)
signal item_removed(slot_index: int)
signal item_changed(slot_index: int, texture: Texture, count: int)

# Global stack size constant - unified across all containers
const GLOBAL_MAX_STACK_SIZE := 10

# Container configuration (override in subclasses)
var container_id: String = ""
var container_type: String = "generic" # chest, fridge, trader, etc.
var slot_count: int = 24
var max_stack_size: int = GLOBAL_MAX_STACK_SIZE

# Container data - dictionary of {slot_index: {texture, count, weight}}
var inventory_data: Dictionary = {}

# Slot references (SlotBase instances) - multi-view support
# Dictionary mapping slot_index -> Array[SlotBase] to support multiple UI views per container
var slot_nodes_by_index: Dictionary = {}

# State
var is_open: bool = false


func register_slot(slot: SlotBase) -> void:
	"""Register a SlotBase node with this container (supports multiple views per index)"""
	if slot == null:
		return
	if slot.slot_index < 0:
		return
	
	# Initialize array for this index if needed
	if not slot_nodes_by_index.has(slot.slot_index):
		slot_nodes_by_index[slot.slot_index] = []
	
	# Append slot to array (don't overwrite - support multiple UI views)
	var slot_array = slot_nodes_by_index[slot.slot_index]
	if not slot in slot_array:
		slot_array.append(slot)


func unregister_slot(slot: SlotBase) -> void:
	"""Unregister a SlotBase node from this container"""
	if slot == null or slot.slot_index < 0:
		return
	
	if slot_nodes_by_index.has(slot.slot_index):
		var slot_array = slot_nodes_by_index[slot.slot_index]
		var index = slot_array.find(slot)
		if index >= 0:
			slot_array.remove_at(index)
			if slot_array.is_empty():
				slot_nodes_by_index.erase(slot.slot_index)


func get_registered_slots_for_index(index: int) -> Array:
	"""Get all SlotBase nodes registered for a specific index"""
	if slot_nodes_by_index.has(index):
		return slot_nodes_by_index[index].duplicate()
	return []


func get_all_registered_slots() -> Array:
	"""Get all registered SlotBase nodes (flattened)"""
	var all_slots = []
	for index in slot_nodes_by_index:
		all_slots.append_array(slot_nodes_by_index[index])
	return all_slots


func _ready() -> void:
	# Initialize inventory data
	for i in range(slot_count):
		inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	# Register with InventoryManager to prevent duplicates
	if InventoryManager:
		InventoryManager.register_container(self)


func open_container() -> void:
	"""Open container UI"""
	is_open = true
	visible = true
	emit_signal("container_opened")


func close_container() -> void:
	"""Close container UI"""
	is_open = false
	visible = false
	
	# Cancel any active drags from this container
	if DragManager and DragManager.is_dragging and DragManager.drag_source_container == self:
		DragManager.cancel_drag()
	
	emit_signal("container_closed")


func can_accept_drop(_from_container: Node, _item_texture: Texture, _item_count: int) -> bool:
	"""Check if this container can accept a drop (override for special rules)"""
	# Base implementation: accept anything
	return true


func add_item_to_slot(slot_index: int, texture: Texture, count: int) -> bool:
	"""Add item to specific slot - returns true if successful"""
	if slot_index < 0 or slot_index >= slot_count:
		print("[Container:%s] ERROR: Invalid slot index %d" % [container_id, slot_index])
		return false
	
	var slot_data = inventory_data.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	
	if not slot_data["texture"]:
		# Empty slot - place item
		inventory_data[slot_index] = {"texture": texture, "count": count, "weight": 0.0}
		emit_signal("item_added", slot_index, texture, count)
		sync_slot_ui(slot_index)
		return true
	elif slot_data["texture"] == texture:
		# Same texture - stack
		var new_count = min(slot_data["count"] + count, max_stack_size)
		inventory_data[slot_index]["count"] = new_count
		emit_signal("item_changed", slot_index, texture, new_count)
		sync_slot_ui(slot_index)
		return true
	else:
		# Different texture - can't add
		return false


func remove_item_from_slot(slot_index: int) -> Dictionary:
	"""Remove and return item from slot"""
	if slot_index < 0 or slot_index >= slot_count:
		return {"texture": null, "count": 0}
	
	var slot_data = inventory_data.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	var removed_data = {"texture": slot_data["texture"], "count": slot_data["count"]}
	
	# Clear slot
	inventory_data[slot_index] = {"texture": null, "count": 0, "weight": 0.0}
	emit_signal("item_removed", slot_index)
	sync_slot_ui(slot_index)
	
	return removed_data


func swap_items(slot_a_index: int, slot_b_index: int) -> void:
	"""Swap items between two slots"""
	if slot_a_index < 0 or slot_a_index >= slot_count:
		return
	if slot_b_index < 0 or slot_b_index >= slot_count:
		return
	
	var temp = inventory_data[slot_a_index]
	inventory_data[slot_a_index] = inventory_data[slot_b_index]
	inventory_data[slot_b_index] = temp
	
	sync_slot_ui(slot_a_index)
	sync_slot_ui(slot_b_index)


func stack_items(from_slot_index: int, to_slot_index: int) -> int:
	"""Stack items from one slot to another - returns overflow count"""
	if from_slot_index < 0 or from_slot_index >= slot_count:
		return 0
	if to_slot_index < 0 or to_slot_index >= slot_count:
		return 0
	
	var from_data = inventory_data[from_slot_index]
	var to_data = inventory_data[to_slot_index]
	
	# Must be same texture to stack
	if from_data["texture"] != to_data["texture"]:
		return from_data["count"]
	
	var combined = from_data["count"] + to_data["count"]
	var new_to_count = min(combined, max_stack_size)
	var overflow = combined - new_to_count
	
	# Update slots
	inventory_data[to_slot_index]["count"] = new_to_count
	if overflow > 0:
		inventory_data[from_slot_index]["count"] = overflow
	else:
		inventory_data[from_slot_index] = {"texture": null, "count": 0, "weight": 0.0}
	
	sync_slot_ui(from_slot_index)
	sync_slot_ui(to_slot_index)
	
	return overflow


func get_slot_data(slot_index: int) -> Dictionary:
	"""Get data for specific slot"""
	return inventory_data.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})


func set_slot_data(slot_index: int, texture: Texture, count: int) -> void:
	"""Set exact slot data (texture and count) - updates inventory_data and syncs UI"""
	if slot_index < 0 or slot_index >= slot_count:
		print("[Container:%s] ERROR: Invalid slot index %d" % [container_id, slot_index])
		return
	
	inventory_data[slot_index] = {"texture": texture, "count": count, "weight": 0.0}
	
	if texture:
		emit_signal("item_changed", slot_index, texture, count)
	else:
		emit_signal("item_removed", slot_index)
	
	sync_slot_ui(slot_index)


func sync_ui() -> void:
	"""Update all slot visuals from inventory_data"""
	# Sync all slots (multi-view support - sync_ui updates all registered views)
	for i in range(slot_count):
		sync_slot_ui(i)


func sync_slot_ui(slot_index: int) -> void:
	"""Update all registered slot visuals at this index from inventory_data"""
	if slot_index < 0:
		return
	
	var slot_data = inventory_data.get(slot_index, {"texture": null, "count": 0, "weight": 0.0})
	
	# Update all registered slots at this index (multi-view support)
	if slot_nodes_by_index.has(slot_index):
		var slot_array = slot_nodes_by_index[slot_index]
		# Clean up invalid references while iterating
		var valid_slots = []
		for slot in slot_array:
			if slot and is_instance_valid(slot) and slot.has_method("set_item"):
				slot.set_item(slot_data["texture"], slot_data["count"])
				valid_slots.append(slot)
			else:
				# Slot was freed - remove from registry
				pass
		
		# Update registry if we removed invalid slots
		if valid_slots.size() != slot_array.size():
			slot_nodes_by_index[slot_index] = valid_slots


func handle_drop_on_slot(target_slot_index: int) -> void:
	"""Handle drop from DragManager onto a slot - MUST be overridden or implemented"""
	if not DragManager or not DragManager.is_dragging:
		return
	
	var drag_data = DragManager.end_drag()
	var source_container = drag_data["source_container"]
	var source_slot_index = drag_data["slot_index"]
	var drag_texture = drag_data["texture"]
	var drag_count = drag_data["count"]
	var is_right_click = drag_data["is_right_click"]
	
	# Check if drop is within same container
	if source_container == self:
		_handle_internal_drop(source_slot_index, target_slot_index, drag_texture, drag_count, is_right_click)
	else:
		_handle_external_drop(source_container, source_slot_index, target_slot_index, drag_texture, drag_count, is_right_click)


func _handle_internal_drop(from_slot: int, to_slot: int, texture: Texture, count: int, is_right_click: bool = false) -> void:
	"""Handle drop within same container (swap or stack)"""
	# Ignore same-slot drops
	if from_slot == to_slot:
		return
	
	# Use API to read data (not direct inventory_data access)
	var from_data = get_slot_data(from_slot)
	var to_data = get_slot_data(to_slot)
	
	# CRITICAL: For right-click drags, we need to calculate remaining count
	# The from_slot still has its original data (we didn't modify it during drag)
	var from_original_count = from_data["count"]
	var remaining_in_source = from_original_count - count
	
	# Right-click with different texture: do not swap (per requirements)
	if is_right_click and to_data["texture"] and to_data["texture"] != texture:
		return
	
	if not to_data["texture"]:
		# Empty slot - move item using API
		var transfer_count = count
		if is_right_click:
			transfer_count = 1
		
		set_slot_data(to_slot, texture, transfer_count)
		
		# Update source slot based on remaining count
		if is_right_click:
			# Right-click: decrement by 1
			var remaining = from_original_count - 1
			if remaining > 0:
				set_slot_data(from_slot, texture, remaining)
			else:
				remove_item_from_slot(from_slot)
		else:
			# Left-click: remove all
			remove_item_from_slot(from_slot)
	elif to_data["texture"] == texture:
		# Same texture - stack using API
		var target_current = get_slot_data(to_slot)
		
		# For right-click, only try to move 1 item
		var amount_to_move = count
		if is_right_click:
			amount_to_move = 1
		
		# Compute space available and amount to move
		var space = max_stack_size - target_current["count"]
		var to_move = min(space, amount_to_move)
		var remaining = from_original_count - to_move
		
		# Apply: move items to target
		if to_move > 0:
			add_item_to_slot(to_slot, texture, to_move)
		
		# Update source: either remove completely or set remaining count
		if remaining <= 0:
			# All items moved - remove from source
			remove_item_from_slot(from_slot)
		else:
			# Some items remain - set source to remaining count
			set_slot_data(from_slot, texture, remaining)
	else:
		# Different texture - swap (only allowed on left-click, checked above)
		var temp_texture = to_data["texture"]
		var temp_count = to_data["count"]
		
		# Put dragged item in destination using API
		set_slot_data(to_slot, texture, count)
		
		# Put destination item in source using API
		if remaining_in_source > 0:
			# Source has remaining items - put swapped item in source, lose remaining
			set_slot_data(from_slot, temp_texture, temp_count)
		else:
			# Normal swap: source gets destination's item
			set_slot_data(from_slot, temp_texture, temp_count)


func _handle_external_drop(source_container: Node, source_slot: int, target_slot: int, texture: Texture, count: int, is_right_click: bool = false) -> void:
	"""Handle drop from external container (transfer or swap)"""
	# Use API to read data (not direct inventory_data access)
	var target_data = get_slot_data(target_slot)
	
	if not target_data["texture"]:
		# Empty target - transfer item using API (preserves count)
		# For right-click, only move 1 item (Stardew-style peel)
		var transfer_count = count
		if is_right_click:
			transfer_count = 1
		
		add_item_to_slot(target_slot, texture, transfer_count)
		
		# Update source: remove all if left-click, or decrement by 1 if right-click
		if is_right_click:
			# For right-click, we moved 1 item, so decrement source by 1
			# Get current source count (may have changed if drag started with partial count)
			var source_data = source_container.get_slot_data(source_slot) if source_container.has_method("get_slot_data") else {"texture": texture, "count": count}
			var current_source_count = source_data.get("count", count)
			var remaining = current_source_count - 1
			if remaining > 0:
				if source_container.has_method("set_slot_data"):
					source_container.set_slot_data(source_slot, texture, remaining)
				else:
					source_container.remove_item_from_slot(source_slot)
					source_container.add_item_to_slot(source_slot, texture, remaining)
			else:
				source_container.remove_item_from_slot(source_slot)
		else:
			source_container.remove_item_from_slot(source_slot)
	elif target_data["texture"] == texture:
		# Same texture - stack using clearer algorithm
		# Read current state using APIs
		var target_current = get_slot_data(target_slot)
		
		# For right-click, only try to move 1 item
		var amount_to_move = count
		if is_right_click:
			amount_to_move = 1
		
		# Compute space available and amount to move
		var space = max_stack_size - target_current["count"]
		var to_move = min(space, amount_to_move)
		var remaining = count - to_move
		
		# Apply: move items to target
		if to_move > 0:
			add_item_to_slot(target_slot, texture, to_move)
		
		# Update source: either remove completely or set remaining count
		if remaining == 0:
			# All items moved - remove from source
			source_container.remove_item_from_slot(source_slot)
		else:
			# Some items remain - set source to remaining count using API
			if source_container.has_method("set_slot_data"):
				source_container.set_slot_data(source_slot, texture, remaining)
			else:
				# Fallback: remove and re-add with remaining count
				source_container.remove_item_from_slot(source_slot)
				source_container.add_item_to_slot(source_slot, texture, remaining)
	else:
		# Different texture - swap (only allowed on left-click)
		# Right-click with different texture: do not swap (per requirements)
		if is_right_click:
			return
		
		# Left-click swap using API (preserves both counts)
		var temp_texture = target_data["texture"]
		var temp_count = target_data["count"]
		
		# Put dragged item in target using API
		add_item_to_slot(target_slot, texture, count)
		
		# Put target's item in source using API
		if source_container.has_method("add_item_to_slot"):
			source_container.add_item_to_slot(source_slot, temp_texture, temp_count)
		else:
			push_error("[Container:%s] Source container doesn't have add_item_to_slot()!" % container_id)


func handle_shift_click(_slot_index: int) -> void:
	"""Handle shift-click quick transfer - OVERRIDE in subclass for specific behavior"""
	pass


func find_empty_slot() -> int:
	"""Find first empty slot index, returns -1 if none"""
	for i in range(slot_count):
		var slot_data = inventory_data[i]
		if not slot_data["texture"] or slot_data["count"] <= 0:
			return i
	return -1


func find_slot_with_item(texture: Texture) -> int:
	"""Find first slot containing specific item, returns -1 if not found"""
	for i in range(slot_count):
		var slot_data = inventory_data[i]
		if slot_data["texture"] == texture and slot_data["count"] > 0:
			return i
	return -1


func get_total_item_count(texture: Texture) -> int:
	"""Count total quantity of specific item in container"""
	var total = 0
	for i in range(slot_count):
		var slot_data = inventory_data[i]
		if slot_data["texture"] == texture:
			total += slot_data["count"]
	return total


func is_full() -> bool:
	"""Check if container has no empty slots"""
	return find_empty_slot() == -1


func add_item_auto_stack(texture: Texture, count: int) -> int:
	"""Auto-stack items into container: fill existing stacks first, then empty slots"""
	"""Returns remaining count (0 if fully placed)"""
	if texture == null:
		return count
	
	if count <= 0:
		return 0
	
	var remaining = count
	
	# Pass 1: Top-off existing stacks of same texture
	for i in range(slot_count):
		var data = get_slot_data(i)
		if data and data.get("texture") == texture:
			var current = int(data.get("count", 0))
			var space = max_stack_size - current
			if space > 0:
				var to_add = min(space, remaining)
				if to_add > 0:
					add_item_to_slot(i, texture, to_add)
					remaining -= to_add
					if remaining <= 0:
						return 0
	
	# Pass 2: Fill empty slots
	for i in range(slot_count):
		var data = get_slot_data(i)
		if not data or not data.get("texture"):
			var to_add = min(max_stack_size, remaining)
			if to_add > 0:
				add_item_to_slot(i, texture, to_add)
				remaining -= to_add
				if remaining <= 0:
					return 0
	
	return remaining
