# Phase 1: Toolkit/HUD Migration - Testing

## What Was Changed

### New Files Created
- `scripts/ui/toolkit_container.gd` - Container that owns HUD/toolkit data
- `scripts/ui/hud_initializer.gd` - Initializes HUD with SlotBase slots

### Modified Files
- `scenes/ui/hud.tscn` - Added hud_initializer.gd script to root node
- `scripts/singletons/inventory_manager.gd` - Added toolkit_container reference, delegated methods
- `scripts/ui/tool_switcher.gd` - Updated to consume ToolkitContainer signals
- `scripts/ui/slot_base.gd` - Added tool_selected signal for ToolSwitcher

### Old System (Still Present)
- `scripts/ui/hud_slot.gd` - Still exists, but will be replaced by SlotBase
- HUD slots in scene still reference hud_slot.gd (will be replaced at runtime by initializer)

## How It Works

1. **HUD loads** → `hud_initializer.gd` runs
2. **Creates ToolkitContainer** → owns toolkit data
3. **Replaces each HUD slot** → removes old hud_slot.gd, adds SlotBase
4. **Connects to ToolkitContainer** → slots use DragManager system
5. **Migrates existing data** → from InventoryManager.toolkit_slots to container
6. **ToolSwitcher subscribes** → to container signals for tool changes

## Test Checklist

### Basic Functionality
- [ ] Game loads without errors
- [ ] HUD appears with 10 slots
- [ ] Existing items from previous save are loaded correctly
- [ ] Slot selection works (click empty or filled slot)
- [ ] Tool highlighting works (active tool shows correctly)

### Drag & Drop
- [ ] Left-click drag full stack from HUD slot
- [ ] Drop on another HUD slot (swap/stack)
- [ ] Drop on chest slot (transfer)
- [ ] Drop on world (throw item if allowed)
- [ ] Ghost preview visible during drag
- [ ] Visual feedback (semi-transparent source slot)

### Tool Switching
- [ ] Keyboard shortcuts (1-0 keys) work
- [ ] Active tool updates correctly
- [ ] Tool follows if moved to different slot
- [ ] ToolSwitcher emits correct signals

### Integration with Existing Systems
- [ ] Chest to HUD transfer works
- [ ] Player inventory to HUD transfer works (if pause menu open)
- [ ] Farming actions use correct active tool
- [ ] Droppables can be picked up to HUD
- [ ] Save/load preserves HUD items

### Edge Cases
- [ ] ESC cancels drag
- [ ] Same-slot click selects tool (doesn't drag)
- [ ] Drag threshold works (must move 5px to drag)
- [ ] Scene transitions don't break HUD
- [ ] No ghost icons stuck on cursor
- [ ] No data loss or duplication

## Expected Console Output

On game start:
```
[ToolkitContainer] Migrating data from InventoryManager...
[ToolkitContainer] Migrated slot X: <texture> xY
[ToolkitContainer] Initialized: 10 slots, max stack 9
[HudInitializer] Created 10 toolkit slots
[HudInitializer] Linked ToolkitContainer to InventoryManager
[ToolSwitcher] Connecting to ToolkitContainer...
[ToolSwitcher] Connected to ToolkitContainer
```

On drag:
```
[SlotBase] Starting drag from slot X: <texture> xY right_click=false
[DragManager] Started drag: container=Control slot=X texture=<path> count=Y
[DragManager] Creating drag preview for: <path>
[DragManager] Preview layer visible: true, preview visible: true
[DragManager] Initial mouse position: (X, Y)
```

On drop:
```
[SlotBase] Handling drop on slot Y
[DragManager] Ended drag: source_slot=X count=Y
[ChestPanel] Drop on slot Y: from=Control source_slot=X...
[ChestPanel] Placing in empty slot Y
```

## Known Issues (Expected)

- Linter warning: "ToolkitContainer not declared" → Restart Godot to fix
- Linter warning: "Confusable local declaration" → Harmless, can ignore
- Old hud_slot.gd still referenced in scene → Will be removed after testing

## Next Steps If Tests Pass

1. Delete `scripts/ui/hud_slot.gd` (2570 lines)
2. Update HUD scene to remove old slot references (clean up ext_resource)
3. Move to Phase 2: Player Inventory Migration

## Next Steps If Tests Fail

1. Check console for specific errors
2. Verify ToolkitContainer.instance is set
3. Verify slots are created correctly
4. Debug specific failing test case

