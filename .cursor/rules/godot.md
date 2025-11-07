# Godot Development Rules

## Error-Avoidance Patterns

### Control vs CanvasLayer

- Never assign a CanvasLayer node to a variable typed as Control.

- CanvasLayer is a Node, not a Control; it exists to isolate UI from world-space transforms.

- When creating UI:

  * Use a Control node as the root of the layout.

  * Place that Control **under** a CanvasLayer (do not replace the Control with the CanvasLayer).

  * CanvasLayer holds one or more Control scenes, each centered via anchors or containers.

- Type integrity guidelines:

  * Control variables only receive Control or derived types (VBoxContainer, MarginContainer, CenterContainer, etc.).

  * Node or CanvasLayer variables may contain CanvasLayer.

  * When instantiating a scene with CanvasLayer root, access the Control child via `get_node("Control")` or change the variable type to Node/CanvasLayer.

- Scene structure pattern:

  ```
  CanvasLayer (root, layer = 10)
  └── Control (full-screen anchors, script attached here)
      └── CenterContainer (or other container for layout)
          └── Content nodes...
  ```

- Prefer adding a new Control **as a child** of a CanvasLayer rather than changing the CanvasLayer's type.

### Interaction Pattern

- Keep world interactions event-driven (signals, input), not _process polling.

- Use signal-based sets to track nearby interactables:

  * Maintain arrays/sets updated via Area2D `body_entered`/`body_exited` or `area_entered`/`area_exited` signals.

  * Check these sets in `_unhandled_input()` when action is pressed, not in `_process()`.

- Use groups for identifying interactable types:

  * Add items to groups like "pickable", "door", etc.

  * Check membership with `is_in_group()` rather than type checking or path lookups.

- Interaction radius should come from GameConfig resource, not magic numbers.

### UI Indicators

- Hover affordances live in CanvasLayer and react to input events.

- Use `_unhandled_input(InputEventMouseMotion)` to detect mouse movement, not `_process()` polling.

- Position indicators using viewport screen coordinates, not world coordinates.

- Use timers to hide indicators after mouse stops moving (avoid flicker).

## World / Viewport Access (Godot 4.4)

- Do NOT call `get_world_2d()` on plain `Node` or classes that are not `CanvasItem`.

- Preferred:

  - From `CanvasItem`/`Node2D`/`Control`: `get_viewport().get_world_2d()`

  - From non-Canvas nodes (e.g., `Node`, singletons, data models): `get_tree().root.get_world_2d()`

- If a script may be used from **either** context, call `World2DUtil.get_world_2d_for(self)`.

- No `/root` path lookups. Use SceneTree/Viewport APIs only.

- No ternary operators. Use explicit `if/else`.

### Auto-Heal Note

- When a parser/runtime error says: `Function "get_world_2d()" not found in base self`, refactor to use the utility below and re-run.

## Mouse Position (Godot 4.4)

- Do NOT call `get_global_mouse_position()` on `Window` or via `get_tree().root`. `Window` has no such method.

- Preferred APIs:

  - **Viewport (screen coords):** `get_viewport().get_mouse_position()`

  - **2D world coords:** Use `MouseUtil.get_world_mouse_pos_2d(self)` or manually convert using camera transform.

- From non-Canvas contexts (e.g., `extends Node`), use a utility to resolve the correct `Viewport` and Camera2D.

- No `/root` path lookups. Use SceneTree/Viewport accessors only.

- No ternary operators. Use explicit `if/else`.

### Auto-Heal Trigger

- When you see: `Invalid call. Nonexistent function 'get_global_mouse_position' in base 'Window'`

  → Replace with `MouseUtil.get_world_mouse_pos_2d(self)` (or `get_viewport_mouse_pos(self)` for screen coords).

## Camera2D API (Godot 4.4)

- Do NOT call `screen_to_world()` on `Camera2D`. This method does not exist in Godot 4.

- To convert screen coordinates to world coordinates:

  - Use `MouseUtil.get_world_mouse_pos_2d(self)` for mouse position conversion.

  - Or manually calculate: `camera.global_position + (screen_pos - viewport_center) / camera.zoom`

  - Formula: `world_pos = camera.global_position + (screen_pos - viewport.size / 2.0) / camera.zoom`

- No `/root` path lookups. Use SceneTree/Viewport APIs only.

- No ternary operators. Use explicit `if/else`.

### Auto-Heal Trigger

- When you see: `Invalid call. Nonexistent function 'screen_to_world' in base 'Camera2D'`

  → Replace with `MouseUtil.get_world_mouse_pos_2d(self)` or use the manual conversion formula above.

## Typed Declarations & Nulls (Godot 4.4)

- Do NOT write `var x := null`. GDScript 2.0 cannot infer a type from `null`.

- Prefer explicit typed declarations without an initializer, then assign in branches:

  - ✅ `var vp: Viewport`  # assign later

  - ❌ `var vp := null`

- If a function may return `null`, OMIT the return type annotation. Do NOT declare `-> World2D` (or similar) if `null` is a possible return.

- Keep branch-safe assignment (no ternary). No `/root` path lookups.

### Auto-Heal Trigger

- When you see: `Parser Error: Cannot infer the type of "<NAME>" variable because the value is "null"`

  → Replace `var <NAME> := null` with `var <NAME>: <ExpectedType>` (no initializer) and ensure explicit assignment in `if/else` before first read.
