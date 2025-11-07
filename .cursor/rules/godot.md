# Godot Repository Rules (Godot 4.4)

## Core Philosophy
- Build modular, event-driven systems.
- Avoid global coupling and hidden dependencies.
- Favor clarity and maintainability over cleverness.
- No ternary operators; always use explicit `if/else`.

---

## File & Directory Structure
- `addons/` — optional editor extensions.
- `autoload/` — singletons (SignalManager, GameState, EventBus).
- `data/` — .tres/.res Resource files and configuration.
- `scenes/` — visual/gameplay scenes collocated with scripts.
- `scripts/` — non-visual logic shared between systems.
- `ui/` — UI components and scenes.
- `assets/` — art, audio, and static assets.

---

## Scene & Script Conventions
- Every `.tscn` file lives with its `.gd` script in the same folder.
- Use `@onready var` for cached node references.
- Scene tree access:
  - Prefer relative node paths or `%NodeName`.
  - Never use absolute `/root/...` lookups.
- Prefer signals for communication across scenes.
- Keep scenes small; one core responsibility per scene.

---

## Scripting Standards
**Script order**
1. Signals  
2. Constants  
3. Exported vars  
4. Regular vars  
5. `_ready()`  
6. `_process()`  
7. Public functions  
8. Private functions (`_helper()`)

**Typing**
- All exports and public funcs use type hints.
- Use `:=` only where type is obvious.
- Always prefer named signals with argument types.

**Control Flow**
- No ternary operators.
- Use explicit `if/else` and early returns for clarity.

**Performance**
- No heavy logic inside `_process()`; use timers or signals instead.
- Cache nodes; avoid repeated `get_node()` calls in loops.
- Use Resources for static data; don’t hardcode constants.

---

## Communication Patterns
- **Signals:** Primary mechanism for cross-scene updates.
- **EventBus (autoload):** Handles global game events only.
- **Groups:** For batch operations (`call_group("enemies", "die")`).
- **Resources:** Data-driven configs (UI settings, item definitions).

---

## Data Management
- Store configuration and tunables in `.tres` Resources.
- Avoid "magic numbers" in scripts.
- Example:
  ```gdscript
  @onready var ui_config: UIConfig = load("res://data/ui_config.tres")
  ```

---

## Migration Pattern: Replacing Absolute Paths

**NEVER use absolute `/root/...` paths.** Use one of these patterns based on context:

### Pattern 1: Same Scene (Use `@onready` with `%UniqueName`)

**When:** Node is in the same scene tree as the script.

**From (bad):**
```gdscript
var label := get_node("/root/Farm/Hud/HUD/MarginContainer/HBoxContainer/HealthLabel")
label.text = str(player.health)
```

**To (good):**
```gdscript
# In scene: Add "Unique Name" to HealthLabel node (right-click → "Access as Unique Name")
@onready var health_label: Label = %HealthLabel

func _on_player_health_changed(new_health: int) -> void:
    health_label.text = str(new_health)
```

**Steps:**
1. In scene editor, right-click target node → "Access as Unique Name"
2. Replace `get_node("/root/...")` with `@onready var name: Type = %UniqueName`
3. Move logic to signal handlers or `_ready()` if needed

---

### Pattern 2: Cross-Scene via Autoload Signal Bus

**When:** Communication between unrelated scenes or singletons.

**From (bad):**
```gdscript
# In some script
var hud = get_node("/root/Farm/Hud")
hud.update_health(player.health)
```

**To (good):**
```gdscript
# autoload/SignalManager.gd (or existing autoload)
signal player_health_changed(new_health: int)

# Emitting side
SignalManager.player_health_changed.emit(player.health)

# Receiving side (HUD script)
func _ready() -> void:
    SignalManager.player_health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(new_health: int) -> void:
    health_label.text = str(new_health)
```

**Steps:**
1. Add signal to appropriate autoload (SignalManager, EventBus, etc.)
2. Replace direct calls with `SignalManager.signal_name.emit(args)`
3. Connect signal in receiver's `_ready()`
4. Move update logic to signal handler

---

### Pattern 3: Cross-Scene via Injection

**When:** Parent scene instantiates child and needs to pass references.

**From (bad):**
```gdscript
# In autoload singleton
var player = get_node("/root/Farm/Player")
```

**To (good):**
```gdscript
# Parent scene script (farm_scene.gd)
var player_instance = player_scene.instantiate()
add_child(player_instance)
HUD.set_player(player_instance)  # Inject reference

# HUD.gd (autoload or scene script)
var _player: Node = null

func set_player(p: Node) -> void:
    _player = p
    # Optional: connect signals here
    if _player.has_signal("health_changed"):
        _player.health_changed.connect(_on_player_health_changed)
```

**Steps:**
1. Create injection method: `func set_reference(ref: Type) -> void`
2. Call injection method from parent after `instantiate()` and `add_child()`
3. Cache reference in class variable
4. Use cached reference instead of absolute path

---

### Pattern 4: Relative Paths (Same Scene Tree)

**When:** Node is in same scene but not easily accessible via unique name.

**From (bad):**
```gdscript
var container = get_node("/root/Farm/Hud/HUD/MarginContainer")
```

**To (good):**
```gdscript
# If script is on Hud node
@onready var container: MarginContainer = $HUD/MarginContainer

# Or if script is elsewhere, use relative path from known parent
var hud = get_parent().get_node("Hud")
var container = hud.get_node("HUD/MarginContainer")
```

**Steps:**
1. Determine relative path from script's node
2. Use `$` syntax for direct children, or `get_node()` for relative paths
3. Cache with `@onready var` if accessed multiple times

---

## Migration Decision Tree

```
Is the target node in the same scene?
├─ YES → Use Pattern 1 (@onready var = %UniqueName)
└─ NO → Is it a cross-scene communication?
    ├─ YES → Use Pattern 2 (Signal bus via autoload)
    └─ NO → Is parent scene instantiating child?
        ├─ YES → Use Pattern 3 (Injection from parent)
        └─ NO → Use Pattern 4 (Relative path from known parent)
```

---

## Common Pitfalls to Avoid

1. **Don't mix patterns:** Choose one pattern per use case, don't combine absolute paths with signals.
2. **Don't use `_process()` for polling:** If you're checking node existence in `_process()`, use signals instead.
3. **Don't forget null checks:** Always check injected references before use: `if _player: _player.do_something()`
4. **Don't cache in `_ready()` if injection happens later:** Use injection method to set cache, not `_ready()`.
5. **Don't use absolute paths as fallback:** If injection fails, fix the injection, don't add absolute path fallback.

---

## Migration Checklist

When replacing absolute paths:
- [ ] Identify which pattern applies (same scene, cross-scene signal, or injection)
- [ ] Remove all `get_node("/root/...")` calls
- [ ] Add `@onready var` or injection method as appropriate
- [ ] Update scene file if using `%UniqueName` (add unique name to node)
- [ ] Move update logic to signal handlers if using signal bus
- [ ] Add null checks for injected references
- [ ] Test that references are set before use
- [ ] Verify no `/root/` paths remain (grep for `/root/`)
