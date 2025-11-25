# Game Time & Day/Night System – Design (Rimfield)

This document defines the behavior and requirements for the game time system and day/night cycle in Rimfield. All time-related features should follow this design.

## High-Level Goals

- Have a single, reliable time system for:

  - In-game clock

  - Day/night visuals

  - Midnight warning and 2AM pass-out

  - Save/load of time and date

- Make time pausable (e.g., inventory open) in a clear, centralized way.

- Keep the design future-proof for crops, NPC schedules, events, etc.

---

## Core Time System

### Requirements

- Use an internal tick system inspired by Stardew's pacing.

- Track:

  - `time_of_day`

  - `day` (1–28)

  - `season` (4 seasons per year)

  - `year` (starting at 1)

- Time advances only when the game is NOT paused.

- A single `GameTimeManager` (likely a singleton/autoload) owns time.

### Acceptance Criteria

- There is a single `GameTimeManager.gd` that:

  - Can be queried from anywhere for time_of_day/day/season/year.

  - Exposes a method like `advance_time(ticks: int)`.

  - Exposes methods to pause/unpause time.

- Time visibly advances in-game while the player can move around.

- Time does not advance when the game is paused or on menus.

---

## In-Game Clock & HUD

### Requirements

- HUD shows a clock that:

  - Starts at 6:00 AM when the player wakes up.

  - Advances in discrete ticks based on the game's pacing.

- The clock reflects the real game time from GameTimeManager.

- At midnight (12:00 AM), the clock changes appearance to warn the player.

- The inventory panel must display the same consistent time.

### Acceptance Criteria

- The HUD clock reads time from GameTimeManager (no internal time state).

- The clock updates visually as time advances.

- At 12:00 AM:

  - The clock text turns red (or some clear danger color).

  - The clock shakes or shows some warning effect.

- At 2:00 AM, the pass-out sequence begins (see below).

---

## Day/Night Lighting

### Requirements

- Implement time-based lighting for:

  - Morning (e.g., 6:00–10:00)

  - Midday (10:00–16:00)

  - Evening/Dusk (16:00–20:00)

  - Night (20:00–2:00)

- Morning and midday are brighter.

- Evening is warm and softer.

- Night is darker but not fully black (player and world still readable).

- Control lighting through a single controller (overlay/environment) that reacts to time.

### Acceptance Criteria

- A `DayNightController` (or similarly named script) listens to GameTimeManager.

- The lighting clearly shifts throughout the day.

- At night, it is clearly darker but still playable.

- Lighting changes are driven by GameTimeManager state, not by ad-hoc timers.

---

## Midnight Warning & 2AM Pass-Out

### Requirements

- At 12:00 AM (midnight):

  - Player is visually warned via clock shaking/turning red.

- At 2:00 AM:

  - The player automatically "passes out" no matter where they are.

  - A short sequence:

    - Disable movement/input.

    - Fade to black.

    - Advance the day by one.

    - Reset time to 6:00 AM.

    - Return the player to their bed (or a designated wake-up point).

    - Re-enable input.

### Acceptance Criteria

- Reaching midnight triggers a visible warning on the HUD clock.

- Reaching 2:00 AM:

  - Always triggers a pass-out sequence.

  - Always increments the day by 1.

  - Always resets time to the defined wake-up time (e.g., 6:00).

  - Always returns the player to a valid wake-up location.

  - Leaves the game in a valid, interactive state afterward (not soft-locked).

---

## Pause Behavior (Inventory / Menus)

### Requirements

- Opening the inventory panel pauses time.

- Closing the inventory panel resumes time.

- Optionally, other menus (pause menu, settings, etc.) also pause time.

- There must be a single, canonical "paused" flag, controlled through GameTimeManager or a central game state manager.

### Acceptance Criteria

- While inventory is open, time_of_day does not change.

- When inventory is closed, time_of_day continues to advance.

- It is easy to see in code where `game_paused` is set and cleared.

---

## Save/Load Integration

### Requirements

- Save files must include:

  - time_of_day

  - day

  - season

  - year

- On load:

  - GameTimeManager restores these values.

  - HUD and lighting immediately match the restored time.

- Time state must be self-contained and not depend on hidden global state.

### Acceptance Criteria

- Saving in the middle of the day, quitting, and reloading restores:

  - Same time

  - Same day/season/year

  - Matching HUD and lighting

- Saving at night and loading preserves correct midnight/2AM behavior.

---

## Future Hooks (For Later Systems)

### Requirements

- The time system should be usable by:

  - Crop growth

  - NPC schedules

  - Events/festivals

  - Weather

- Do not hard-code this now, but leave hooks/signals for other systems to attach to later.

### Acceptance Criteria

- GameTimeManager exposes signals such as `time_changed` and `day_changed`.

- Other systems can connect to these signals without modifying GameTimeManager.

---

## Implementation Phases (High-Level)

This is the rough order to implement:

1. Implement `GameTimeManager` (data only, no UI or lighting).

2. Wire HUD clock to GameTimeManager.

3. Implement `DayNightController` that adjusts visuals based on time.

4. Implement midnight warning and 2AM pass-out using signals from GameTimeManager.

5. Wire inventory/menu open/close to pause/unpause time.

6. Integrate time state into save/load.

Each step should be implemented and tested in isolation before moving on.

---

End of file.

---

