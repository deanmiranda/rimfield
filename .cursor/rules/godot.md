# Godot Coding Standards for Rimfield

## Script Organization Order

All GDScript files MUST follow this exact order (enforced by linter):

1. **File Header Comment** (optional but recommended)
   ```gdscript
   # script_name.gd
   # Brief description of what this script does
   ```

2. **Extends Declaration**
   ```gdscript
   extends Node2D
   ```

3. **Class Name** (if applicable)
   ```gdscript
   class_name MyClass
   ```

4. **Signals** (all signals first)
   ```gdscript
   signal item_picked_up(item: Resource)
   signal health_changed(new_health: int)
   ```

5. **Constants** (all constants, uppercase with underscores)
   ```gdscript
   const MAX_HEALTH = 100
   const TILE_SIZE = Vector2(16, 16)
   ```

6. **@export Variables** (all exports grouped together)
   ```gdscript
   @export var speed: float = 200.0
   @export var health: int = 100
   ```

7. **@onready Variables** (all onready variables)
   ```gdscript
   @onready var sprite = $Sprite2D
   @onready var animation_player = $AnimationPlayer
   ```

8. **Regular Variables** (grouped by purpose)
   ```gdscript
   var current_state: String = "idle"
   var direction: Vector2 = Vector2.ZERO
   ```

9. **Functions** (in logical order: lifecycle → public → private)
   - `_ready()` first
   - `_process()` / `_physics_process()` next
   - `_input()` / `_unhandled_input()` next
   - Public functions
   - Private functions (prefixed with `_`)

## Naming Conventions

### Variables and Functions
- **snake_case** for all variables and functions
- **PascalCase** for class names and constants (if using class_name)
- **UPPER_SNAKE_CASE** for constants
- Prefix private functions with `_`
- Use descriptive names: `player_health` not `ph`, `calculate_damage()` not `calc()`

### Signals
- Use past tense for events: `item_collected`, `player_died`, `level_completed`
- Use present tense for state changes: `health_changed`, `inventory_updated`

### Nodes and Scenes
- PascalCase for scene file names: `Player.tscn`, `MainMenu.tscn`
- Descriptive names for node instances in scenes

## Resource Management

### Use Resource Files for Configuration
- **NEVER** use magic numbers in code
- Create `Resource` classes for configuration data (see `GameConfig`, `ToolConfig`)
- Store all game constants in resource files: `res://resources/data/`

Example:
```gdscript
# BAD
var speed: float = 200.0  # Magic number

# GOOD
var game_config: Resource = load("res://resources/data/game_config.tres")
var speed: float = game_config.player_speed
```

### Preloading vs Loading
- Use `preload()` for resources always needed at script load time
- Use `load()` for resources that may not always be needed
- Prefer `preload()` for performance-critical resources

## Node References

### Avoid Hardcoded Paths
- **NEVER** use `/root/...` paths
- Use dependency injection via `set_*()` methods
- Use `@export var` for NodePath references when needed
- Cache node references in `@onready` variables

Example:
```gdscript
# BAD
var player = get_node("/root/Farm/Player")

# GOOD
@onready var player = $Player
# OR
var player: Node = null
func set_player(player_node: Node) -> void:
    player = player_node
```

### TileMapLayer (Godot 4.x)
- **IMPORTANT**: This project uses `TileMapLayer` nodes directly (not `TileMap`)
- `TileMapLayer` can be a child of any `Node2D` (not just `TileMap`)
- **NEVER** assume `TileMapLayer.get_parent()` is a `TileMap`
- Use `TileMapLayer`'s own coordinate methods directly:
  - `tilemap_layer.to_local(world_pos)` - Convert world to layer local
  - `tilemap_layer.to_global(local_pos)` - Convert layer local to world
  - `tilemap_layer.local_to_map(local_pos)` - Convert local pos to cell coords
  - `tilemap_layer.map_to_local(cell_pos)` - Convert cell coords to local pos

Example:
```gdscript
# BAD - Assumes parent is TileMap
var tilemap = tilemap_layer.get_parent()
if tilemap is TileMap:
    var local_pos = tilemap.to_local(world_pos)

# GOOD - Use TileMapLayer directly
var local_pos = tilemap_layer.to_local(world_pos)
var cell = tilemap_layer.local_to_map(local_pos)
```

## Variable Scope and Naming

### Avoid Variable Name Conflicts
- **NEVER** declare a variable with the same name twice in the same scope
- Check for existing variable declarations before adding new ones
- Use descriptive, unique variable names to avoid conflicts
- If reusing a variable from a parent scope, add a comment explaining why

```gdscript
# BAD - Variable declared twice in same function
func some_function():
    var parent = get_parent()
    # ... code ...
    var parent = get_node("../OtherParent")  # ERROR: Variable already declared

# GOOD - Reuse existing variable or use different name
func some_function():
    var parent = get_parent()
    # ... code ...
    # Reuse parent variable from above
    if parent:
        var other_parent = parent.get_node_or_null("../OtherParent")
```

## Error Handling

### Always Check for Null
- Check if nodes/resources exist before using them
- Use `get_node_or_null()` instead of `get_node()` when node might not exist
- Provide meaningful error messages

```gdscript
var node = get_node_or_null("SomeNode")
if not node:
    print("Error: SomeNode not found!")
    return
```

### Use Early Returns
- Check conditions early and return to avoid deep nesting
- Makes code more readable

## Type Hints

### Always Use Type Hints
- Specify types for all variables and function parameters/returns
- Use `-> void` for functions that return nothing
- Use `-> Type` for functions that return a value

```gdscript
# BAD
func process_item(item):
    return item.value * 2

# GOOD
func process_item(item: Resource) -> int:
    return item.value * 2
```

## Code Comments

### When to Comment
- Explain **why**, not **what** (code should be self-explanatory)
- Document complex algorithms or business logic
- Add TODO comments for future improvements
- Remove commented-out code before committing

### Comment Style
```gdscript
# Single-line comments for brief explanations
# Multi-line comments for detailed explanations
# that span multiple lines
```

## Performance Best Practices

### Avoid Per-Frame Operations
- Don't do expensive operations in `_process()` or `_physics_process()`
- Use timers for periodic checks instead of per-frame polling
- Cache frequently accessed values

```gdscript
# BAD
func _process(_delta: float) -> void:
    var player = get_tree().get_first_node_in_group("player")
    # ... do something

# GOOD
@onready var player = get_tree().get_first_node_in_group("player")
func _process(_delta: float) -> void:
    # ... do something
```

### Signal-Based Communication
- Use signals instead of polling
- Connect signals in `_ready()` or via editor connections
- Disconnect signals in `_exit_tree()` or cleanup functions

## Singleton Usage

### Autoload Singletons
- Use singletons for global state management
- Keep singletons focused on a single responsibility
- Document singleton dependencies

### Accessing Singletons
```gdscript
# Direct access (singletons are autoloaded)
if GameState:
    GameState.save_game()

# Check for null if singleton might not exist
if InventoryManager:
    InventoryManager.add_item(item)
```

## Input Handling

### Input Actions
- Use named input actions from project settings
- Never hardcode key codes
- Handle input in `_input()` or `_unhandled_input()` based on needs

```gdscript
# BAD
if event.keycode == KEY_SPACE:
    jump()

# GOOD
if event.is_action_pressed("ui_jump"):
    jump()
```

### Item Pickup Controls
- **Right-click** is used for picking up items (vegetables, dropped items) when the player is nearby
- **E key** is used for door interactions (house entrance)
- **E key** opens inventory (pause menu) only if no interactable objects are nearby
- Right-click on toolkit slots is for drag-and-drop (takes priority over world pickup)
- The hover icon (plus icon) shows when items are nearby and becomes "enabled" when close enough
- Future: Right-click pickup will trigger a character animation (pulling item out of ground)

## Scene Management

### Scene Transitions
- Use SceneManager singleton for scene changes
- Always unpause before changing scenes
- Clean up resources before scene changes

```gdscript
# Good pattern
get_tree().paused = false
SceneManager.change_scene("res://scenes/ui/main_menu.tscn")
```

## Debugging

### Debug Output
- Use `print()` for temporary debugging
- Remove or comment out debug prints before committing
- Use consistent debug prefixes: `DEBUG:`, `ERROR:`, `WARNING:`

```gdscript
print("DEBUG: Player position: ", global_position)
print("ERROR: Failed to load resource: ", resource_path)
```

## File Organization

### Script Location
- Scripts should be in `scripts/` directory
- Organize by feature/system: `scripts/game_systems/`, `scripts/ui/`, etc.
- Keep related scripts together

### File Naming
- Use `snake_case.gd` for script files
- Match script name to primary class/functionality
- One class per file (unless using inner classes)

## Code Quality and Linting

### Always Run Linters Before Completing Work
- **MANDATORY**: Run `read_lints` tool on all modified files before marking work as complete
- Fix all linter errors and warnings before submitting changes
- Check for:
  - Variable name conflicts
  - Unused variables/parameters
  - Type mismatches
  - Script ordering violations
  - Missing null checks
  - Invalid constant/enum usage
  - Member access errors

### Linter Usage
```gdscript
# After making changes, always run:
read_lints(paths=['scripts/path/to/modified_file.gd'])
# Fix any errors before completing the task
```

### Godot 4.x Constants and Enums
- **NEVER** use non-existent constants or enum values
- If a constant doesn't exist, use the integer value directly with a comment
- Always verify constant names exist in Godot 4.x documentation
- Common issue: `Control.LAYOUT_MODE_ANCHORS` doesn't exist - use integer `1` instead

```gdscript
# BAD - Non-existent constant
border_rect.layout_mode = Control.LAYOUT_MODE_ANCHORS  # ERROR: Constant doesn't exist

# GOOD - Use integer value with comment
border_rect.layout_mode = 1  # LAYOUT_MODE_ANCHORS (Godot 4.x uses integer 1)
```

## Testing and Validation

### Validation Functions
- Validate inputs at function boundaries
- Return early on invalid inputs
- Provide clear error messages

```gdscript
func add_item(item: Resource) -> bool:
    if not item:
        print("ERROR: Cannot add null item")
        return false
    # ... rest of function
```

## Code Formatting

### Indentation
- Use **tabs** for indentation (Godot default)
- Consistent 1 tab = 4 spaces visually

### Line Length
- Keep lines under 100 characters when possible
- Break long lines at logical points
- Align continuation lines

### Spacing
- One blank line between function definitions
- Blank lines to separate logical sections within functions
- No trailing whitespace

## Common Patterns

### State Management
- Use enums for state machines
- Clear state transitions
- Document state flow

### Resource Loading Pattern
```gdscript
var config: Resource = null

func _ready() -> void:
    config = load("res://resources/data/config.tres")
    if not config:
        print("ERROR: Failed to load config")
        return
```

### Signal Connection Pattern
```gdscript
func _ready() -> void:
    if not some_node.is_connected("signal_name", Callable(self, "_handler")):
        some_node.connect("signal_name", Callable(self, "_handler"))
```
