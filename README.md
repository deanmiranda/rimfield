# Rimfield - 2D Farming Simulation Game

**Rimfield** is a 2D farming simulation game inspired by *Stardew Valley*, built using **Godot 4.3/4.4**. The goal is to create a fully interactive farming and exploration experience with mechanics like planting crops, interacting with NPCs, mining, and resource management.

---

## Project Overview

### Core Concept
A farming simulation game where players can:
- Manage a farm with planting, harvesting, and crop management
- Explore different areas (farm, house, town)
- Manage inventory and tools
- Interact with NPCs and complete quests
- Experience day/night cycles and weather systems

### Current Status
The project is in active development with core systems implemented:
- ✅ Player movement and interaction
- ✅ Scene transition system
- ✅ Inventory system (30 slots: 3 rows × 10 columns)
- ✅ Toolkit system (10 slots in HUD)
- ✅ Farming mechanics (hoeing, planting, harvesting)
- ✅ Drag and drop system (in progress - left/right click behaviors being fixed)
- ✅ UI systems (HUD, pause menu, inventory menu)

---

## Project Structure

```
Rimfield/
├── assets/                    # All raw asset files
│   ├── animations/            # Character and element animations
│   ├── audio/                 # Music and sound effects
│   ├── fonts/                 # Font files for UI
│   ├── particles/             # Particle textures and configs
│   ├── sprites/               # Individual sprite assets
│   ├── tiles/                 # Tile textures for world
│   ├── tilesets/              # Pre-configured tilesets
│   ├── tilesheets/            # Full tilesheets for reference
│   └── ui/                    # UI-specific assets (icons, buttons)
├── resources/                 # Predefined reusable resources
│   └── data/                  # Game configuration resources
│       ├── game_config.tres   # Game-wide configuration
│       └── tool_config.tres    # Tool configuration
├── scenes/                    # All game scenes
│   ├── characters/            # Player and NPC scenes
│   ├── droppable/             # Droppable item scenes
│   ├── effects/               # Particle effects
│   ├── systems/               # System scenes (inventory, save/load)
│   ├── ui/                    # UI scenes (menus, HUDs)
│   └── world/                 # World scenes (farm, house)
├── scripts/                   # Game logic, organized by functionality
│   ├── characters/             # Player and NPC scripts
│   ├── data/                   # Data management scripts
│   ├── droppable/              # Droppable item behavior
│   ├── game_systems/           # Core systems (farming, scene management)
│   ├── inventory/              # Inventory system scripts
│   ├── scenes/                 # Scene-specific scripts
│   ├── singletons/             # Global scripts (autoloads)
│   ├── ui/                     # UI behavior and interactions
│   └── util/                   # Utility scripts
├── tests/                      # Test files
├── .cursor/                    # Cursor AI configuration
│   └── rules/                  # Project coding standards
├── .github/                    # GitHub workflows and templates
│   └── workflows/              # CI/CD automation
└── scripts/                    # Development scripts
    └── verify_rules.ps1        # Code quality verification
```

---

## Key Features

### Implemented Features
- **Core Farming Mechanics:**
  - Hoeing, planting, and harvesting crops
  - Tile state management (grass, dirt, tilled, planted, grown)
  - Tool interaction system
  
- **Scene Management:**
  - Seamless transitions between farm, house, and town
  - Scene state persistence
  - Player position tracking across scenes

- **Inventory System:**
  - 30-slot inventory (3 rows × 10 columns)
  - Item storage and retrieval
  - Drag and drop functionality (in progress)

- **Toolkit System:**
  - 10-slot toolkit in HUD
  - Tool switching via keyboard (1-0 keys) or mouse
  - Active tool highlighting
  - Drag and drop between toolkit and inventory (in progress)

- **UI Systems:**
  - HUD with toolkit display
  - Pause menu with inventory tab
  - Main menu and load menu
  - Scene transition UI

### Planned Features
- Day/Night cycle with time-based events
- NPC interactions and quests
- Mining and crafting mechanics
- Weather systems affecting farming
- Player and farm upgrades
- Save/Load system enhancements
- Equipment system

---

## Development Environment

### Prerequisites
- **Godot 4.4** (project engine version)
- **Windows PowerShell 5+** or **PowerShell Core (pwsh)**
- **Git** 2.30+
- Optional: **Ripgrep** (`rg`) for faster code scans

### Setup Instructions

1. **Clone the Repository:**
   ```bash
   git clone <repository-url>
   cd Rimfield
   ```

2. **Open in Godot:**
   - Launch Godot 4.4
   - Select "Import" and choose the `Rimfield` project directory
   - Or open `project.godot` directly

3. **Run the Game:**
   - Test scenes: `scenes/world/farm_scene.tscn` (main starting point)
   - Or use the main menu: `scenes/ui/main_menu.tscn`

---

## Architecture & Coding Standards

### Core Principles
Rimfield follows strict coding standards defined in `.cursor/rules/godot.md`:

1. **No Absolute Paths:** Never use `/root/...` lookups. Use dependency injection, `@onready` references, or relative paths (`$Node`).

2. **No Ternary Operators:** Use explicit `if/else` blocks for clarity and rule compliance.

3. **Signal-Driven Architecture:** Use signals and autoloads as the main communication channels between systems.

4. **Typed Code:** All variables and functions should have explicit type hints (`-> void`, `-> bool`, etc.).

5. **Performance:** Avoid heavy logic in `_process()`. Use signals, timers, or event-driven updates.

6. **Configuration via Resources:** Use `.tres` resource files (GameConfig, ToolConfig) instead of magic numbers.

### Code Organization
Scripts follow this standard order:
1. Signals
2. Constants
3. Exports (`@export`)
4. Variables
5. Functions

### Local Development Tools

**Code Quality Verification:**
```powershell
# Run rule checks manually
pwsh -File scripts/verify_rules.ps1

# Or with Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts/verify_rules.ps1
```

**Pre-Commit Hook:**
- Automatically runs `verify_rules.ps1` before each commit
- Blocks commits with rule violations
- Can be skipped with `git commit --no-verify` (use sparingly)

**CI/CD:**
- GitHub Actions runs the same verification on all pull requests
- PRs fail if violations are found
- Ensures consistent code quality across the team

---

## Key Systems

### Inventory System
- **Manager:** `scripts/singletons/inventory_manager.gd` (autoload singleton)
- **Slots:** `scripts/ui/inventory_menu_slot.gd` (inventory menu slots)
- **Features:**
  - 30-slot grid (3×10)
  - Drag and drop support
  - Locked slots for future upgrades
  - Item swapping between slots

### Toolkit System
- **Manager:** `scripts/ui/tool_switcher.gd`
- **Slots:** `scripts/ui/hud_slot.gd` (HUD toolkit slots)
- **Features:**
  - 10-slot toolkit in HUD
  - Keyboard shortcuts (1-0)
  - Mouse selection
  - Active tool highlighting
  - Drag and drop support

### Farming System
- **Manager:** `scripts/game_systems/farming_manager.gd`
- **Features:**
  - Tile state management
  - Tool interaction (hoe, plant, harvest)
  - Crop growth system
  - Interaction range validation

### Scene Management
- **Manager:** `scripts/singletons/scene_manager.gd` (autoload)
- **Features:**
  - Scene transitions
  - Player position persistence
  - Scene state management

### UI Management
- **Manager:** `scripts/singletons/ui_manager.gd` (autoload)
- **Features:**
  - Input processing control
  - Scene change detection
  - Menu management

---

## Contributing

### Guidelines
- Follow the existing folder structure for adding new assets, scenes, or scripts
- Ensure scripts are commented and modular
- Follow `.cursor/rules/godot.md` coding standards
- Run `scripts/verify_rules.ps1` before committing
- Submit pull requests for review before merging

### Pull Request Checklist
- [ ] No `/root/...` paths remain
- [ ] No ternary operators
- [ ] Input handled via InputMap
- [ ] Signals typed and connected once
- [ ] `_process()` free of polling logic
- [ ] `scripts/verify_rules.ps1` → **PASS**
- [ ] Code follows script ordering standard
- [ ] Type hints on all functions and variables

### Code Review Process
1. Create feature branch from `develop`
2. Implement changes following coding standards
3. Run verification script locally
4. Submit PR with description
5. CI will verify code quality
6. Address review feedback
7. Merge after approval

---

## Known Issues & Technical Debt

### Current Focus
- **Inventory Drag and Drop:** Fixing left and right click behaviors
  - Left click: Drag and drop between inventory and toolkit
  - Right click: Context menu or alternative behavior (to be implemented)

### Technical Debt
See `NEXT_STEPS.md` for detailed technical debt items, including:
- Code organization improvements
- Magic number elimination
- Node path reference cleanup
- Type hint completion
- Error handling improvements
- Performance optimizations

---

## Resources & Configuration

### Game Configuration
- **File:** `resources/data/game_config.tres`
- Contains game-wide settings (slot counts, speeds, distances, etc.)

### Tool Configuration
- **File:** `resources/data/tool_config.tres`
- Contains tool mappings and properties

### Input Actions
All input is handled via Godot's InputMap system. Common actions:
- `ui_interact` - Interact with objects
- `ui_pause` - Open/close pause menu
- `tool_1` through `tool_0` - Select toolkit slots (1-0 keys)

---

## Testing

### Manual Testing
- Test scenes in `scenes/test/`
- Run game from main menu
- Test scene transitions
- Test inventory and toolkit interactions
- Test farming mechanics

### Automated Testing
- Test framework setup planned
- Unit tests for utility functions
- Integration tests for system interactions

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

## Acknowledgments

- Inspired by *Stardew Valley*
- Built with the amazing **Godot Engine**
- Uses various open-source assets and tools

---

## Getting Help

- Review `.cursor/rules/godot.md` for coding standards
- Check `NEXT_STEPS.md` for current development priorities
- Review existing code for patterns and examples
- Run `scripts/verify_rules.ps1` to check code quality

---

**Last Updated:** Current development focus is on inventory drag and drop functionality (left/right click behaviors).
