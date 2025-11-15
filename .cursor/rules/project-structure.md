# Rimfield Project Structure Standards

## Directory Organization

### Required Structure
```
Rimfield/
├── assets/              # All game assets (images, audio, etc.)
│   ├── animations/      # Animation files
│   ├── audio/           # Sound effects and music
│   ├── fonts/           # Font files
│   ├── particles/       # Particle textures
│   ├── sprites/         # Character and object sprites
│   ├── tiles/           # Tile textures
│   ├── tilesets/        # Tileset resources
│   └── ui/              # UI element textures
├── resources/           # Game data resources
│   └── data/            # Configuration resources (GameConfig, ToolConfig)
├── scenes/              # All scene files (.tscn)
│   ├── characters/      # Character scenes
│   ├── ui/              # UI scenes
│   └── world/           # World/level scenes
├── scripts/             # All GDScript files
│   ├── characters/      # Character scripts
│   ├── data/            # Data/Resource scripts
│   ├── game_systems/    # Core game system scripts
│   ├── inventory/       # Inventory system scripts
│   ├── scenes/          # Scene-specific scripts
│   ├── singletons/      # Autoload singleton scripts
│   ├── ui/              # UI scripts
│   └── util/            # Utility scripts
└── tests/               # Test files (future)
```

## Naming Conventions

### Files and Directories
- **Directories**: `snake_case` (lowercase with underscores)
- **Scripts**: `snake_case.gd`
- **Scenes**: `PascalCase.tscn` (matches node name)
- **Resources**: `PascalCase.tres` (matches class name)

### Asset Files
- **Sprites**: Descriptive names like `player_idle.png`, `grass_tile.png`
- **Audio**: Descriptive names like `footstep_01.ogg`, `menu_select.wav`
- **Fonts**: Match font family name

## Scene Organization

### Scene Hierarchy
- Root node should match scene purpose (e.g., `Farm` for farm scene)
- Group related nodes under parent nodes
- Use clear, descriptive node names
- Avoid deep nesting (max 4-5 levels)

### Node Naming
- Use descriptive names: `Player`, `InventoryPanel`, `HealthBar`
- Avoid generic names: `Node`, `Sprite`, `Control`
- Use prefixes for organization: `UI_`, `FX_`, `BG_` when helpful

## Script Organization

### Script Location Rules
- Scripts should be in `scripts/` directory
- Organize by system/feature, not by scene
- Shared utilities go in `scripts/util/`
- System-specific scripts go in `scripts/game_systems/`

### Script-to-Scene Relationship
- One script per scene (attached to root node)
- Scene-specific logic in scene script
- Reusable logic in separate scripts

## Resource Organization

### Resource Files
- All configuration data in `resources/data/`
- Use Resource classes for structured data
- Name resources to match their class: `GameConfig.tres` for `GameConfig` class

### Resource Types
- **GameConfig**: Game-wide settings (speeds, distances, counts)
- **ToolConfig**: Tool-specific configuration
- **ItemData**: Item definitions and properties

## Asset Organization

### Texture Organization
- Group by purpose: `ui/`, `sprites/`, `tiles/`
- Use subdirectories for large categories
- Keep related assets together

### Import Settings
- Configure import settings in Godot editor
- Use appropriate compression for each asset type
- Document any special import requirements

## Documentation

### Required Documentation Files
- `README.md`: Project overview and setup
- `README_DEV.md`: Development guidelines
- `.cursor/rules/`: Coding standards (this folder)

### Code Documentation
- Document public APIs
- Explain complex algorithms
- Add TODO comments for future work

## Version Control

### Gitignore
- Ignore `.godot/` directory
- Ignore `.import/` files (or track selectively)
- Ignore temporary files (`*.tmp`, `*.bak`)

### Commit Messages
- Use clear, descriptive commit messages
- Reference issue numbers when applicable
- Group related changes in single commits

## Build and Export

### Export Presets
- Store export presets in project
- Document export requirements
- Test exports regularly

### Platform-Specific
- Keep platform-specific code minimal
- Use feature flags for platform differences
- Document platform requirements

