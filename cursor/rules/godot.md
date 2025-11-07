# Godot Repo Rules (Godot 4.x)

## Global
- Language: GDScript 2.0. Target Godot 4.4.
- No ternary operators. Always use explicit `if/else`.
- Use signals for decoupling. No singletons grabbing nodes via absolute paths.
- Prefer Resources/.tres for data configs over hard-coding.
- Keep scenes small and composable; avoid “god” nodes.

## Project Structure (expected)
- `addons/` – editor add-ons
- `autoload/` – singletons (GameState.gd, EventBus.gd)
- `scenes/` – .tscn files collocated with their scripts
- `scripts/` – shared non-scene logic (pure utility)
- `ui/` – UI scenes + styles
- `assets/` – art/audio/fonts
- `data/` – .tres/.res configs

## Code style
- Signals at top, then constants, exports, variables, `_ready`, `_process`, public funcs, private funcs.
- Exported vars have type hints; prefer `@onready var` for node refs.
- No logic inside `_ready` that can run in constructors.
- Use `InputMap` names; no hardcoded keycodes.

## Testing & safety
- For refactors, propose an incremental plan and a checklist of breaking changes.
- When creating or editing scenes/scripts, explain how it improves architecture.

## Commit etiquette (for Cursor’s changes)
- Group changes by subsystem; include migration notes if renaming nodes.
