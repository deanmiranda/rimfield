# Test: Old System Removal Verification

## Test Objective

Verify that old slot scripts (hud_slot.gd, inventory_menu_slot.gd) are NOT loaded at runtime.

## Test Procedure

1. **Tripwire Test:**
   - Run Godot
   - Start game
   - If old scripts load → game will crash with error: "OLD SLOT SYSTEM LOADED"
   - If game doesn't crash → old scripts are not being used ✅

2. **Functional Test:**
   - HUD appears with 10 slots
   - Items visible in HUD slots
   - Click HUD slot → tool selection works
   - Drag HUD item → drag works, ghost preview visible
   - Drop in chest → transfer works
   - Open pause menu → inventory slots visible
   - Drag inventory item → drag works
   - All UI uses DragManager system

3. **Console Verification:**
   - Look for tripwire errors (should be NONE)
   - Look for "SlotBase" initialization logs (should see many)
   - Look for "DragManager" drag logs (should see on drag)
   - No references to old scripts

## Expected Console Output (Success)

```
[ToolkitContainer] Migrating data from InventoryManager...
[ToolkitContainer] Initialized: 10 slots, max stack 9
[HudInitializer] Created 10 toolkit slots
[HudInitializer] Linked ToolkitContainer to InventoryManager
[ToolSwitcher] Connecting to ToolkitContainer...
[ToolSwitcher] Connected to ToolkitContainer
[ChestPanel] Created 24 chest slots (SlotBase)
[ChestPanel] Created 12 player slots (SlotBase)
[PauseMenu] Created 30 inventory slots (SlotBase)
```

## Expected Console Output (Failure - Old System Loaded)

```
❌ OLD SLOT SYSTEM LOADED: hud_slot.gd is deprecated! Use SlotBase instead.
❌ This script should be deleted. Check scenes/scripts for references.
FATAL ERROR: Assertion failed
```

## If Test Passes

- Delete scripts/ui/hud_slot.gd (2570 lines)
- Delete scripts/ui/inventory_menu_slot.gd (2324 lines)
- Move to Phase 2: Create PlayerInventoryContainer

## If Test Fails

- Check console for which script loaded
- Find and remove the reference
- Re-test

## Visual Checklist

- [ ] HUD slots appear with correct size/layout
- [ ] HUD slot items visible
- [ ] Active tool highlight works
- [ ] Pause menu inventory appears correctly
- [ ] Chest panel shows both chest and player inventory
- [ ] All slots are clickable
- [ ] All slots support drag/drop
- [ ] Ghost preview appears during drag

