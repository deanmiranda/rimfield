# Chest Inventory Refactor - Testing Guide

## Important: First Steps

**RESTART GODOT** before testing! The new autoload singleton (DragManager) needs to be loaded.

The linter errors you see are expected and will disappear after Godot reloads the project.

---

## What Was Refactored

### New System Components:
1. **DragManager** (singleton) - Global drag state coordinator
2. **SlotBase** (class) - Clean slot component with custom mouse handling
3. **ContainerBase** (class) - Abstract base for all inventory containers
4. **ChestContainer** (refactored) - Chest inventory using new system

### Integration Points:
- **HUD slots** now detect when chest is open and route to DragManager
- **Existing HUD-to-HUD** drags still use old system (unchanged)
- **Chest-to-HUD** and **HUD-to-Chest** use new DragManager system

---

## Testing Checklist

### Test 1: Basic Chest Opening
1. Start game
2. Place chest on farm
3. **Right-click on chest** to open it
4. **Expected:** Chest UI appears with 24 empty slots
5. Press ESC or click "Close" button to close
6. **Expected:** Chest UI closes, game unpauses

**Console should show:**
```
[DragManager] Initialized
[ChestPanel] Ready: 24 chest slots created
[ChestPanel] Opening chest UI for: chest_X
```

### Test 2: HUD to Chest Transfer (LEFT-CLICK)
1. Have seeds in HUD slot (e.g., slot 3)
2. Open chest
3. Left-click and hold on HUD slot
4. **Expected:** Drag preview appears, follows mouse
5. Move to chest slot and release
6. **Expected:** 
   - Item appears in chest slot
   - HUD slot clears
   - NO GHOST ICON ON CURSOR
   - Stack count shows correctly

**Console should show:**
```
[DragManager] Started drag: container=Hud slot=3 texture=... count=10 right_click=false
[ChestPanel] Drop on slot X: from=Hud source_slot=3 texture=... count=10
[DragManager] Ended drag: source_slot=3 count=10
```

### Test 3: Chest to HUD Transfer
1. Have item in chest
2. Left-click chest slot
3. **Expected:** Drag preview appears
4. Move to HUD slot and release
5. **Expected:**
   - Item moves to HUD
   - Chest slot clears
   - NO GHOST ICON

**Console should show:**
```
[SlotBase] Starting drag from slot X: ... x10 right_click=false
[HudSlot] DragManager drop: from=chest_X slot=X texture=... count=10
```

### Test 4: Chest Internal Swap
1. Have items in chest slots 0 and 5
2. Drag from slot 0 to slot 5
3. **Expected:** Items swap positions cleanly

### Test 5: Right-Click Drag (Peel Single Item)
1. Have stack of 10 seeds in HUD
2. Open chest
3. RIGHT-CLICK (not hold, just click) on HUD stack
4. **Expected:** Drag preview shows "1" (not "10")
5. Drop in chest
6. **Expected:**
   - Chest gets 1 seed
   - HUD has 9 seeds left

**Console should show:**
```
[DragManager] Started drag: ... count=1 right_click=true
```

### Test 6: Shift-Click Quick Transfer
1. Have item in chest slot
2. Shift+Left-Click the chest slot
3. **Expected:** Item transfers to player inventory automatically

### Test 7: ESC Key Cancel
1. Start dragging from HUD to chest
2. Press ESC while dragging
3. **Expected:**
   - Drag preview disappears
   - Item returns to source slot
   - Console: `[DragManager] ESC pressed - canceling drag`

### Test 8: Close Chest While Dragging
1. Start dragging from chest
2. Press ESC or click Close button
3. **Expected:**
   - Drag cancels
   - Item returns to chest slot
   - Chest closes normally

### Test 9: Persistence
1. Add items to chest
2. Close chest (E key)
3. Reopen chest (E key)
4. **Expected:** Items are still there

### Test 10: Auto-Sort
1. Add various items to chest in random slots
2. Click "Auto Sort" button
3. **Expected:** Items stack and sort alphabetically

---

## If You See Errors

### "Identifier DragManager not declared"
- **Fix:** Restart Godot to load the new autoload

### "Could not find base class ContainerBase"
- **Fix:** Restart Godot to parse the new class

### "Chest slots don't appear"
- Check console for error messages during `_setup_chest_slots()`

### "Ghost icon stuck on cursor"
- Check if `DragManager.cleanup_preview()` is being called
- Share full console output

---

## Success Criteria

All 10 tests pass without:
- Ghost icons stuck on cursor
- Grayed-out items
- Items disappearing
- Crashes or errors

If successful, the system is ready for Phase 2 (migrate player inventory panel).

