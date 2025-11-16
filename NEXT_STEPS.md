# Next Steps: Drag and Drop Implementation

## Overview
Implement drag-and-drop functionality to move tools between the toolkit (HUD) and inventory (pause menu). This will allow players to organize their tools and items flexibly.

## Current State
- ✅ `inventory_menu_slot.gd` has skeleton drag/drop methods (`get_drag_data`, `can_drop_data`, `drop_data`)
- ✅ Signals are defined (`slot_drag_started`, `slot_drop_received`)
- ✅ Basic validation logic exists (locked slots, item checks)
- ✅ Inventory system is functional with 30 slots (3 rows × 10 columns)
- ✅ Toolkit system is functional with 10 slots

## Implementation Plan

### Phase 1: Toolkit → Inventory Drag (2-3 hours)
**Files to modify:**
- `scenes/ui/hud.tscn` - Add drag support to toolkit slots
- `scripts/ui/hud_slot.gd` (if exists) or create new script for toolkit slots
- `scripts/ui/inventory_menu_slot.gd` - Complete `can_drop_data()` and `drop_data()` implementations
- `scripts/singletons/inventory_manager.gd` - Add methods to handle item addition/removal

**Tasks:**
1. Create or update toolkit slot script to implement `get_drag_data()`
   - Return Dictionary with: `{"slot_index": int, "item_texture": Texture, "source": "toolkit"}`
   - Emit `slot_drag_started` signal
2. Complete `inventory_menu_slot.gd` drop handlers
   - `can_drop_data()`: Check if slot is locked, validate data structure
   - `drop_data()`: Update slot texture, notify InventoryManager
3. Update `InventoryManager` to track toolkit items
   - Add method: `add_item_from_toolkit(slot_index: int, texture: Texture)`
   - Add method: `remove_item_from_toolkit(slot_index: int)`
4. Connect signals between systems
   - Toolkit slot → InventoryManager
   - Inventory slot → InventoryManager

### Phase 2: Visual Feedback (1 hour)
**Files to modify:**
- `scripts/ui/inventory_menu_slot.gd` - Add visual feedback methods
- `scripts/ui/hud_slot.gd` (or toolkit slot script) - Add visual feedback

**Tasks:**
1. Create drag preview texture that follows mouse
   - Use `Control.set_drag_preview()` in `get_drag_data()`
   - Create a small TextureRect with the item texture
2. Highlight valid drop targets
   - Add `_can_drop_data()` visual feedback (change slot color/border)
   - Reset on `_can_drop_data()` returning false
3. Visual feedback for invalid drops
   - Brief red flash or shake animation
   - Tooltip message (optional)

### Phase 3: Inventory → Toolkit Drag (1-2 hours)
**Files to modify:**
- `scripts/ui/inventory_menu_slot.gd` - Complete `get_drag_data()` implementation
- `scripts/ui/hud_slot.gd` (or toolkit slot script) - Implement `can_drop_data()` and `drop_data()`
- `scripts/singletons/hud.gd` - Handle toolkit updates

**Tasks:**
1. Complete `inventory_menu_slot.get_drag_data()`
   - Return Dictionary with: `{"slot_index": int, "item_texture": Texture, "source": "inventory"}`
2. Implement toolkit slot drop handlers
   - `can_drop_data()`: Check if toolkit slot is valid (0-9), validate data
   - `drop_data()`: Update toolkit slot texture, notify HUD/ToolSwitcher
3. Update `ToolSwitcher` to reflect toolkit changes
   - Add method: `update_toolkit_slot(slot_index: int, texture: Texture)`
   - Emit `tool_changed` signal if active slot is updated
4. Update `InventoryManager` to handle inventory removals
   - Add method: `remove_item_from_inventory(slot_index: int)`

### Phase 4: Data Synchronization & Edge Cases (1-2 hours)
**Files to modify:**
- `scripts/singletons/inventory_manager.gd` - Complete data management
- `scripts/ui/pause_menu.gd` - Handle inventory updates
- `scripts/singletons/hud.gd` - Handle toolkit updates

**Tasks:**
1. Implement item swapping logic
   - When dragging to occupied slot, swap items instead of replacing
   - Handle both toolkit ↔ inventory swaps
2. Handle empty slots
   - Clear slot texture when item is dragged away
   - Update slot state (empty vs occupied)
3. Persist changes (if needed)
   - Update `GameState` with inventory/toolkit changes
   - Save on game save
4. Edge cases:
   - Dragging to same slot (no-op)
   - Dragging locked inventory slots (prevent)
   - Dragging when menu is closing (cancel drag)
   - Multiple rapid drags (prevent race conditions)

### Phase 5: Testing & Polish (30 min - 1 hour)
**Test scenarios:**
1. Toolkit → Inventory (all 10 toolkit slots)
2. Inventory → Toolkit (all 30 inventory slots)
3. Swapping items between toolkit and inventory
4. Swapping items within toolkit
5. Swapping items within inventory
6. Dragging to locked inventory slots (should fail)
7. Dragging empty slots (should fail)
8. Rapid drag operations (should not cause errors)

## Technical Notes

### Godot Drag & Drop API
- `get_drag_data(position: Vector2) -> Variant`: Called when drag starts, return data Dictionary
- `can_drop_data(position: Vector2, data: Variant) -> bool`: Called during drag, return true if valid drop target
- `drop_data(position: Vector2, data: Variant) -> void`: Called when drop occurs, handle the data
- `set_drag_preview(control: Control)`: Set visual preview that follows mouse

### Data Structure
```gdscript
{
    "slot_index": int,           # Source slot index
    "item_texture": Texture,      # Item texture
    "source": String,            # "toolkit" or "inventory"
    "source_node": Node          # Reference to source slot node (optional)
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

## Estimated Total Time
**4-6 hours** (depending on complexity of edge cases and visual polish)

## Priority
**Medium** - Nice-to-have feature that improves UX but not critical for core gameplay.

## Dependencies
- Inventory system must be fully functional ✅
- Toolkit system must be fully functional ✅
- `InventoryManager` singleton must exist ✅
- `HUD` singleton must exist ✅

## Future Enhancements (Post-MVP)
- Drag multiple items at once (shift+drag)
- Drag to trash/delete items
- Drag to combine/stack items
- Drag to quick-use items
- Drag to equip items (if equipment system exists)
- Visual drag preview with item count/stack size
- Sound effects for drag/drop operations

