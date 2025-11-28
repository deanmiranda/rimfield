# Time System & Day/Night Rules (Rimfield)

## Scope

These rules apply to ALL code that touches:

- Game time

- Day/night cycle

- Clock HUD

- Lighting based on time

- Midnight warning and 2AM pass-out

- Save/load of time/day/season/year

in this project.

You must respect these rules whenever modifying or generating code in this area.

## Architecture (must follow)

- There is a SINGLE source of truth for game time: **GameTimeManager**.

- GameTimeManager is responsible for:

  - `time_of_day` (in ticks / minutes, Stardew-like pacing)

  - `day` (1–28)

  - `season` (4 seasons per year)

  - `year` (starting at 1)

  - `game_paused` (bool)

- GameTimeManager exposes methods such as:

  - `advance_time(ticks: int)`

  - `set_paused(paused: bool)`

  - `save_state() -> Dictionary`

  - `load_state(state: Dictionary)`

- GameTimeManager emits signals ONLY for notification, for example:

  - `time_changed`

  - `day_changed`

  - `midnight_warning`

  - `pass_out`

- UI, lighting, and gameplay systems:

  - READ state from GameTimeManager

  - REACT to its signals

  - NEVER maintain their own independent "current time".

## Invariants (must NEVER be broken)

These conditions must always hold true in a correct implementation:

1. **Single clock**

   - GameTimeManager is the ONLY authority on time.

   - No other script keeps its own "current time" that can diverge.

2. **Pause behavior**

   - When `game_paused == true`, time MUST NOT advance.

   - No script may call `advance_time` while the game is paused.

   - Opening the inventory or pause menus sets `game_paused = true`.

   - Closing them sets `game_paused = false`.

3. **Consistency of time/day/season/year**

   - At any moment, the tuple `(time_of_day, day, season, year)` is logically consistent and can be serialized/deserialized without extra hidden state.

   - `save_state()` and `load_state()` must be enough to fully restore time.

4. **Derived visuals**

   - HUD clock, day text, lighting, and any other visual representation MUST be derived from GameTimeManager state.

   - Visuals may NEVER drive time (no "changing time to match the UI").

5. **Midnight and 2AM behavior**

   - When time reaches midnight (00:00), GameTimeManager emits a `midnight_warning` signal (or equivalent behavior) but does NOT directly manipulate UI visuals itself.

   - When time reaches 2:00 AM:

     - GameTimeManager emits a `pass_out` signal.

     - The pass-out sequence MUST:

       - Increment `day` by exactly 1.

       - Reset `time_of_day` to the defined wake-up time (e.g., 6:00 AM).

       - Leave `season` and `year` correct according to day progression.

       - Eventually return the player to a valid wake-up location.

       - Ensure player input is re-enabled after waking.

   - The pass-out sequence MUST NOT leave the game stuck in a paused or soft-locked state.

6. **No hidden time advancement**

   - Time may only advance through GameTimeManager (e.g., in `_process`, `_physics_process`, or explicit calls to `advance_time`).

   - No other system is allowed to "secretly" increment time.

## Allowed / Forbidden code patterns

### Allowed

- UI scripts:

  - Subscribing to GameTimeManager signals.

  - Formatting and displaying time/day/season/year.

  - Adjusting visual styles (e.g., clock turning red, shaking at midnight).

- Lighting scripts:

  - Subscribing to GameTimeManager time changes.

  - Adjusting overlays, environment, or shaders based on `time_of_day`.

- Save system:

  - Calling `GameTimeManager.save_state()` / `load_state()` and putting the result into the global save file.

### Forbidden

- Any script other than GameTimeManager:

  - Maintaining its own clock or tick counter for "current time".

  - Manually incrementing time_of_day/day/season/year.

  - Deciding when midnight or 2AM happens.

- GameTimeManager:

  - Directly changing UI nodes.

  - Directly tweaking lighting nodes.

  - Being tightly coupled to specific scenes.

## Cursor-specific rules (VERY IMPORTANT)

When you (Cursor / LLM) modify or generate code related to this system:

1. **One file at a time**

   - Do not modify more than ONE file per request unless explicitly instructed by the user.

   - If a change requires touching multiple files, explain the plan first and wait for confirmation.

2. **No surprise new classes**

   - Do not create new classes, autoloads, or singletons unless you first PROPOSE them in text and get approval.

   - Respect the existing role of GameTimeManager as the sole time authority.

3. **Explain before editing**

   - Before writing code, restate:

     - Which file you are touching.

     - What you are changing.

     - Which invariants are relevant.

   - Only then produce a small, readable diff.

4. **Never violate invariants silently**

   - If a requested change would violate any invariant above, you MUST say so and propose an alternative instead of forcing the change.

5. **No mixed concerns**

   - Time logic must stay in GameTimeManager (and possibly a separate pass-out controller), not leak into random UI or gameplay scripts.

   - UI must only react and display; it must not own game time.

---

End of file.

---

