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

# Container configuration (override in subclasses)
var container_id: String = ""
var container_type: String = "generic" # chest, fridge, trader, etc.
var slot_count: int = 24
var max_stack_size: int = 99

# Container data - dictionary of {slot_index: {texture, count, weight}}
var inventory_data: Dictionary = {}

# Slot references (SlotBase instances)
var slots: Array[SlotBase] = []

# State
var is_open: bool = false


func _ready() -> void:
	# Initialize inventory data
	for i in range(slot_count):
		inventory_data[i] = {"texture": null, "count": 0, "weight": 0.0}
	
	print("[ContainerBase] Initialized: id=%s type=%s slots=%d" % [container_id, container_type, slot_count])


func open_container() -> void:
	"""Open container UI"""
	is_open = true
	visible = true
	emit_signal("container_opened")
	print("[Container:%s] Opened" % container_id)


func close_container() -> void:
	"""Close container UI"""
	is_open = false
	visible = false
	
	# Cancel any active drags from this container
	if DragManager and DragManager.is_dragging and DragManager.drag_source_container == self:
		print("[Container:%s] Canceling drag on close" % container_id)
		DragManager.cancel_drag()
	
	emit_signal("container_closed")
	print("[Container:%s] Closed" % container_id)


func can_accept_drop(from_container: Node, item_texture: Texture, item_count: int) -> bool:
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


func sync_ui() -> void:
	"""Update all slot visuals from inventory_data"""
	for i in range(min(slots.size(), slot_count)):
		sync_slot_ui(i)


func sync_slot_ui(slot_index: int) -> void:
	"""Update single slot visual from inventory_data"""
	if slot_index < 0 or slot_index >= slots.size():
		return
	
	var slot = slots[slot_index]
	var slot_data = inventory_data[slot_index]
	
	if slot and slot.has_method("set_item"):
		slot.set_item(slot_data["texture"], slot_data["count"])


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
	
	print("[Container:%s] Handling drop: from=%s slot=%d to_slot=%d texture=%s count=%d" % [
		container_id,
		source_container.container_id if source_container else "unknown",
		source_slot_index,
		target_slot_index,
		drag_texture.resource_path if drag_texture else "null",
		drag_count
	])
	
	# Check if drop is within same container
	if source_container == self:
		_handle_internal_drop(source_slot_index, target_slot_index, drag_texture, drag_count, is_right_click)
	else:
		_handle_external_drop(source_container, source_slot_index, target_slot_index, drag_texture, drag_count)


func _handle_internal_drop(from_slot: int, to_slot: int, texture: Texture, count: int, is_right_click: bool = false) -> void:
	"""Handle drop within same container (swap or stack)"""
	# Ignore same-slot drops
	if from_slot == to_slot:
		print("[Container:%s] Ignoring same-slot drop: %d → %d" % [container_id, from_slot, to_slot])
		return
	
	var from_data = inventory_data[from_slot]
	var to_data = inventory_data[to_slot]
	
	# CRITICAL: For right-click drags, we need to calculate remaining count
	# The from_slot still has its original data (we didn't modify it during drag)
	var from_original_count = from_data["count"]
	var remaining_in_source = from_original_count - count
	
	if not to_data["texture"]:
		# Empty slot - move item
		inventory_data[to_slot] = {"texture": texture, "count": count, "weight": 0.0}
		
		# Update source slot based on remaining count
		if remaining_in_source > 0:
			# Right-click or partial drag: keep remaining items
			inventory_data[from_slot] = {"texture": texture, "count": remaining_in_source, "weight": from_data.get("weight", 0.0)}
		else:
			# Left-click full stack: clear source
			inventory_data[from_slot] = {"texture": null, "count": 0, "weight": 0.0}
	elif to_data["texture"] == texture:
		# Same texture - stack
		var combined = to_data["count"] + count
		var new_to_count = min(combined, max_stack_size)
		var overflow = combined - new_to_count
		
		inventory_data[to_slot]["count"] = new_to_count
		
		# Update source slot
		if overflow > 0:
			# Stack overflow: put overflow back in source
			inventory_data[from_slot] = {"texture": texture, "count": overflow, "weight": from_data.get("weight", 0.0)}
		elif remaining_in_source > 0:
			# Right-click: keep remaining items in source
			inventory_data[from_slot] = {"texture": texture, "count": remaining_in_source, "weight": from_data.get("weight", 0.0)}
		else:
			# All items stacked: clear source
			inventory_data[from_slot] = {"texture": null, "count": 0, "weight": 0.0}
	else:
		# Different texture - swap
		var temp_texture = to_data["texture"]
		var temp_count = to_data["count"]
		
		# Put dragged item in destination
		inventory_data[to_slot] = {"texture": texture, "count": count, "weight": 0.0}
		
		# Put destination item in source (if source has remaining items, they're lost in swap)
		if remaining_in_source > 0:
			# Source has remaining items - this is a complex case
			# For now, put swapped item in source and lose remaining items
			# TODO: Could put remaining items back in destination or handle differently
			inventory_data[from_slot] = {"texture": temp_texture, "count": temp_count, "weight": 0.0}
		else:
			# Normal swap: source gets destination's item
			inventory_data[from_slot] = {"texture": temp_texture, "count": temp_count, "weight": 0.0}
	
	sync_slot_ui(from_slot)
	sync_slot_ui(to_slot)


func _handle_external_drop(source_container: Node, source_slot: int, target_slot: int, texture: Texture, count: int) -> void:
	"""Handle drop from external container (transfer or swap)"""
	var target_data = inventory_data[target_slot]
	
	if not target_data["texture"]:
		# Empty target - transfer item
		inventory_data[target_slot] = {"texture": texture, "count": count, "weight": 0.0}
		source_container.remove_item_from_slot(source_slot)
	elif target_data["texture"] == texture:
		# Same texture - stack
		var combined = target_data["count"] + count
		var new_count = min(combined, max_stack_size)
		var overflow = combined - new_count
		
		inventory_data[target_slot]["count"] = new_count
		
		if overflow > 0:
			# Update source with overflow
			if source_container.has_method("get_slot_data"):
				source_container.inventory_data[source_slot]["count"] = overflow
				source_container.sync_slot_ui(source_slot)
		else:
			# Remove from source
			source_container.remove_item_from_slot(source_slot)
	else:
		# Different texture - swap
		var temp_texture = target_data["texture"]
		var temp_count = target_data["count"]
		
		inventory_data[target_slot] = {"texture": texture, "count": count, "weight": 0.0}
		
		if source_container.has_method("add_item_to_slot"):
			source_container.inventory_data[source_slot] = {"texture": temp_texture, "count": temp_count, "weight": 0.0}
			source_container.sync_slot_ui(source_slot)
	
	sync_slot_ui(target_slot)


func handle_shift_click(slot_index: int) -> void:
	"""Handle shift-click quick transfer - OVERRIDE in subclass for specific behavior"""
	print("[Container:%s] Shift-click on slot %d (override this method)" % [container_id, slot_index])


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
