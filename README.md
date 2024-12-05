
# FarmSim

FarmSim is a 2D farming simulation game inspired by *Stardew Valley*, built using Godot 4.3. The goal is to create a fully interactive farming and exploration experience with mechanics like planting crops, interacting with NPCs, mining, and resource management.

---

## **Project Structure**

The project is organized as follows:

```
.
+---assets                     # Contains all raw asset files used in the game
|   +---animations             # Animation files for characters and other elements
|   +---audio                  # Audio files (music, sound effects)
|   +---fonts                  # Font files for text and UI elements
|   +---particles              # Particle textures and configurations
|   +---sprites                # Individual sprite assets
|   +---tiles                  # Tile textures for the world
|   +---tilesets               # Pre-configured tilesets
|   +---tilesheets             # Full tilesheets for reference or usage
|   \---ui                     # UI-specific assets (icons, buttons, etc.)
+---resources                  # Predefined reusable resources for the game
|   \---droppable_items        # Resource files for items that can be picked up or dropped
+---scenes                     # All scenes in the game, organized by type
|   +---characters             # Scenes for player and NPC characters
|   +---droppable              # Scenes for droppable items
|   +---effects                # Particle effects and other visual elements
|   +---systems                # Scenes for game systems like inventory or save/load
|   +---ui                     # UI scenes such as menus, HUDs, and overlays
|   \---world                  # Scenes representing the game world (e.g., farm, house)
+---scripts                    # Game logic, grouped by functionality
|   +---characters             # Scripts for player and NPC behavior
|   +---droppable              # Scripts for droppable item behavior
|   +---game_systems           # Core systems like saving, loading, and inventory
|   +---scenes                 # Scene-specific scripts
|   +---singletons             # Global scripts (autoloads) like managers and factories
|   +---ui                     # UI behavior and interactions
|   \---utils                  # Utility scripts for general-purpose logic
+---tests                      # Test files for automated or manual testing
\---textures                   # General textures that don't belong to specific assets

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
