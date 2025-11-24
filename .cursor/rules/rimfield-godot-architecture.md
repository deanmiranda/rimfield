# Rimfield – Godot Architecture Rules

## Scope

These rules apply to all code and design for the **Rimfield** project
(Godot 4.x, GDScript). The assistant must prioritize **clean architecture,
extensibility, and data-driven systems** over quick hacks.

## High-level principles

1. **Single source of truth**
   - Each domain has a clear data model and a manager that owns it:
     - Farming → `FarmingManager` + `TileData`
     - Time → `TimeManager`
     - Inventory/Containers → `Inventory` + `Container`
     - Player stats → `PlayerState` / `EnergyManager`
   - UI and visuals should *subscribe* to state via signals, not mutate it.

2. **Feature-first design, but architecture-aware**
   - When implementing a feature, design the **data model and API** before
     writing implementation details or UI glue.
   - Always consider **save/load**, **signals**, and **future extensions**
     while designing a feature.

3. **Event-driven, not tightly coupled**
   - Use Godot signals to communicate between systems.
   - Managers expose methods and signals; other code should not reach in
     and modify internal state directly.

4. **No spaghetti / minimal global state**
   - Prefer a small set of well-defined autoloads (singletons), each with
     a clear responsibility.
   - Do *not* scatter flags or loose state across random nodes.

5. **Code style**
   - Godot 4.x GDScript.
   - No ternary operators; use explicit `if/else`.
   - Clear, descriptive names: `water_tile`, `advance_day`, `spend_energy`.

---

## Pattern to follow for EVERY new feature

Whenever the user says they want to add or change a feature
(e.g. watering system, containers, task queue, NPCs, etc.),
the assistant must internally walk through this checklist and
structure its answer accordingly:

### 1. Data model

- Define or confirm the core data structures as GDScript classes or
  Resources, e.g.:

  - For farming:
    - `TileData` with fields like `state`, `crop_id`, `growth_stage`,
      `moisture`, `fertility`, etc.
  - For inventory:
    - `InventoryItem`, `InventorySlot`, `InventorySnapshot`.

- Ensure new concepts that might expand later (e.g. soil quality,
  watering levels, item rarity) already have a **field or hook**
  in the data model, even if unused at first.

### 2. Manager / owner

- Identify or define the single manager responsible:
  - `FarmingManager`, `InventoryManager`, `TimeManager`, `EnergyManager`,
    `TaskQueueManager`, etc.

- Clearly list this manager’s responsibilities and boundaries, e.g.:
  - `FarmingManager`:
    - owns `Dictionary<Vector2i, TileData>`
    - exposes `hoe_tile`, `plant_seed`, `water_tile`
    - handles growth on day advance.

### 3. Public API

For each manager, define **public methods** as clean verbs:

- Example for watering:
  - `func water_tile(pos: Vector2i) -> void`
  - `func on_day_advanced(new_day: int) -> void`

- Example for inventory:
  - `func add_item(item_id: StringName, count: int) -> int`
  - `func move_item(src_slot: int, dst_slot: int) -> void`
  - `func to_snapshot() -> InventorySnapshot`
  - `static func from_snapshot(snapshot: InventorySnapshot) -> Inventory`

These methods are the only way other systems should interact with the
feature.

### 4. Signals / events

- Design signals the manager will emit, such as:
  - `signal tile_updated(pos: Vector2i, data: TileData)`
  - `signal item_added(slot_index: int, item: InventoryItem)`
  - `signal energy_changed(value: int)`
  - `signal day_advanced(new_day: int)`

- UI, world nodes, and VFX should respond to these signals rather than
  manually reading and writing state.

### 5. Integration points

For each feature, the assistant must explicitly cover:

- How it connects to:
  - `TimeManager` (e.g. `day_advanced`)
  - `EnergyManager` (action costs)
  - `Save/Load` system (serialization)
  - Existing managers (e.g. watering integrates with `FarmingManager`)

- Any new autoloads needed, and why.

### 6. Save/load implications

- For every new data model/manager, define:
  - what needs to be serialized (`TileData`, inventory snapshots, time),
  - where it lives in the save structure,
  - how to reconstruct it on load.

- Prefer small, explicit snapshot structs/dictionaries instead of
  serializing whole nodes.

### 7. Future extension / hooks

- Before finalizing a design, the assistant must call out at least
  one future extension and how the current design supports it, e.g.:

  - Watering system:
    - future soil quality grading uses existing `fertility`/`moisture`
      fields in `TileData`.
  - Inventory:
    - containers and shipping bins reuse the same `Inventory` class and
      `InventorySnapshot` logic.

The assistant should **avoid** designs that will obviously block
future features the user has already mentioned (e.g. soil grading,
shipping bin, crafting, NPC schedules).

---

## When answering Rimfield questions

- Always:
  - identify which manager(s) are involved,
  - describe the data model and signals,
  - mention how save/load would work,
  - mention at least one future hook.

- Prefer concrete, Godot-ready examples (GDScript snippets, signal
  definitions, scene structure) over vague advice.
