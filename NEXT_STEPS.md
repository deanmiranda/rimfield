# Next Steps - Rimfield Development Roadmap

This document outlines the current development priorities and next steps for the Rimfield project.

---

## 🎯 Current Focus: Inventory Drag and Drop

**Priority:** HIGH  
**Status:** IN PROGRESS - Fixing Right-Click Bugs  
**Goal:** Fix left and right click behaviors for inventory drag and drop system

### Current Status
- 🚨 **Inventory left-click drag and drop:** Regression in inventory panel — dropping or swapping while a right-click drag is active destroys stacks.
- ⚠️ **Right-click drag and drop:** Toolkit solid; inventory panel `r l r l` and `r l l` sequences remain broken.

### Critical Bugs to Fix (Right-Click)

#### Bug 2.a: Items Destroyed Instead of Swapped ✅ FIXED
**Problem:** When right-click dragging multiple items (e.g., 2 items from a stack of 7) and dropping on a target slot with different item type, the target slot items are destroyed and replaced instead of being swapped back to the ghost slot.

**Expected Behavior:** 
- Ghost slot items → Target slot
- Target slot items → Ghost slot (swap, don't destroy)

**Status:** ✅ FIXED
- Updated `drop_data()` in `inventory_menu_slot.gd` to swap target items to ghost slot instead of keeping remaining items on cursor
- When right-click dragging different item types with remaining items, target items now go to ghost slot (swap)

**Files Modified:**
- `scripts/ui/inventory_menu_slot.gd` - `drop_data()` function (line ~1255-1290)

#### Bug 2.a.1: Items Destroyed on Invalid Drop ✅ FIXED
**Problem:** When dropping items into invalid locations (not a slot, not world map area), items are destroyed instead of returning to source slot.

**Expected Behavior:**
- Items should return to source slot if dropped in invalid location
- Guard against dropping in illegal positions:
  - Not a valid inventory slot
  - Not a valid toolkit slot  
  - Not a valid world map area
  - Any other invalid position

**Status:** ✅ FIXED
- Updated `_stop_drag()` in both files to restore items when drop fails on valid UI slots
- Added guards to prevent item destruction on invalid drops
- Items now restore to source slot if drop fails

**Files Modified:**
- `scripts/ui/inventory_menu_slot.gd` - `_stop_drag()` function (line ~395-402)
- `scripts/ui/hud_slot.gd` - `_stop_drag()` function (line ~367-380)

#### Bug 2.a.2: Ghost Image Lingering After Drop ✅ FIXED
**Problem:** Ghost icon remains visible on screen after dropping swapped items and clearing the ghost slot.

**Expected Behavior:**
- Ghost image should disappear immediately after drop
- No lingering ghost images on world map or inventory panel
- Proper cleanup of drag preview layers

**Status:** ✅ FIXED
- Modified `_stop_drag_cleanup()` to hide drag layer immediately before freeing
- Added search for orphaned drag layers in scene tree
- Ensured `_process` is stopped and `drag_preview` is freed correctly

**Files Modified:**
- `scripts/ui/inventory_menu_slot.gd` - `_stop_drag_cleanup()` function

#### Bug 2.a.3: Multiple Item Types in Ghost Slot ✅ FIXED
**Problem:** User could right-click drag items from different slots with different item types, allowing multiple item types to accumulate in the ghost slot. Ghost slot should only hold one item type at a time.

**Expected Behavior:**
- Ghost slot can only hold one item type
- Starting a new right-click drag with a different item type should cancel the existing drag
- Items from canceled drag should be restored to their source slot

**Status:** ✅ FIXED
- Added `_find_existing_drag_texture()` to check for existing drags in both inventory and toolkit slots
- Added `_cancel_existing_drag_from_other_slot()` and `_cancel_existing_drag_from_toolkit()` for inventory slots
- Added `_cancel_existing_drag_from_inventory()` and `_cancel_existing_drag_from_other_toolkit_slot()` for toolkit slots
- Guard in `_start_right_click_drag()` cancels any existing drag with different item type before starting new one

**Files Modified:**
- `scripts/ui/inventory_menu_slot.gd` - `_start_right_click_drag()` and helper functions
- `scripts/ui/hud_slot.gd` - `_start_right_click_drag()` and helper functions

#### Bug 2.b: Inventory Panel `r l r l` / `r l l` Sequences Destroy Stacks 🚨 ACTIVE
**Problem:** When a right-click drag is active in the inventory panel, left-clicking another slot should cancel the drag and start a new one. Instead, the current logic attempts to drop the partial stack, causing item loss or duplication and preventing swaps.

**Expected Behavior:**
- Right-click drag active → left-click on another slot cancels the drag and starts a fresh left-click drag.
- Left-click drag active → clicking another slot should perform a swap/place, matching toolbar behavior.
- Dropping to empty slots must never destroy items; InventoryManager stays in sync.

**Status:** 🚧 IN PROGRESS
- Toolbar already satisfies both patterns; inventory panel needs parity with toolkit logic.
- Next step: Detect whether the dragging slot is performing a right-click or left-click drag and branch accordingly (cancel vs. receive drop).

**Files to Touch:**
- `scripts/ui/inventory_menu_slot.gd` (`_gui_input`, `_stop_drag`, `drop_data`)
- `scripts/ui/hud_slot.gd` (`_gui_input`)

#### Bug 2.c: Right-click Drops Blocked in Inventory & Toolbar 🚨 ACTIVE
**Problem:** After recent guarding changes, right-click drags cannot be dropped onto inventory slots or toolkit slots. As soon as the cursor is over a potential target, the existing drag is canceled instead of performing the drop. This also prevents left-click drags from placing stacks into empty toolkit slots (the empty slot cancels the drag instead of receiving it).

**Expected Behavior:**
- When another slot is dragging and the mouse is over the current slot, the slot should attempt to receive the drop (both left-click and right-click drags).
- Cancellation should only happen when the mouse is NOT over the target slot.

**Status:** 🚧 IN PROGRESS
- Need to reintroduce "receive drop" logic for same-source drags in both inventory and toolkit `_gui_input` handlers.
- Ensure `_cancel_existing_drag_from_*` helpers are only called when we truly intend to abandon the existing drag.

**Files to Touch:**
- `scripts/ui/inventory_menu_slot.gd` (`_gui_input`)
- `scripts/ui/hud_slot.gd` (`_gui_input`)

### Known Bugs (To Address After Drag/Drop)
- **Tool Interaction Range Issue:** Tools currently work when clicking anywhere, not just on tiles near the character. Should only work on the 8 tiles closest to the character (3x3 grid minus center). Files: `scripts/game_systems/farming_manager.gd`, `scripts/scenes/farm_scene.gd`

### Tasks

#### Left Click Drag and Drop
- [ ] **Fix left-click drag detection**
  - Ensure drag starts correctly on mouse press
  - Verify drag preview follows mouse smoothly
  - Test drag cancellation (releasing outside valid drop zones)

- [ ] **Fix left-click drop handling**
  - Inventory → Inventory: Item swapping works correctly
  - Inventory → Toolkit: Items move to toolkit slots properly
  - Toolkit → Inventory: Items move to inventory slots properly
  - Toolkit → Toolkit: Items swap within toolkit correctly

- [ ] **Fix left-click visual feedback**
  - Drag preview appears and follows cursor
  - Valid drop targets highlight correctly
  - Invalid drop targets show red flash
  - Source slot dims during drag

- [ ] **Fix left-click edge cases**
  - Dragging to same slot (no-op)
  - Dragging locked slots (prevent)
  - Dragging empty slots (prevent)
  - Dragging when menu is closing (cancel gracefully)
  - Multiple rapid drags (prevent race conditions)

#### Right Click Behavior
- [ ] **Implement right-click context menu**
  - Right-click on inventory slot shows context menu
  - Options: "Use", "Move to Toolkit", "Drop", "Info" (future)
  - Right-click on toolkit slot shows context menu
  - Options: "Move to Inventory", "Info" (future)

- [ ] **Alternative: Right-click quick actions**
  - Right-click on inventory slot → Quick move to first empty toolkit slot
  - Right-click on toolkit slot → Quick move to first empty inventory slot
  - Right-click on empty slot → No action (or show "Info" if slot has item info)

- [ ] **Right-click visual feedback**
  - Show context menu at cursor position
  - Highlight menu options on hover
  - Close menu on click outside or ESC key

#### Testing & Validation
- [ ] **Test all drag scenarios**
  - [ ] Toolkit → Inventory (all 10 toolkit slots)
  - [ ] Inventory → Toolkit (all 30 inventory slots)
  - [ ] Swapping items between toolkit and inventory
  - [ ] Swapping items within toolkit
  - [ ] Swapping items within inventory
  - [ ] Dragging to locked inventory slots (should fail gracefully)
  - [ ] Dragging empty slots (should fail gracefully)
  - [ ] Rapid drag operations (should not cause errors)

- [ ] **Test right-click scenarios**
  - [ ] Right-click on inventory slot with item
  - [ ] Right-click on toolkit slot with item
  - [ ] Right-click on empty slots
  - [ ] Context menu interactions
  - [ ] Menu closing behavior

- [ ] **Performance testing**
  - [ ] No lag during drag operations
  - [ ] Smooth drag preview movement
  - [ ] No memory leaks from drag preview layers
  - [ ] No errors in console during drag/drop

### Files to Modify
- `scripts/ui/inventory_menu_slot.gd` - Main inventory slot drag/drop logic
- `scripts/ui/hud_slot.gd` - Toolkit slot drag/drop logic
- `scripts/singletons/inventory_manager.gd` - Data synchronization
- `scripts/ui/tool_switcher.gd` - Toolkit updates
- `scenes/ui/inventory_scene.tscn` - Context menu UI (if needed)
- `scenes/ui/hud.tscn` - Context menu UI (if needed)

### Success Criteria
✅ Left-click drag and drop works flawlessly in all scenarios  
✅ Right-click behavior is implemented and intuitive  
✅ Visual feedback is clear and responsive  
✅ No errors or performance issues  
✅ Code follows project coding standards  

---

## 🔧 Code Technical Debt

**Priority:** MEDIUM  
**Status:** PENDING (After drag/drop is complete)  
**Goal:** Improve code quality, maintainability, and adherence to best practices

### High Priority Technical Debt

#### 1. Code Organization
- [ ] **Remove duplicate `utils/` directory**
  - Consolidate `scripts/util/` and `scripts/utils/` (empty) to `scripts/util/`

- [ ] **Fix script ordering**
  - Ensure all scripts follow: Signals → Constants → Exports → Vars → Functions

- [ ] **Remove commented-out code**
  - Clean up all commented-out debug code and old implementations

- [ ] **Consolidate duplicate code**
  - Review for duplicate logic that can be extracted to utility functions

#### 2. Magic Numbers Elimination
- [ ] **Audit all scripts for magic numbers**
  - Replace with GameConfig or ToolConfig references
  - Common magic numbers: `10` (HUD slots), `12` (inventory slots), `99` (max stack), `1.5` (interaction distance), `200` (player speed)

- [ ] **Create missing config resources**
  - Add any new config values needed to `resources/data/game_config.tres`

- [ ] **Document all config values**
  - Add comments explaining what each config value does

#### 3. Node Path References
- [ ] **Remove all `/root/...` paths** (if any remain)
  - Replace with dependency injection or `@onready` references
  - Verify with `scripts/verify_rules.ps1`

- [ ] **Audit `get_node()` calls**
  - Replace with `get_node_or_null()` where nodes might not exist
  - Cache frequently accessed nodes with `@onready`

- [ ] **Add null checks**
  - Ensure all node accesses have proper null checking

#### 4. Type Hints
- [ ] **Add missing type hints**
  - All variables and functions should have explicit types

- [ ] **Fix `-> void` returns**
  - Ensure all functions that return nothing use `-> void`

- [ ] **Type hint function parameters**
  - All parameters should have types

#### 5. Error Handling
- [ ] **Add error handling**
  - All resource loads and node accesses should check for null

- [ ] **Improve error messages**
  - Make error messages more descriptive and actionable

- [ ] **Add validation**
  - Validate inputs at function boundaries

### Medium Priority Technical Debt

#### 6. Performance Optimization
- [ ] **Review `_process()` functions**
  - Move expensive operations to timers or events
  - Verify no heavy polling logic remains

- [ ] **Cache node references**
  - Use `@onready` for frequently accessed nodes

- [ ] **Optimize signal connections**
  - Ensure signals are connected efficiently
  - Remove duplicate connections

#### 7. Code Duplication
- [ ] **Extract common patterns**
  - Create utility functions for repeated code
  - Note: Significant duplication between `hud_slot.gd` and `inventory_menu_slot.gd` for drag-and-drop functions

- [ ] **Consolidate similar scripts**
  - Review if multiple scripts can be merged
  - Consider creating shared base class or utility functions for common drag-and-drop logic

- [ ] **Create base classes**
  - Use inheritance for common functionality (e.g., base slot class)

- [ ] **Remove deprecated code**
  - Remove unused `get_drag_data()` from `hud_slot.gd` and `inventory_menu_slot.gd` if manual drag works
  - Remove debug print statements from `hud_slot.gd`
  - Remove `_notification()` handler for `NOTIFICATION_DRAG_END` from `inventory_menu_slot.gd`
  - Remove `custom_drag_preview` and `_process()` from `inventory_menu_slot.gd` if `get_drag_data()` is removed

#### 8. Documentation
- [ ] **Add file headers**
  - All scripts should have a brief description comment

- [ ] **Document public APIs**
  - All public functions should have doc comments

- [ ] **Explain complex logic**
  - Add comments for non-obvious algorithms

### Low Priority Technical Debt

#### 9. Code Style Consistency
- [ ] **Standardize spacing**
  - Ensure consistent blank line usage

- [ ] **Fix indentation**
  - Ensure all files use tabs consistently

- [ ] **Line length**
  - Break long lines appropriately

- [ ] **Remove trailing whitespace**
  - Clean up all files

#### 10. Signal Management
- [ ] **Document all signals**
  - Add comments explaining when signals are emitted

- [ ] **Review signal connections**
  - Ensure all connections are properly managed

- [ ] **Add signal disconnection**
  - Ensure signals are disconnected in cleanup

---

## 📦 Commit & Branch Management

**Priority:** MEDIUM  
**Status:** PENDING (After drag/drop and tech debt)  
**Goal:** Clean up branch and prepare for next features

### Tasks
- [ ] **Review all changes**
  - Ensure drag/drop fixes are complete
  - Verify technical debt items are addressed
  - Run `scripts/verify_rules.ps1` and fix any violations

- [ ] **Test all functionality**
  - Run full game test suite
  - Test all drag/drop scenarios
  - Test all existing features still work

- [ ] **Update documentation**
  - Update README.md if needed
  - Update NEXT_STEPS.md with completed items
  - Document any new patterns or changes

- [ ] **Commit changes**
  - Create meaningful commit messages
  - Group related changes logically
  - Follow commit message conventions

- [ ] **Push to branch**
  - Push `develop` branch to remote
  - Create PR if needed
  - Merge after review

---

## 🚀 Next Features

**Priority:** LOW  
**Status:** PLANNED (After commit)  
**Goal:** Plan and prioritize next feature development

### Potential Features to Review

#### Core Gameplay
- [ ] **Day/Night Cycle**
  - Time system with day progression
  - Visual day/night transitions
  - Time-based events

- [ ] **NPC Interactions**
  - NPC dialogue system
  - Quest system
  - Relationship tracking

- [ ] **Mining System**
  - Mine areas and mechanics
  - Ore collection
  - Mining tools

- [ ] **Crafting System**
  - Crafting recipes
  - Crafting UI
  - Resource combination

#### Systems & Mechanics
- [ ] **Weather System**
  - Weather effects on farming
  - Visual weather effects
  - Weather-based events

- [ ] **Player Upgrades**
  - Skill system
  - Player stats
  - Upgrade progression

- [ ] **Farm Upgrades**
  - Building construction
  - Farm expansion
  - Upgrade system

- [ ] **Equipment System**
  - Equipment slots
  - Equipment effects
  - Equipment UI

#### UI & UX
- [ ] **Save/Load System Enhancements**
  - Multiple save slots
  - Save game previews
  - Auto-save functionality

- [ ] **Settings Menu**
  - Graphics settings
  - Audio settings
  - Input remapping

- [ ] **Inventory Enhancements**
  - Item stacking
  - Item sorting
  - Item categories/tabs

- [ ] **Tooltips & Info**
  - Item tooltips
  - Context-sensitive help
  - Tutorial system

### Feature Planning Process
1. Review feature list and prioritize
2. Create feature branch
3. Design feature architecture
4. Implement feature
5. Test thoroughly
6. Document feature
7. Merge to develop

---

## 📝 Notes

- **Current Branch:** `develop`
- **Focus Order:**
  1. ✅ Inventory drag and drop (left/right click) - **CURRENT**
  2. ⏳ Code technical debt - **NEXT**
  3. ⏳ Commit branch - **THEN**
  4. ⏳ Review next features - **FINALLY**

- **Development Workflow:**
  - Work on current focus until complete
  - Run verification scripts before committing
  - Test thoroughly before moving to next phase
  - Document changes as you go

- **Questions or Issues:**
  - Review code comments and existing patterns
  - Check `.cursor/rules/godot.md` for standards
  - Run `scripts/verify_rules.ps1` for code quality checks

---

**Last Updated:** All critical right-click drag and drop bugs have been fixed! Ready to move to code technical debt cleanup.
