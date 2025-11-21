# Code Cleanup Review - Today's Changes

## Issues Found

### 1. **Deprecated/Unused Code in `inventory_menu_slot.gd`**

**Issue:** The file has BOTH manual drag system AND Godot's built-in drag system, which could cause conflicts.

**Deprecated Functions:**
- `get_drag_data()` (lines 375-425) - Old Godot drag system, but manual drag is now used in `_gui_input()`
- `_notification(what: int)` with `NOTIFICATION_DRAG_END` (lines 611-618) - Only used by old drag system
- `custom_drag_preview` variable and `_process()` (lines 19, 80-86) - Only used by `get_drag_data()`

**Recommendation:** 
- Remove `get_drag_data()` if manual drag is working correctly
- Remove `_notification()` handler for `NOTIFICATION_DRAG_END`
- Remove `custom_drag_preview` and `_process()` if not needed
- Keep `can_drop_data()` and `drop_data()` as they're still used by toolkit→inventory drops

### 2. **Deprecated Code in `hud_slot.gd`**

**Issue:** `get_drag_data()` function exists but is not used (manual drag is implemented).

**Deprecated Function:**
- `get_drag_data()` (lines 93-125) - Not called anywhere, manual drag is used instead

**Recommendation:** Remove `get_drag_data()` from `hud_slot.gd`

### 3. **Debug Print Statements**

**Issue:** Several debug print statements left in code.

**Files with Debug Prints:**
- `scripts/ui/hud_slot.gd` - 9 debug print statements (lines 124, 505, 507, 509, 576, 628, 638, 762, 776)

**Recommendation:** Remove all debug print statements or convert to proper logging system

### 4. **Code Duplication**

**Issue:** Significant duplication between `hud_slot.gd` and `inventory_menu_slot.gd` for drag-and-drop functions.

**Duplicated Functions:**
- `_create_drag_preview()` - Similar but with minor differences (hud_slot has count parameter)
- `_stop_drag()` - Very similar logic
- `_handle_drop()` - Similar but different drop target logic
- `_cleanup_drag_preview()` - Similar cleanup logic
- `_update_drag_preview_position()` - Identical

**Differences:**
- `hud_slot.gd` has right-click drag support (`_start_right_click_drag()`, `_is_right_click_drag`)
- `hud_slot.gd` has `_cancel_drag()` and `_remove_orphaned_drag_layers()`
- `inventory_menu_slot.gd` has locked slot checks
- `inventory_menu_slot.gd` has `can_drop_data()` and `drop_data()` for receiving drops from toolkit

**Recommendation:** 
- Consider creating a shared base class or utility functions for common drag-and-drop logic
- Keep slot-specific differences (right-click, locked slots) in individual files
- This is lower priority - duplication is acceptable if it keeps code simpler

### 5. **Unused Variables**

**Issue:** `custom_drag_preview` in `inventory_menu_slot.gd` is only used by deprecated `get_drag_data()`

**Recommendation:** Remove if `get_drag_data()` is removed

## Priority Actions

### High Priority (Remove Deprecated Code)
1. ✅ Remove `get_drag_data()` from `hud_slot.gd` (not used)
2. ✅ Remove `get_drag_data()` from `inventory_menu_slot.gd` (if manual drag works)
3. ✅ Remove debug print statements from `hud_slot.gd`
4. ✅ Remove `_notification()` handler for `NOTIFICATION_DRAG_END` from `inventory_menu_slot.gd`
5. ✅ Remove `custom_drag_preview` and `_process()` from `inventory_menu_slot.gd` if `get_drag_data()` is removed

### Medium Priority (Code Quality)
1. Consider extracting common drag-and-drop logic to shared utility (future refactor)
2. Document why `can_drop_data()` and `drop_data()` are kept in `inventory_menu_slot.gd` (for toolkit→inventory drops)

### Low Priority (Nice to Have)
1. Create shared base class for drag-and-drop slots (major refactor, not urgent)

## Notes

- `can_drop_data()` and `drop_data()` in `inventory_menu_slot.gd` are still needed for receiving drops from toolkit slots
- Manual drag system is working correctly, so old Godot drag system can be removed
- Right-click drag is only in `hud_slot.gd`, which is correct (toolkit only)

