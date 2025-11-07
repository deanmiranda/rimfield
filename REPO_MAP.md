# Rimfield Repository Map

## Top-Level Directories

- **`assets/`** - Art assets (animations, audio, fonts, particles, sprites, tiles, tilesets, UI)
- **`scenes/`** - Scene files (.tscn) organized by subsystem:
  - `characters/player/` - Player scene
  - `droppable/` - Droppable item scenes
  - `effects/particles/` - Particle effect scenes
  - `ui/` - UI scenes (HUD, inventory, menus)
  - `world/` - World scenes (farm_scene, house_scene)
- **`scripts/`** - GDScript files organized by subsystem:
  - `singletons/` - Autoload scripts
  - `characters/` - Character scripts
  - `game_systems/` - Core game systems (farming, interactions)
  - `inventory/` - Inventory system scripts
  - `ui/` - UI component scripts
  - `scenes/` - Scene-specific scripts
  - `droppable/` - Droppable item scripts
  - `utils/` - Utility scripts (currently empty)
- **`resources/`** - Resource files (.tres) for data-driven content (droppable items)
- **`tests/`** - Test directory (minimal usage)
- **`cursor/rules/`** - Cursor IDE rules and conventions

## Autoloads (Singletons)

1. **DroppableFactory** - Creates and spawns droppable items
2. **GameState** - Manages persistent game state (farm tiles, current scene, save/load)
3. **SceneManager** - Handles scene transitions and spawn positions
4. **Player** - Player state (health, inventory array, spawn position)
5. **UiManager** - Global UI management (inventory instantiation, pause menu, scene change detection)
6. **InventoryManager** - Inventory data storage and slot management
7. **HUD** - HUD management, tool switching, drag-and-drop
8. **SignalManager** - Central signal routing hub, tool texture-to-name mapping

## Scene Graph Highlights

### Key Scenes
- **`scenes/world/farm_scene.tscn`** - Main farm scene (script: `scripts/scenes/farm_scene.gd`)
  - Contains: FarmingManager, PlayerSpawnPoint, TileMapLayer, HUD instance
- **`scenes/ui/hud.tscn`** - HUD overlay (script: `scripts/singletons/hud.gd`)
  - Structure: `/HUD/MarginContainer/HBoxContainer/TextureButton_*` (tool slots)
- **`scenes/ui/inventory_scene.tscn`** - Inventory panel (script: `scripts/inventory/inventory_scene.gd`)
  - Structure: `CenterContainer/GridContainer` with TextureButton slots
- **`scenes/ui/main_menu.tscn`** - Main menu (script: `scripts/scenes/main_menu.gd`)
- **`scenes/ui/pause_menu.tscn`** - Pause menu (script: `scripts/ui/pause_menu.gd`)

### Primary Scripts
- **`scripts/game_systems/farming_manager.gd`** - Core farming logic (tile interactions, tool handling)
- **`scripts/inventory/inventory_slot.gd`** - Inventory slot behavior (drag-and-drop, stacking)
- **`scripts/ui/hud_slot.gd`** - HUD tool slot behavior (tool selection, drag-and-drop)
- **`scripts/characters/player.gd`** - Player movement and interaction

## Input Handling

- **InputMap** - All input actions defined in `project.godot` (ui_interact, ui_tool_*, ui_hud_*, ui_inventory, ui_cancel)
- **Global Input** - `UiManager._input()` handles global actions (inventory toggle, pause menu)
- **Scene Input** - Player handles movement via InputMap actions
- **UI Input** - Individual UI components handle their own `_gui_input()` events

## State Storage

- **GameState** - Persistent state (farm tile states, current scene, save file path)
- **InventoryManager** - Inventory slot data (`inventory_slots: Dictionary`)
- **Player** - Player-specific state (health, inventory array, spawn position)
- **HUD** - Current drag data (`current_drag_data: Dictionary`)

## UI Update Triggers

- **Signals** - `tool_changed`, `scene_changed`, `game_loaded`, `drag_started`, `item_dropped`
- **Direct Calls** - `InventoryManager.sync_inventory_ui()`, `HUD._highlight_active_tool()`
- **Scene Change** - `UiManager._process()` monitors scene changes and triggers updates
- **Game Load** - `GameState.load_game()` emits `game_loaded` signal, scenes react accordingly

