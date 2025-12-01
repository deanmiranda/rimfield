# Farming Paths Tileset Documentation

## Overview

This document catalogs all soil/path tiles used by the Farmable TileMapLayer in the Rimfield farming system. The tiles are driven by the `SoilShape` enum and `SOIL_*` constants defined in `scripts/game_systems/farming_manager.gd`.

The autotiling system uses adjacency-based logic to determine which tile sprite to display based on neighboring soil tiles. Wet soil variants may be added in the future and will use the terrain system (`TERRAIN_ID_WET_SOIL`) rather than direct atlas coordinates.

## Dry Soil Tiles

The following table lists all dry soil tiles currently used by the autotiling system:

| Shape Name | SOIL_* Constant | Description | Atlas Coordinates (x, y) |
|------------|----------------|-------------|-------------------------|
| SINGLE | `SOIL_SINGLE` | Isolated 1-tile patch | (8, 9) |
| BLOCK_CENTER | `SOIL_BLOCK_CENTER` | Interior blob tile (no grass edge) | (5, 6) |
| HORZ_MIDDLE | `SOIL_HORZ_MIDDLE` | Middle of horizontal paths (length ≥ 3) | (12, 9) |
| VERT_MIDDLE | `SOIL_VERT_MIDDLE` | Middle of vertical paths (length ≥ 3) | (12, 8) |
| HORZ_END_LEFT | `SOIL_HORZ_END_LEFT` | Horizontal end pointing left | (10, 6) |
| HORZ_END_RIGHT | `SOIL_HORZ_END_RIGHT` | Horizontal end pointing right | (9, 6) |
| VERT_END_UP | `SOIL_VERT_END_UP` | Vertical end at top | (13, 6) |
| VERT_END_DOWN | `SOIL_VERT_END_DOWN` | Vertical end at bottom | (13, 11) |
| CORNER_UP_LEFT | `SOIL_CORNER_UP_LEFT` | Corner: path goes up and left, grass on bottom-right | (10, 15) |
| CORNER_UP_RIGHT | `SOIL_CORNER_UP_RIGHT` | Corner: path goes up and right, grass on bottom-left | (12, 14) |
| CORNER_DOWN_LEFT | `SOIL_CORNER_DOWN_LEFT` | Corner: path goes down and left, grass on top-right | (13, 15) |
| CORNER_DOWN_RIGHT | `SOIL_CORNER_DOWN_RIGHT` | Corner: path goes down and right, grass on top-left | (13, 12) |
| T_UP | `SOIL_T_UP` | T-junction: open up, horizontal path with road from bottom | (10, 18) |
| T_DOWN | `SOIL_T_DOWN` | T-junction: open down, horizontal path with road from top | (12, 18) |
| T_LEFT | `SOIL_T_LEFT` | T-junction: open left, vertical path with road from right | (13, 19) |
| T_RIGHT | `SOIL_T_RIGHT` | T-junction: open right, vertical path with road from left | (13, 21) |
| CROSS | `SOIL_CROSS` | 4-way path intersection | (13, 17) |

### Shape Selection Logic

The autotiling system determines which tile to use based on the number and position of soil neighbors:

- **0 neighbors**: `SINGLE`
- **1 neighbor**: `END` piece (direction based on neighbor position)
- **2 neighbors**:
  - Same axis (U+D or L+R): `VERT_MIDDLE` or `HORZ_MIDDLE`
  - Perpendicular axes: `CORNER_*` variants
- **3 neighbors**: `T_*` variants (shape based on missing neighbor)
- **4 neighbors**:
  - All diagonals also soil: `BLOCK_CENTER`
  - Otherwise: `CROSS`

## Known Wet Soil Tiles (Future Use)

The following wet soil tiles are defined in code but not yet used by the autotiling system. They are documented here for future implementation:

### Terrain-Based Wet Soil
- Terrain ID `TERRAIN_ID_WET_SOIL` (2) at:
  - (5, 9) - General wet soil tile
  - (11, 6) - Wet T-junction variant (legacy)

### Wet T-Junction Variants
These constants are defined but not wired into logic yet:

| Constant | Description | Atlas Coordinates (x, y) |
|----------|-------------|-------------------------|
| `WET_T_UP` | Wet T-junction: open up | (11, 18) |
| `WET_T_DOWN` | Wet T-junction: open down | (13, 18) |
| `WET_T_LEFT` | Wet T-junction: open left | (13, 20) |
| `WET_T_RIGHT` | Wet T-junction: open right | (13, 22) |

**Note**: These wet constants are currently defined in `FarmingManager` but are not used by the autotiling system. The current watering behavior uses the terrain system (`TERRAIN_ID_WET_SOIL`) which applies wet soil visuals via Godot's terrain autotiling, not direct atlas coordinate placement.

## Corner Debug Helpers

The following debug functions are available in `FarmingManager` to help diagnose corner mapping issues:

- **`debug_log_corner_for_cell(cell: Vector2i)`**: Logs diagnostic information for a specific cell, including neighbor pattern (e.g., "UR", "DL"), computed SoilShape, and assigned atlas coordinates. Use this to verify which atlas tile is being used for a specific corner pattern.

- **`debug_log_corners_around_player()`**: Scans a 7x7 region around the player's current position and logs all corner shapes found in that area. This is useful for quickly checking multiple corners after creating L-shaped paths with the hoe tool.

**How to interpret the output:**
- The neighbor pattern shows which directions have soil neighbors (U=up, R=right, D=down, L=left)
- The shape shows the computed SoilShape enum value (e.g., CORNER_UP_RIGHT)
- The atlas shows the actual tile coordinates being used (e.g., (12, 14))
- If the visual doesn't match the expected direction, compare the neighbor pattern → SoilShape → atlas mapping to identify which constant needs adjustment

## Maintenance Notes

### Adding a New Soil/Path Tile

To add a new soil or path tile to the tileset:

1. **Add the tile sprite to `tiles.png`**:
   - Open the tileset image file at `res://assets/tilesets/full version/tiles/tiles.png`
   - Add your new tile sprite at the desired atlas coordinates
   - Note the exact (x, y) coordinates in the atlas

2. **Find the atlas coordinates**:
   - In Godot, open the TileSet resource (`FarmingTerrain.tres`)
   - Select the tile in the tileset editor
   - The atlas coordinates are shown in the editor (0-indexed from top-left)
   - Alternatively, use an image editor to count tiles (each tile is 16×16 pixels)

3. **Update the corresponding constant**:
   - Open `scripts/game_systems/farming_manager.gd`
   - Find or create the appropriate `SOIL_*` constant
   - Set it to `Vector2i(x, y)` where x and y are the atlas coordinates

4. **Extend SoilShape enum (if needed)**:
   - If the new tile represents a new shape pattern, add it to the `SoilShape` enum
   - Update `_compute_soil_shape()` to detect the new pattern
   - Update `_soil_shape_to_atlas()` to map the new shape to the new constant

5. **Update `_is_soil_cell()`**:
   - Add the new constant to the `soil_atlas_coords` array in `_is_soil_cell()`
   - This ensures the new tile is recognized as "soil" for adjacency calculations

6. **Test the autotiling**:
   - Use the hoe tool to create soil patterns that trigger the new tile
   - Verify the tile appears correctly in all expected scenarios
   - Check that watering and planting still work correctly

### Updating Existing Tile Coordinates

If you need to move a tile to a different location in the atlas:

1. Update the `SOIL_*` constant in `farming_manager.gd`
2. Update the terrain assignments in `FarmingTerrain.tres` if the tile is used by the terrain system
3. Test thoroughly to ensure all patterns still render correctly
4. Update this documentation table

### Debugging Autotiling Issues

If tiles are not rendering correctly:

1. Enable debug logging by setting `DEBUG_SHOW_SOIL_SHAPES := true` in `farming_manager.gd`
2. Check the console output when using the hoe tool
3. Verify that `_compute_soil_shape()` is returning the expected `SoilShape` value
4. Verify that `_soil_shape_to_atlas()` is mapping to the correct atlas coordinates
5. Check that `_is_soil_cell()` recognizes the tile as soil (for adjacency calculations)

