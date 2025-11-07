# Rimfield Project Standard

## File/Directory Structure

### Organization Principles
- **Scene-Script Colocation**: Scripts live in `scripts/` organized by subsystem, not alongside scenes
- **Subsystem Grouping**: Scripts grouped by feature area (inventory, ui, game_systems, singletons)
- **Resource Separation**: Data resources (`.tres`) live in `resources/` directory
- **Asset Organization**: Assets organized by type in `assets/` (sprites, tiles, UI, audio, etc.)

### Naming Conventions
- Scripts: `snake_case.gd`
- Scenes: `snake_case.tscn`
- Resources: `snake_case.tres`
- Nodes: `PascalCase` for important nodes, `snake_case` for generic nodes
- Signals: `snake_case` (e.g., `tool_changed`, `scene_changed`)

## Script Structure & Style

### Code Ordering (as observed)
1. **`extends` declaration**
2. **Signals** (at top of class)
3. **Constants** (`const`)
4. **Exported variables** (`@export`)
5. **Regular variables** (`var`)
6. **`@onready` variables** (when needed)
7. **`_ready()`** - Initialization
8. **`_process()` / `_input()`** - Engine callbacks
9. **Public functions** - API methods
10. **Private functions** (prefixed with `_`)

### Style Rules
- **No ternary operators** - Always use explicit `if/else` blocks
- **Type hints** - Use type hints for exported vars and function parameters
- **Signal-first communication** - Prefer signals over direct calls for decoupling
- **Explicit null checks** - Use `get_node_or_null()` and check before use
- **Debug prints** - Use `print("DEBUG: ...")` or `print("ERROR: ...")` for debugging

### Example Structure
```gdscript
extends Node2D

signal tool_changed(slot_index: int, item_texture: Texture)

const MAX_SLOTS: int = 10

@export var tool_switcher_path: NodePath
var current_drag_data: Dictionary = {}

func _ready() -> void:
    # Initialization code

func _process(delta: float) -> void:
    # Update code

func public_method() -> void:
    # Public API

func _private_helper() -> void:
    # Internal logic
```

## Communication Patterns

### Signals (Primary Pattern)
- **SignalManager** - Central hub for tool-related signals (`tool_changed`)
- **Scene-level signals** - `UiManager.scene_changed`, `GameState.game_loaded`
- **Component signals** - UI components emit `drag_started`, `item_dropped`, `tool_selected`
- **Connection pattern** - Use `SignalManager.connect_tool_changed()` for tool signals
- **Direct connections** - Use `connect()` with `Callable()` for other signals

### When to Use Signals
- Cross-scene communication (HUD ↔ FarmingManager)
- UI component events (slot clicks, drag operations)
- State change notifications (scene changes, game loaded)
- Decoupling singletons from scene nodes

### When to Use Direct Calls
- Internal class methods
- Parent-child relationships within same scene
- Singleton utility methods (e.g., `InventoryManager.add_item()`)

### Anti-Patterns to Avoid
- Deep node paths (`/root/Farm/Hud/HUD/...`) - Use signals or node references instead
- Hardcoded scene names in singletons - Use signals or scene detection
- Direct singleton access for scene-specific nodes - Pass references or use signals

## Data/Config Approach

### Resources (.tres)
- **DroppableItem** - Extends `Resource`, stores item data (texture, max_stack, description, item_id)
- **Location**: `resources/droppable_items/*.tres`
- **Usage**: Data-driven item definitions, loaded via `preload()` or `load()`

### Data Storage
- **GameState** - Dictionary-based state (`farm_state: Dictionary`, `current_scene: String`)
- **InventoryManager** - Dictionary-based inventory (`inventory_slots: Dictionary[int, Texture]`)
- **Save System** - JSON-based save files in `user://` directory

### Configuration
- **Tool Mapping** - `SignalManager.TOOL_MAP` (Dictionary mapping textures to tool names)
- **Tile IDs** - Constants in `FarmingManager` (TILE_ID_GRASS, TILE_ID_DIRT, etc.)
- **Input Actions** - Defined in `project.godot` InputMap (no hardcoded keycodes)

## Testing & Development

### Debug Patterns
- **Debug flags** - `debug_disable_dust: bool` in UiManager/FarmScene
- **Debug prints** - Consistent `DEBUG:` and `ERROR:` prefixes
- **Validation functions** - `validate_paths_and_resources()` pattern (commented out but present)

### Development Notes
- **Temporary files** - `.tmp` files in scene directories (likely editor artifacts, can be cleaned)
- **Commented code** - Some debug/test code left commented (e.g., `populate_test_inventory_items()`)
- **Scene detection** - `UiManager._is_not_game_scene()` helper for conditional logic

## Scene Architecture

### Scene Structure
- **World scenes** - Contain game logic nodes (FarmingManager, TileMapLayer, spawn points)
- **UI scenes** - Overlay scenes instantiated by UiManager or world scenes
- **Component scenes** - Reusable components (droppable items, particles)

### Node Access Patterns
- **NodePath exports** - Use `@export var node_path: NodePath` for inspector-assigned paths
- **`get_node_or_null()`** - Always use null-safe node access
- **Scene tree queries** - `get_tree().current_scene` for scene detection
- **Parent references** - Store references when needed, but prefer signals

## Current Conventions Summary

1. **Signals over direct calls** for cross-system communication
2. **Resources for data** (DroppableItem pattern)
3. **Dictionary-based state** (GameState, InventoryManager)
4. **InputMap usage** (no hardcoded keycodes)
5. **Explicit if/else** (no ternary operators)
6. **Type hints** on exports and function parameters
7. **Debug print prefixes** (DEBUG:, ERROR:)
8. **Null-safe node access** (`get_node_or_null()`)
9. **Subsystem organization** in scripts directory
10. **Scene-script separation** (scripts in `scripts/`, scenes in `scenes/`)

