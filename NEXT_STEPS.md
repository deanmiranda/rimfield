# Next Steps - Rimfield Development Roadmap

This document outlines the current development priorities and next steps for the Rimfield project.

---

## 🎯 Current Focus: Inventory Drag and Drop

**Priority:** HIGH  
**Status:** IN PROGRESS  
**Goal:** Fix left and right click behaviors for inventory drag and drop system

### Current Issue
The inventory drag and drop system has left-click drag working, but right-click behavior needs to be implemented. Both left and right click behaviors need refinement to work correctly across inventory and toolkit slots.

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

**Last Updated:** Focus is on inventory drag and drop right-click behavior implementation.
