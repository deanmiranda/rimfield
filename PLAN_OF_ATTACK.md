# Plan of Attack: Drag and Drop Implementation

## Overview
Implement bidirectional drag-and-drop functionality between the toolkit (HUD) and inventory (pause menu) to allow flexible tool/item organization.

**Estimated Total Time:** 4-6 hours  
**Priority:** Medium

---

## Current State Assessment

### ✅ Already Implemented
- `hud_slot.gd` has basic drag/drop methods (`get_drag_data`, `can_drop_data`, `drop_data`)
- `inventory_menu_slot.gd` has skeleton drag/drop methods
- Signals defined (`slot_drag_started`, `slot_drop_received`, `tool_selected`)
- Basic validation logic exists (locked slots, item checks)
- Inventory system functional (30 slots: 3 rows × 10 columns)
- Toolkit system functional (10 slots)
- `ToolSwitcher` exists with `tool_changed` signal
- `InventoryManager` singleton exists

### ⚠️ Needs Work
- `hud_slot.gd` uses `"source": self` instead of `"source": "toolkit"` (needs standardization)
- `inventory_menu_slot.gd` drop handlers incomplete
- `InventoryManager` lacks toolkit tracking methods
- No visual feedback for drag/drop operations
- No item swapping logic between toolkit ↔ inventory
- Missing edge case handling

---

## Implementation Strategy

### Phase 1: Toolkit → Inventory Drag (2-3 hours)
**Goal:** Enable dragging items from toolkit slots to inventory slots

#### Task 1.1: Standardize `hud_slot.gd` drag data structure
**File:** `scripts/ui/hud_slot.gd`
- [ ] Update `get_drag_data()` to return standardized Dictionary:
  ```gdscript
  {
      "slot_index": int,
      "item_texture": Texture,
      "source": "toolkit",  # Changed from self
      "source_node": Node   # Keep reference for swapping
  }
  ```
- [ ] Add `slot_drag_started` signal emission
- [ ] Ensure drag preview is properly configured

#### Task 1.2: Complete `inventory_menu_slot.gd` drop handlers
**File:** `scripts/ui/inventory_menu_slot.gd`
- [ ] Complete `can_drop_data()`:
  - Check if slot is locked (`is_locked`)
  - Validate data structure (has `item_texture`, `source` == "toolkit")
  - Return `true` if valid, `false` otherwise
- [ ] Complete `drop_data()`:
  - Update slot texture using `set_item()`
  - Emit `slot_drop_received` signal
  - Handle swapping if slot already occupied

#### Task 1.3: Add toolkit tracking to `InventoryManager`
**File:** `scripts/singletons/inventory_manager.gd`
- [ ] Add `toolkit_slots: Dictionary = {}` to track toolkit items
- [ ] Initialize toolkit slots in `_ready()` (10 slots, indices 0-9)
- [ ] Add method: `add_item_from_toolkit(slot_index: int, texture: Texture) -> bool`
- [ ] Add method: `remove_item_from_toolkit(slot_index: int) -> void`
- [ ] Add method: `get_toolkit_item(slot_index: int) -> Texture`
- [ ] Add method: `sync_toolkit_ui(hud_instance: Node) -> void` (update HUD slots)

#### Task 1.4: Connect signals and integrate systems
**Files:** Multiple
- [ ] Connect `hud_slot.slot_drag_started` → `InventoryManager` (if needed)
- [ ] Connect `inventory_menu_slot.slot_drop_received` → `InventoryManager.on_inventory_item_received()`
- [ ] Update `InventoryManager` to handle toolkit → inventory transfers
- [ ] Ensure HUD slots update when items are removed from toolkit

**Dependencies:** Tasks 1.1-1.3 must be complete before 1.4

---

### Phase 2: Visual Feedback (1 hour)
**Goal:** Provide clear visual feedback during drag/drop operations

#### Task 2.1: Enhance drag preview
**File:** `scripts/ui/hud_slot.gd`
- [ ] Improve drag preview in `get_drag_data()`:
  - Use proper size (64x64 or match slot size)
  - Set semi-transparent modulate (alpha 0.7)
  - Ensure preview follows mouse correctly

**File:** `scripts/ui/inventory_menu_slot.gd`
- [ ] Add drag preview in `get_drag_data()` (for Phase 3)

#### Task 2.2: Highlight valid drop targets
**File:** `scripts/ui/inventory_menu_slot.gd`
- [ ] Add visual feedback in `can_drop_data()`:
  - Change slot modulate/color when valid drop target
  - Reset modulate when `can_drop_data()` returns false
  - Use `modulate = Color(1.2, 1.2, 1.0, 1.0)` for highlight

**File:** `scripts/ui/hud_slot.gd`
- [ ] Add visual feedback in `can_drop_data()` (for Phase 3)

#### Task 2.3: Visual feedback for invalid drops
**File:** `scripts/ui/inventory_menu_slot.gd`
- [ ] Add brief red flash animation when drop is invalid
- [ ] Use `modulate` tween: `Color.RED` → `Color.WHITE` over 0.2 seconds
- [ ] Optional: Add shake animation using `position` tween

**Dependencies:** Phase 1 must be complete

---

### Phase 3: Inventory → Toolkit Drag (1-2 hours)
**Goal:** Enable dragging items from inventory slots to toolkit slots

#### Task 3.1: Complete `inventory_menu_slot.get_drag_data()`
**File:** `scripts/ui/inventory_menu_slot.gd`
- [ ] Update `get_drag_data()` to return standardized Dictionary:
  ```gdscript
  {
      "slot_index": int,
      "item_texture": Texture,
      "source": "inventory",
      "source_node": Node
  }
  ```
- [ ] Add drag preview (similar to `hud_slot.gd`)
- [ ] Emit `slot_drag_started` signal

#### Task 3.2: Complete toolkit slot drop handlers
**File:** `scripts/ui/hud_slot.gd`
- [ ] Update `can_drop_data()`:
  - Check if toolkit slot is valid (0-9)
  - Validate data structure (`source` == "inventory")
  - Return `true` if valid
- [ ] Update `drop_data()`:
  - Handle item swapping (if slot occupied)
  - Update toolkit slot texture
  - Notify `InventoryManager` and `ToolSwitcher`

#### Task 3.3: Update `ToolSwitcher` for toolkit changes
**File:** `scripts/ui/tool_switcher.gd`
- [ ] Add method: `update_toolkit_slot(slot_index: int, texture: Texture) -> void`
- [ ] Emit `tool_changed` signal if active slot is updated
- [ ] Update `current_tool_texture` and `current_tool` if needed

#### Task 3.4: Update `InventoryManager` for inventory removals
**File:** `scripts/singletons/inventory_manager.gd`
- [ ] Add method: `remove_item_from_inventory(slot_index: int) -> void`
- [ ] Add method: `add_item_to_toolkit(slot_index: int, texture: Texture) -> bool`
- [ ] Update `sync_inventory_ui()` to handle removals
- [ ] Ensure inventory slots clear when items moved to toolkit

**Dependencies:** Phase 1 and Phase 2 must be complete

---

### Phase 4: Data Synchronization & Edge Cases (1-2 hours)
**Goal:** Handle item swapping, empty slots, persistence, and edge cases

#### Task 4.1: Implement item swapping logic
**Files:** `scripts/ui/inventory_menu_slot.gd`, `scripts/ui/hud_slot.gd`
- [ ] When dragging to occupied slot, swap items instead of replacing
- [ ] Handle toolkit ↔ inventory swaps
- [ ] Handle toolkit ↔ toolkit swaps (within same container)
- [ ] Handle inventory ↔ inventory swaps (within same container)

#### Task 4.2: Handle empty slots
**Files:** Multiple
- [ ] Clear slot texture when item is dragged away
- [ ] Update slot state (empty vs occupied)
- [ ] Ensure `empty_texture` is restored when slot becomes empty
- [ ] Update `InventoryManager` dictionaries when slots cleared

#### Task 4.3: Persist changes (if needed)
**Files:** `scripts/singletons/inventory_manager.gd`, `scripts/singletons/game_state.gd` (if exists)
- [ ] Update `GameState` with inventory/toolkit changes
- [ ] Save on game save (if save system exists)
- [ ] Load inventory/toolkit state on game load

#### Task 4.4: Handle edge cases
**Files:** Multiple
- [ ] Dragging to same slot (no-op, return early)
- [ ] Dragging locked inventory slots (prevent in `can_drop_data()`)
- [ ] Dragging when menu is closing (cancel drag, check menu state)
- [ ] Multiple rapid drags (add drag state flag, prevent concurrent drags)
- [ ] Dragging empty slots (prevent in `get_drag_data()`)

**Dependencies:** Phases 1-3 must be complete

---

### Phase 5: Testing & Polish (30 min - 1 hour)
**Goal:** Verify all functionality works correctly

#### Test Scenarios
- [ ] **Test 1:** Toolkit → Inventory (all 10 toolkit slots)
- [ ] **Test 2:** Inventory → Toolkit (all 30 inventory slots)
- [ ] **Test 3:** Swapping items between toolkit and inventory
- [ ] **Test 4:** Swapping items within toolkit
- [ ] **Test 5:** Swapping items within inventory
- [ ] **Test 6:** Dragging to locked inventory slots (should fail gracefully)
- [ ] **Test 7:** Dragging empty slots (should fail gracefully)
- [ ] **Test 8:** Rapid drag operations (should not cause errors)
- [ ] **Test 9:** Drag preview follows mouse correctly
- [ ] **Test 10:** Visual feedback works (highlighting, invalid drop flash)

#### Polish Tasks
- [ ] Remove debug `print()` statements
- [ ] Add error handling for edge cases
- [ ] Ensure consistent code style
- [ ] Verify no performance issues with rapid operations

**Dependencies:** All previous phases must be complete

---

## Technical Specifications

### Data Structure
```gdscript
{
    "slot_index": int,           # Source slot index
    "item_texture": Texture,      # Item texture
    "source": String,            # "toolkit" or "inventory"
    "source_node": Node          # Reference to source slot node (for swapping)
}
```

### Signal Flow
```
Toolkit Slot (drag start)
  → emit slot_drag_started(slot_index, texture)
  → InventoryManager.on_toolkit_item_dragged()

Inventory Slot (drop)
  → emit slot_drop_received(slot_index, data)
  → InventoryManager.on_inventory_item_received()
  → Update inventory data
  → Update HUD toolkit (if needed)
```

### Godot Drag & Drop API
- `get_drag_data(position: Vector2) -> Variant`: Called when drag starts, return data Dictionary
- `can_drop_data(position: Vector2, data: Variant) -> bool`: Called during drag, return true if valid drop target
- `drop_data(position: Vector2, data: Variant) -> void`: Called when drop occurs, handle the data
- `set_drag_preview(control: Control)`: Set visual preview that follows mouse

---

## File Modification Summary

### Files to Modify
1. `scripts/ui/hud_slot.gd` - Toolkit slot drag/drop
2. `scripts/ui/inventory_menu_slot.gd` - Inventory slot drag/drop
3. `scripts/singletons/inventory_manager.gd` - Data management
4. `scripts/ui/tool_switcher.gd` - Toolkit updates
5. `scripts/singletons/hud.gd` - HUD updates (if needed)
6. `scripts/ui/pause_menu.gd` - Menu handling (if needed)

### Files to Review (No Changes Expected)
- `scenes/ui/hud.tscn` - Verify scene structure
- `scenes/ui/inventory_menu.tscn` - Verify scene structure

---

## Risk Assessment

### Low Risk
- Visual feedback implementation
- Testing and polish

### Medium Risk
- Data synchronization between systems
- Edge case handling
- Signal connections

### High Risk
- Item swapping logic (complex state management)
- Persistence integration (if save system is complex)

---

## Success Criteria

✅ **Phase 1 Complete When:**
- Can drag toolkit items to inventory slots
- Items appear in inventory after drop
- Toolkit slots clear when items moved

✅ **Phase 2 Complete When:**
- Drag preview follows mouse
- Valid drop targets highlight
- Invalid drops show visual feedback

✅ **Phase 3 Complete When:**
- Can drag inventory items to toolkit slots
- Items appear in toolkit after drop
- Inventory slots clear when items moved

✅ **Phase 4 Complete When:**
- Items swap correctly between occupied slots
- Empty slots handled properly
- Edge cases handled gracefully

✅ **Phase 5 Complete When:**
- All test scenarios pass
- No errors in console
- Smooth user experience

---

## Notes

- Follow `.cursor/rules/godot.md` patterns for code style
- Use type hints for all functions (`-> void`, `-> bool`, etc.)
- Use `@onready` for cached node references
- Avoid magic numbers (use GameConfig/ToolConfig resources)
- Add null checks for all node accesses
- Use `get_node_or_null()` instead of `get_node()` where nodes might not exist

---

## Future Enhancements (Post-MVP)
- Drag multiple items at once (shift+drag)
- Drag to trash/delete items
- Drag to combine/stack items
- Drag to quick-use items
- Drag to equip items (if equipment system exists)
- Visual drag preview with item count/stack size
- Sound effects for drag/drop operations

