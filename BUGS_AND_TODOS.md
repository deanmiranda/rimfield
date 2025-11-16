# Bugs and TODOs

## High Priority Bugs

### Tool Interaction Range Issue
**Problem:** Tools currently work when clicking anywhere on the mouse area, not just on tiles near the character.

**Expected Behavior:** Tools should only work on the 8 tiles closest to the character (the 3x3 grid centered on the player, minus the center tile = 8 tiles).

**Files to Investigate:**
- `scripts/game_systems/farming_manager.gd` - Tool interaction logic
- `scripts/scenes/farm_scene.gd` - Mouse click handling
- Player position tracking

**Next Steps:**
1. Find where mouse clicks are being processed for tool interactions
2. Add distance/range check from player position
3. Only allow tool use if clicked tile is within 8 closest tiles (3x3 grid minus center)
4. Add visual feedback for valid/invalid tool use range

---

## Drag and Drop Issues

### Toolkit Drag and Drop Not Working
**Problem:** Drag and drop functionality is not working on toolkit slots.

**Current Status:** 
- Drag data structure is implemented
- Drop handlers are implemented
- Visual feedback is implemented
- But drag operations are not being triggered

**Investigation Needed:**
- Check if `get_drag_data()` is being called
- Verify mouse event handling
- Check if TextureButton drag/drop is properly enabled
- Test with simpler drag/drop implementation first

**Priority:** Fix toolkit drag/drop first, then inventory drag/drop

