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
