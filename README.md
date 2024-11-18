
# FarmSim

FarmSim is a 2D farming simulation game inspired by *Stardew Valley*, built using Godot 4.3. The goal is to create a fully interactive farming and exploration experience with mechanics like planting crops, interacting with NPCs, mining, and resource management.

---

## **Project Structure**

The project is organized as follows:

```
/project
├── assets/
│   ├── audio/             # Sound effects, music
│   ├── fonts/             # Fonts for UI
│   ├── sprites/           # Pixel art for characters, tiles, and items
│   ├── tilesets/          # Tileset images and configurations
│   ├── ui/                # UI graphics (buttons, icons, etc.)
│   └── animations/        # Animation spritesheets
├── scenes/
│   ├── world/             # Game world scenes (farm, town, house, etc.)
│   ├── systems/           # Game system managers (e.g., day/night, NPC management)
│   ├── ui/                # UI scenes (inventory, HUD, menus)
│   └── test/              # Test scenes for debugging
├── scripts/
│   ├── characters/        # Scripts for player and NPCs
│   ├── game_systems/      # Core game mechanics and systems
│   ├── ui/                # Scripts for UI logic
│   └── utils/             # Utility scripts for shared functionality
├── singletons/            # Autoload singleton scripts for global management
├── tests/                 # Unit and functional test scripts
└── README.md              # Project overview and instructions
```

---

## **Key Features**

### Initial Goals:
- **Core Farming Mechanics:** 
  - Hoeing, planting, and harvesting crops.
- **Scene Transitions:**
  - Seamlessly move between the farm, house, and town.
- **Day/Night Cycle:**
  - Time-based events and visual transitions.
- **Inventory Management:**
  - Collect and store items like crops and tools.

### Future Expansions:
- NPC interactions and quests.
- Mining and crafting mechanics.
- Weather systems affecting farming.
- Player and farm upgrades.

---

## **Current Progress**

### Completed:
- Initial folder structure and project setup.
- Placeholder scenes for `farm` and `house`.
- Player singleton with position tracking.

### In Progress:
- Scene transition system using `GameState`.
- Basic player movement and interaction zones.

---

## **Setup Instructions**

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/yourusername/FarmSim.git
   cd FarmSim
   ```

2. **Open in Godot:**
   - Open Godot and select the `FarmSim` project directory.

3. **Run the Game:**
   - Test the `farm.tscn` scene as the starting point.

---

## **Contributing**

### Guidelines:
- Follow the existing folder structure for adding new assets, scenes, or scripts.
- Ensure scripts are commented and modular to maintain clarity and scalability.
- Submit pull requests for review before merging.

### TODOs:
- Add documentation for core systems like inventory, scene transitions, and NPCs.

---

## **License**

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

## **Acknowledgments**
Inspired by *Stardew Valley* and built with the amazing Godot Engine.
