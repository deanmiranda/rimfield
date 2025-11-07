# Repository-Wide Improvements Plan

**Based on `.cursor/rules/godot.md` audit**

Generated: Repository-wide analysis of rule violations and improvement opportunities.

---

## Summary

**Total Issues Found:** 8 violations + 5 improvement opportunities  
**Critical Violations:** 1 (ternary operator)  
**High ROI Fixes:** 3  
**Medium ROI Fixes:** 5  
**Low ROI Fixes:** 4

---

## Critical Violations (Must Fix)

### 1. Ternary Operator in tool_switcher.gd ⚠️ **CRITICAL**

**File:** `scripts/ui/tool_switcher.gd:57`  
**Violation:** Uses ternary operator `if ... else` (disallowed by rules)  
**ROI:** HIGH (rule compliance)

**Current Code:**
```gdscript
var item_texture = hud_slot.get_texture() if hud_slot.has_method("get_texture") else null
```

**Fix:**
```gdscript
var item_texture: Texture = null
if hud_slot.has_method("get_texture"):
    item_texture = hud_slot.get_texture()
```

**Effort:** 2 minutes  
**Impact:** Rule compliance, code clarity  
**Migration Pattern:** N/A (simple refactor)

---

## High ROI Improvements

### 2. Replace _process() Polling in ui_manager.gd

**File:** `scripts/singletons/ui_manager.gd:31-38`  
**Violation:** Polls scene name every frame instead of using signals  
**ROI:** HIGH (performance + best practice)

**Current Code:**
```gdscript
func _process(delta: float) -> void:
    var current_scene = get_tree().current_scene
    if current_scene:
        var current_scene_name = current_scene.name
        if current_scene_name != last_scene_name:
            last_scene_name = current_scene_name
            update_input_processing()
            emit_signal("scene_changed", current_scene_name)
```

**Fix:** Use `get_tree().current_scene_changed` signal (Godot 4.x feature)

```gdscript
func _ready() -> void:
    # ... existing code ...
    get_tree().current_scene_changed.connect(_on_scene_tree_changed)
    set_process(false)  # Disable polling

func _on_scene_tree_changed() -> void:
    var current_scene = get_tree().current_scene
    if current_scene:
        var current_scene_name = current_scene.name
        if current_scene_name != last_scene_name:
            last_scene_name = current_scene_name
            update_input_processing()
            emit_signal("scene_changed", current_scene_name)
```

**Effort:** 10 minutes  
**Impact:** Eliminates per-frame check, better performance  
**Migration Pattern:** Pattern 2 (Signal-driven updates)

---

### 3. Replace _process() Polling in house_interaction.gd

**File:** `scripts/game_systems/house_interaction.gd:31-34`  
**Violation:** Polls input in `_process()` instead of `_input()`  
**ROI:** HIGH (performance + best practice)

**Current Code:**
```gdscript
func _process(_delta: float) -> void:
    if player_in_zone and Input.is_action_just_pressed("ui_interact"):
        SceneManager.change_scene(HOUSE_SCENE_PATH)
```

**Fix:** Move to `_input()` method

```gdscript
func _input(event: InputEvent) -> void:
    if player_in_zone and event.is_action_pressed("ui_interact"):
        SceneManager.change_scene(HOUSE_SCENE_PATH)
        get_viewport().set_input_as_handled()  # Prevent further processing
```

**Effort:** 5 minutes  
**Impact:** Eliminates per-frame check, more efficient input handling  
**Migration Pattern:** N/A (move to appropriate callback)

---

### 4. Cache Repeated get_node() Calls in tool_switcher.gd

**File:** `scripts/ui/tool_switcher.gd:19, 43`  
**Violation:** Calls `get_node("../HUD")` twice (should cache)  
**ROI:** HIGH (performance)

**Current Code:**
```gdscript
func _ready() -> void:
    var hud = get_node("../HUD")  # First call
    # ... code ...

func set_hud_by_slot(slot_index: int) -> void:
    var hud = get_node("../HUD")  # Second call (repeated)
```

**Fix:** Cache with `@onready var`

```gdscript
@onready var hud: Node = get_node("../HUD")

func _ready() -> void:
    if hud:
        # ... existing code ...

func set_hud_by_slot(slot_index: int) -> void:
    if not hud:
        print("Error: HUD not found.")
        return
    # ... rest of code ...
```

**Effort:** 5 minutes  
**Impact:** Eliminates repeated node lookup  
**Migration Pattern:** Pattern 1 (Same scene, cached reference)

---

## Medium ROI Improvements

### 5. Fix Script Ordering in farming_manager.gd

**File:** `scripts/game_systems/farming_manager.gd`  
**Violation:** Constants defined after exports (should be before)  
**ROI:** MEDIUM (code organization)

**Current Order:**
```gdscript
@export var farmable_layer_path: NodePath
@export var farm_scene_path: NodePath
var hud_instance: Node
# ... more vars ...
const TILE_ID_GRASS = 0  # Constants after exports/vars
const TILE_ID_DIRT = 1
```

**Fix:** Move constants to top (after signals, before exports)

```gdscript
extends Node

# Constants (should be after signals, before exports)
const TILE_ID_GRASS = 0
const TILE_ID_DIRT = 1
const TILE_ID_TILLED = 2
const TILE_ID_PLANTED = 3
const TILE_ID_GROWN = 4

@export var farmable_layer_path: NodePath
@export var farm_scene_path: NodePath
# ... rest of code ...
```

**Effort:** 3 minutes  
**Impact:** Follows script ordering standard  
**Migration Pattern:** N/A (reordering)

---

### 6. Extract Magic Numbers to Resource

**Files:** Multiple  
**Violation:** Magic numbers scattered across codebase  
**ROI:** MEDIUM (extensibility + maintainability)

**Magic Numbers Found:**
- `10` - HUD slot count (tool_switcher.gd:76, inventory_manager.gd:132)
- `12` - Inventory slot count (inventory_manager.gd:9)
- `99` - Max item stack (droppable_item.gd:8)
- `1.5` - Interaction distance (farming_manager.gd:66)
- `200` - Player speed (player.gd:6)

**Fix:** Create `resources/data/game_config.tres`

```gdscript
# scripts/data/game_config.gd
extends Resource
class_name GameConfig

@export var hud_slot_count: int = 10
@export var inventory_slot_count: int = 12
@export var max_item_stack: int = 99
@export var interaction_distance: float = 1.5
@export var player_speed: float = 200
```

**Usage:**
```gdscript
@onready var game_config: GameConfig = preload("res://resources/data/game_config.tres")

# Replace magic numbers
for i in range(game_config.hud_slot_count):
    # ...
```

**Effort:** 30 minutes  
**Impact:** Single source of truth, designer-friendly  
**Migration Pattern:** Pattern 4 (Resource-based config)

---

### 7. Consolidate Tool Mapping

**Files:** `scripts/ui/tool_switcher.gd`, `scripts/game_systems/farming_manager.gd`  
**Violation:** Tool mapping duplicated in two places  
**ROI:** MEDIUM (maintainability)

**Current:** Both files have `TOOL_MAP` constant with same data

**Fix:** Move to SignalManager (already exists) or create ToolConfig Resource

**Option A (Use SignalManager):**
- Remove `TOOL_MAP` from tool_switcher.gd
- Remove `_get_tool_name_from_texture()` from farming_manager.gd
- Use `SignalManager.get_tool_name()` everywhere

**Option B (Create Resource):**
- Create `resources/data/tool_config.tres`
- Export tool mappings as Resource
- Load in both places

**Recommendation:** Option A (SignalManager already has this)

**Effort:** 15 minutes  
**Impact:** Single source of truth, no duplication  
**Migration Pattern:** N/A (consolidation)

---

### 8. Replace get_node() with @onready in house_interaction.gd

**File:** `scripts/game_systems/house_interaction.gd:9`  
**Violation:** Uses `get_node()` in `_ready()` instead of `@onready`  
**ROI:** MEDIUM (best practice)

**Current Code:**
```gdscript
var interaction_label: Label

func _ready() -> void:
    interaction_label = get_node("Label")
```

**Fix:**
```gdscript
@onready var interaction_label: Label = $Label
```

**Effort:** 2 minutes  
**Impact:** Follows best practice, cleaner code  
**Migration Pattern:** Pattern 1 (Same scene, @onready)

---

## Low ROI Improvements (Nice to Have)

### 9. Add Type Hints to Signal Declarations

**Files:** Multiple  
**Violation:** Some signals lack full type hints  
**ROI:** LOW (code quality)

**Current:** Most signals have types, but some could be more explicit

**Effort:** 10 minutes  
**Impact:** Better IDE support, self-documenting  
**Migration Pattern:** N/A (additive improvement)

---

### 10. Cache get_node() in player.gd

**File:** `scripts/characters/player.gd:20`  
**Violation:** Uses `get_node()` in `_ready()` that could be cached  
**ROI:** LOW (minor optimization)

**Current Code:**
```gdscript
if farm_scene and farm_scene.has_node("FarmingManager"):
    farming_manager = farm_scene.get_node("FarmingManager")
```

**Note:** This is acceptable since it's conditional and only called once. Low priority.

**Effort:** 5 minutes  
**Impact:** Minor optimization  
**Migration Pattern:** Pattern 3 (Injection would be better, but requires refactor)

---

### 11. Review _process() in Other Files

**Files:** `scripts/ui/tile_highlighter.gd`, `scripts/game_systems/exit_zone.gd`, `scripts/characters/player.gd`  
**Violation:** `_process()` usage should be reviewed for heavy logic  
**ROI:** LOW (review only)

**Action:** Review each `_process()` to ensure it's minimal. Most appear acceptable.

**Effort:** 15 minutes (review)  
**Impact:** Ensure no performance issues  
**Migration Pattern:** N/A (review only)

---

### 12. Extract Hardcoded Paths to Constants

**File:** `scripts/game_systems/house_interaction.gd:3`  
**Violation:** Scene path hardcoded (acceptable, but could be Resource)  
**ROI:** LOW (minor improvement)

**Current:**
```gdscript
const HOUSE_SCENE_PATH = "res://scenes/world/house_scene.tscn"
```

**Note:** This is acceptable as a constant. Could move to Resource if many scene paths exist.

**Effort:** 10 minutes (if many paths)  
**Impact:** Minor organization improvement  
**Migration Pattern:** N/A (optional)

---

## Implementation Priority

### Phase 1: Critical (Do First)
1. ✅ Fix ternary operator in tool_switcher.gd (#1)

### Phase 2: High ROI (Do Next)
2. ✅ Replace _process() polling in ui_manager.gd (#2)
3. ✅ Replace _process() polling in house_interaction.gd (#3)
4. ✅ Cache get_node() calls in tool_switcher.gd (#4)

### Phase 3: Medium ROI (Do When Time Permits)
5. Fix script ordering in farming_manager.gd (#5)
6. Extract magic numbers to Resource (#6)
7. Consolidate tool mapping (#7)
8. Replace get_node() with @onready in house_interaction.gd (#8)

### Phase 4: Low ROI (Nice to Have)
9. Add type hints to signals (#9)
10. Cache get_node() in player.gd (#10)
11. Review _process() in other files (#11)
12. Extract hardcoded paths (#12)

---

## Estimated Total Effort

- **Phase 1:** 2 minutes
- **Phase 2:** 20 minutes
- **Phase 3:** 50 minutes
- **Phase 4:** 30 minutes
- **Total:** ~102 minutes (~1.7 hours)

---

## Verification

After implementing fixes, run:
```powershell
pwsh -File scripts/verify_rules.ps1
```

Expected result: All violations resolved, only review items remain.

---

## Notes

- All fixes follow `.cursor/rules/godot.md` patterns
- No structural overhauls - only targeted refactors
- Backward compatible changes only
- Each fix is isolated and can be done independently

