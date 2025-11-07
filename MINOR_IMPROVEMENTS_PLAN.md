# Minor Improvements Plan

Ranked by ROI (Performance + Extensibility)

---

## 1. Replace Deep Node Paths in hud.gd (HIGH ROI)

**Files Affected:**
- `scripts/singletons/hud.gd`

**Rationale:**
- 5 instances of `/root/Farm/Hud/HUD/MarginContainer/HBoxContainer` hardcoded path
- Fragile to scene structure changes
- Performance: repeated `get_node()` calls in hot paths (highlight, slot lookup)
- Extensibility: Cannot easily change HUD structure

**Exact Edit Steps:**
1. Add `@onready var slots_container: HBoxContainer` at top
2. Cache container reference in `setup_hud()`: `slots_container = get_node_or_null("HUD/MarginContainer/HBoxContainer")` (relative path since HUD is parent)
3. Replace all 5 `get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer")` calls with `slots_container`
4. Add null checks before using `slots_container`
5. Cache `tool_buttons` array once per function instead of re-fetching

**Expected Benefit:**
- Performance: Eliminates 5+ node path traversals per interaction
- Extensibility: HUD structure changes only require updating one reference
- Maintainability: Single source of truth for container location

**Rollback Note:**
- Revert to absolute paths if scene structure changes break relative path resolution
- Keep original paths in comments for reference

---

## 2. Remove Hardcoded Paths in SignalManager._ready() (HIGH ROI)

**Files Affected:**
- `scripts/singletons/signal_manager.gd`

**Rationale:**
- Hardcoded `/root/Farm/FarmingManager` and `/root/Farm/Hud` paths
- Breaks if scene name changes or structure differs
- Should use groups or injected references

**Exact Edit Steps:**
1. Add nodes to groups: `FarmingManager` → "farming_manager", HUD → "hud"
2. Replace `get_node_or_null("/root/Farm/FarmingManager")` with `get_tree().get_first_node_in_group("farming_manager")`
3. Replace `get_node_or_null("/root/Farm/Hud")` with `get_tree().get_first_node_in_group("hud")`
4. Add null checks and error handling
5. Alternatively: Use signals from UiManager/FarmScene to register managers on scene load

**Expected Benefit:**
- Extensibility: Works with any scene structure
- Maintainability: No hardcoded paths to maintain
- Flexibility: Multiple managers can exist, first one found is used

**Rollback Note:**
- Revert to absolute paths if group system causes conflicts
- Keep group names documented in project standard

---

## 3. Extract Magic Numbers to UI Config Resource (MEDIUM ROI)

**Files Affected:**
- `scripts/singletons/hud.gd`
- `scripts/singletons/inventory_manager.gd`
- `scripts/game_systems/farming_manager.gd`
- `scripts/droppable/droppable_item.gd`
- `scripts/ui/tool_switcher.gd`
- `resources/data/ui_config.tres` (NEW)

**Rationale:**
- Magic numbers scattered: 10 (HUD slots), 12 (inventory slots), 64 (drag preview size), 99 (max stack), 1.5 (interaction distance)
- Hard to adjust without code changes
- No single source of truth

**Exact Edit Steps:**
1. Create `scripts/data/ui_config.gd` extending Resource:
   ```gdscript
   extends Resource
   class_name UIConfig
   @export var hud_slot_count: int = 10
   @export var inventory_slot_count: int = 12
   @export var drag_preview_size: Vector2 = Vector2(64, 64)
   @export var max_item_stack: int = 99
   @export var interaction_distance: float = 1.5
   ```
2. Create `resources/data/ui_config.tres` with default values
3. Load config in singletons: `var ui_config = preload("res://resources/data/ui_config.tres")`
4. Replace magic numbers with `ui_config.hud_slot_count`, etc.

**Expected Benefit:**
- Extensibility: Easy to adjust values without code changes
- Maintainability: Single source of truth
- Designer-friendly: Can edit in inspector

**Rollback Note:**
- Revert to hardcoded constants if Resource loading adds complexity
- Keep original values in comments

---

## 4. Consolidate Tool Mapping to Single Source (MEDIUM ROI)

**Files Affected:**
- `scripts/singletons/signal_manager.gd`
- `scripts/game_systems/farming_manager.gd`

**Rationale:**
- Tool mapping duplicated: `SignalManager.TOOL_MAP` and `FarmingManager._get_tool_name_from_texture()`
- Risk of inconsistency when adding new tools
- `_get_tool_name_from_texture()` is unused (dead code)

**Exact Edit Steps:**
1. Remove `_get_tool_name_from_texture()` from FarmingManager (unused)
2. Ensure all tool lookups use `SignalManager.get_tool_name()`
3. Add validation: if tool not found, log warning
4. Consider moving TOOL_MAP to UIConfig Resource for designer access

**Expected Benefit:**
- Maintainability: Single source of truth
- Consistency: No risk of mismatched mappings
- Code clarity: Removes dead code

**Rollback Note:**
- Keep duplicate method commented if needed for fallback
- Document tool mapping location in project standard

---

## 5. Optimize _process() Calls (MEDIUM-HIGH ROI)

**Files Affected:**
- `scripts/singletons/hud.gd`
- `scripts/singletons/ui_manager.gd`

**Rationale:**
- `hud.gd._process()` only updates drag preview position (could use `_input()` or signal)
- `ui_manager.gd._process()` checks scene name every frame (could use scene change signal)

**Exact Edit Steps:**
1. **hud.gd**: Move drag preview update to `_input()` when mouse moves, or use `NOTIFICATION_WM_MOUSE_ENTER`/`EXIT`
2. **ui_manager.gd**: Use `get_tree().current_scene_changed` signal instead of polling
3. Disable `_process()` when not needed: `set_process(false)` when no drag active

**Expected Benefit:**
- Performance: Eliminates unnecessary per-frame checks
- Battery life: Reduces CPU usage on mobile
- Code clarity: Event-driven is more explicit

**Rollback Note:**
- Revert to `_process()` if event-driven approach misses edge cases
- Keep `_process()` disabled by default, enable only when needed

---

## 6. Cache Frequently Used Nodes (MEDIUM ROI)

**Files Affected:**
- `scripts/singletons/inventory_manager.gd`
- `scripts/droppable/droppable_generic.gd`
- `scripts/ui/tool_switcher.gd`

**Rationale:**
- Repeated `get_node_or_null("CenterContainer/GridContainer")` calls
- `get_node()` calls in loops or hot paths
- Can cache once and reuse

**Exact Edit Steps:**
1. Add `var grid_container: GridContainer` class variable
2. Cache in `_ready()` or first use: `grid_container = get_node_or_null("CenterContainer/GridContainer")`
3. Replace repeated `get_node()` calls with cached reference
4. Add null checks before use

**Expected Benefit:**
- Performance: Eliminates repeated node traversal
- Code clarity: Clearer intent with named variable
- Maintainability: Path only defined once

**Rollback Note:**
- Revert to `get_node()` calls if caching causes issues with dynamic scene changes
- Keep path strings in comments

---

## 7. Add Typed Signal Declarations (LOW-MEDIUM ROI)

**Files Affected:**
- `scripts/singletons/hud.gd`
- `scripts/ui/hud_slot.gd`
- `scripts/inventory/inventory_slot.gd`

**Rationale:**
- Some signals lack type hints in declaration
- Type hints improve IDE support and catch errors early
- Already partially done (SignalManager has typed signals)

**Exact Edit Steps:**
1. Review all signal declarations
2. Add type hints: `signal tool_changed(slot_index: int, item_texture: Texture)`
3. Ensure consistency across similar signals

**Expected Benefit:**
- Code quality: Better IDE autocomplete
- Error prevention: Type checking at signal connection time
- Documentation: Signals self-document their parameters

**Rollback Note:**
- Type hints are additive, no breaking changes
- Remove if Godot version compatibility issues arise

---

## 8. Verify InputMap Usage Only (LOW ROI)

**Files Affected:**
- All input-handling scripts

**Rationale:**
- Project standard requires InputMap usage
- Need to verify no hardcoded keycodes exist
- Already appears compliant, but worth verification

**Exact Edit Steps:**
1. Search for `keycode`, `KEY_`, `InputEventKey.keycode`
2. Verify all input checks use `Input.is_action_pressed()` or `event.is_action_pressed()`
3. Document any exceptions (if needed for special cases)

**Expected Benefit:**
- Compliance: Matches project standard
- Maintainability: Input changes only require InputMap updates
- User experience: Easier to rebind keys

**Rollback Note:**
- No changes needed if already compliant
- Document any exceptions in project standard

---

## Implementation Priority Summary

1. **#1 (hud.gd paths)** - HIGH ROI, low risk, immediate performance gain
2. **#2 (SignalManager paths)** - HIGH ROI, medium risk, improves flexibility
3. **#5 (_process optimization)** - MEDIUM-HIGH ROI, low risk, performance gain
4. **#6 (node caching)** - MEDIUM ROI, low risk, incremental improvement
5. **#4 (tool mapping)** - MEDIUM ROI, low risk, code quality
6. **#3 (magic numbers)** - MEDIUM ROI, medium risk, requires Resource creation
7. **#7 (typed signals)** - LOW-MEDIUM ROI, no risk, code quality
8. **#8 (InputMap verification)** - LOW ROI, no risk, compliance check

