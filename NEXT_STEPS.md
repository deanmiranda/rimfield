# Next Steps: Inventory Drag and Drop Bug Fixes

## Current Status (Last Updated: Today)

### ✅ Completed
1. **Basic drag and drop implementation** - Full drag-and-drop system between toolkit and inventory is functional
2. **Right-click drag support** - Right-click to drag one item at a time, with accumulation on repeated right-clicks
3. **Left-click drag support** - Left-click to drag entire stack
4. **Visual feedback** - Ghost icons, drag previews, and count labels
5. **Bug Fix: Right-click then left-click on empty slot** - Original stack count is now preserved when dropping on empty slots

### 🔧 In Progress / Needs Testing
1. **Bug: Right-click drag then left-click swap on different item type**
   - **Status**: Fix identified, needs implementation
   - **Issue**: When right-click dragging items from toolkit and dropping on inventory slot with a different item type, the swap doesn't work correctly. The source slot gets the original item back instead of the swapped item, and remaining items are lost.
   - **Root Cause**: In `scripts/ui/inventory_menu_slot.gd` lines 1195-1226, when `source_remaining > 0`, the code sets source slot to `from_item_texture, source_remaining` (original item) instead of `temp_texture, temp_stack_count` (swapped item).
   - **Proposed Fix**: 
     - When swapping different item types with right-click drag and `source_remaining > 0`:
       - Source slot should receive the swapped item (`temp_texture, temp_stack_count`)
       - Remaining items (`source_remaining`) should stay on cursor by updating drag state
       - Drag preview should be updated to show remaining count
     - This matches the inventory-to-inventory right-click swap logic (lines 1255-1290)
   - **File to Modify**: `scripts/ui/inventory_menu_slot.gd` (lines ~1195-1226)
   - **Implementation**: Replace the toolkit right-click drag handling section to properly handle different item type swaps

## Testing Required

### Test Case 1: Right-click drag then left-click on empty slot ✅ (Fixed)
**Steps:**
1. Open inventory panel
2. Right-click a stack (e.g., 8 items) — should grab 1 item, showing 7 remaining
3. Left-click on an empty inventory slot
4. **Expected result:**
   - Empty slot gets the dragged item (1 item)
   - Source slot shows the remaining items (7 items)
   - No items lost

### Test Case 2: Right-click drag then left-click on different item type 🔧 (Needs Testing)
**Steps:**
1. Open inventory panel
2. Right-click a stack (e.g., 8 items of type A) — should grab 1 item, showing 7 remaining
3. Left-click on a slot with a different item type (e.g., type B with 3 items)
4. **Expected result:**
   - Target slot gets the dragged item (1x type A)
   - Source slot gets the swapped item (3x type B)
   - Remaining items (7x type A) stay on the cursor as a ghost icon
   - Ghost icon shows count "7"
5. **Previous bug:** The swapped item (type B) was destroyed/lost

### Test Case 3: Right-click drag then left-click on same item type
**Steps:**
1. Open inventory panel
2. Right-click a stack (e.g., 8 items of type A) — should grab 1 item, showing 7 remaining
3. Left-click on a slot with the same item type (e.g., type A with 3 items, max stack 99)
4. **Expected result:**
   - Target slot gets stacked items (3 + 1 = 4 items of type A)
   - Source slot gets the remaining items (7 items of type A)
   - If stacking exceeds max, remainder stays on cursor

### Test Case 4: Right-click drag accumulation
**Steps:**
1. Open inventory panel
2. Right-click a stack (e.g., 8 items) — should grab 1 item
3. Right-click the same slot again — should grab another item (now dragging 2)
4. Right-click again — should grab another item (now dragging 3)
5. **Expected result:**
   - Drag preview count label updates (1 → 2 → 3)
   - Source slot count decreases accordingly (7 → 6 → 5)
   - Cannot accumulate more than the original stack count

### Test Case 5: Right-click drag transition to left-click drag
**Steps:**
1. Open inventory panel
2. Right-click a stack (e.g., 8 items) — should grab 1 item
3. While still dragging, left-click and hold — should transition to left-click drag
4. **Expected result:**
   - Drag preview updates to show full stack (8 items)
   - Source slot becomes empty (all items being dragged)
   - Can drop entire stack

## Code Location

**Primary File**: `scripts/ui/inventory_menu_slot.gd`
- **Key Functions**:
  - `_gui_input()` - Handles mouse input and drag transitions (lines ~200-280)
  - `_start_drag()` - Initiates left-click drag (lines ~300-400)
  - `_start_right_click_drag()` - Initiates/accumulates right-click drag (lines ~450-550)
  - `drop_data()` - Handles drop logic, including swaps (lines ~800-1300)
  - `_stop_drag_cleanup()` - Cleans up drag state (lines ~600-650)

## Debug Output

The code currently has extensive debug print statements (29 instances of "DEBUG inventory"). These can be removed after testing confirms all bugs are fixed.

**To find debug statements:**
```powershell
Select-String -Path "scripts\ui\inventory_menu_slot.gd" -Pattern "DEBUG inventory"
```

## Next Actions

1. **Test Test Case 2** (right-click drag then left-click on different item type)
   - Verify items swap correctly
   - Verify remaining items stay on cursor
   - Check that no items are lost/destroyed

2. **If Test Case 2 passes:**
   - Test all other test cases to ensure no regressions
   - Remove debug print statements
   - Mark bug as complete

3. **If Test Case 2 fails:**
   - Review the `drop_data()` function, specifically the section handling right-click drags from inventory (lines ~1228-1300)
   - Check that `source_remaining` is calculated correctly
   - Verify that drag state is preserved when keeping items on cursor
   - Check that `_update_drag_preview_count()` is being called correctly

## Technical Notes

### Key Variables
- `original_stack_count`: Stores the original stack size before any drag operations
- `drag_count`: Number of items currently being dragged
- `_is_right_click_drag`: Boolean flag indicating right-click drag mode
- `source_original_stack_count`: Passed in drag data to preserve original stack across drops

### Critical Logic Flow
1. Right-click drag starts → `original_stack_count` is set to current `stack_count`
2. Items are accumulated → `drag_count` increases, `stack_count` decreases
3. Drop occurs → `source_remaining = source_original_stack_count - drag_count`
4. If swapping with different item type → remaining items stay on cursor, source gets swapped item

## Known Issues / Edge Cases to Watch

- [x] Right-click drag from toolkit to inventory with different item type - **FIX IDENTIFIED** (see Proposed Fix above)
- [ ] Right-click drag from inventory to toolkit with different item type - **NEEDS VERIFICATION**
- [ ] Rapid right-click accumulation (should not cause race conditions)
- [ ] Right-click drag then cancel (right-click outside inventory) - should restore original stack
- [ ] Right-click drag with stack size 1 (edge case)

## Proposed Fixes

### Fix 1: Right-click drag from toolkit to inventory (different item type swap)

**Location**: `scripts/ui/inventory_menu_slot.gd` lines 1195-1226

**Current Problem**: When right-click dragging from toolkit and dropping on inventory with different item type:
- Source slot incorrectly gets `from_item_texture, source_remaining` (original item with remaining count)
- Should get `temp_texture, temp_stack_count` (swapped item from target slot)
- Remaining items are lost instead of staying on cursor

**Fix Code**:
```gdscript
if source == "toolkit" and source_slot_index >= 0 and is_right_click_drag and source_original_stack_count > 0:
	# Right-click drag: source should have (original - dragged) items remaining
	var source_remaining = source_original_stack_count - from_stack_count
	print("DEBUG inventory drop_data: Right-click full swap from toolkit - original=", source_original_stack_count, " dragged=", from_stack_count, " remaining=", source_remaining)
	
	# CRITICAL: For different item types, source gets the swapped item, remaining stays on cursor
	if source_remaining > 0:
		# Different item type swap: source gets swapped item, remaining items stay on cursor
		if source_node and source_node.has_method("set_item"):
			# Source slot gets the swapped item (that was in the target slot)
			source_node.set_item(temp_texture, temp_stack_count)
		# Update InventoryManager
		if InventoryManager:
			if temp_texture:
				InventoryManager.add_item_to_toolkit(source_slot_index, temp_texture, temp_stack_count)
			else:
				InventoryManager.remove_item_from_toolkit(source_slot_index)
		
		# CRITICAL: Update source node's drag state to continue dragging the remaining items
		if "drag_count" in source_node:
			source_node.drag_count = source_remaining
		if "original_texture" in source_node:
			source_node.original_texture = from_item_texture
		if "original_stack_count" in source_node:
			source_node.original_stack_count = source_original_stack_count
		# Update drag preview to show remaining count
		if source_node.has_method("_update_drag_preview_count"):
			source_node._update_drag_preview_count(source_remaining)
		elif source_node.has_method("_create_drag_preview"):
			# Recreate drag preview with new count
			if "drag_preview" in source_node and source_node.drag_preview:
				if source_node.has_method("_cleanup_drag_preview"):
					source_node._cleanup_drag_preview()
			source_node.drag_preview = source_node._create_drag_preview(from_item_texture, source_remaining)
		# Don't call _stop_drag_cleanup() - let the user continue dragging the remainder
	else:
		# All items moved - source gets swapped item (if any) or becomes empty
		if source_node and source_node.has_method("set_item"):
			source_node.set_item(temp_texture, temp_stack_count)
		# Update InventoryManager
		if InventoryManager:
			if temp_texture:
				InventoryManager.add_item_to_toolkit(source_slot_index, temp_texture, temp_stack_count)
			else:
				InventoryManager.remove_item_from_toolkit(source_slot_index)
		
		# CRITICAL: Stop dragging on the source slot to clean up ghost icon and drag state
		if source_node and source_node.has_method("_stop_drag_cleanup"):
			source_node._stop_drag_cleanup()
		elif source_node:
			# Fallback: directly clear drag state if method doesn't exist
			if "is_dragging" in source_node:
				source_node.is_dragging = false
			if "_is_right_click_drag" in source_node:
				source_node._is_right_click_drag = false
			if "drag_preview" in source_node and source_node.drag_preview:
				if source_node.has_method("_cleanup_drag_preview"):
					source_node._cleanup_drag_preview()
```

**Key Changes**:
1. When `source_remaining > 0` and swapping different item types: source slot gets `temp_texture, temp_stack_count` (swapped item)
2. Remaining items (`source_remaining`) stay on cursor by updating drag state instead of calling `_stop_drag_cleanup()`
3. Drag preview is updated to show remaining count
4. Matches the inventory-to-inventory right-click swap logic pattern

## Future Enhancements

- Remove all debug print statements after testing
- Add sound effects for drag/drop operations
- Consider adding visual feedback for invalid drops
- Optimize drag preview creation/destruction if performance issues arise
