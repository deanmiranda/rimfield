# FarmingTerrain.tres Build Instructions

## Current Status
The TileSet file has been created with the basic structure, but tile coordinates need to be verified by inspecting the tilesheet image.

## Required Steps

1. **Open the tilesheet**: `res://assets/tilesets/full version/tiles/tiles.png`

2. **Identify farming tiles**:
   - **Grass tiles**: Green/grass-colored tiles (terrain 0)
   - **Soil tiles**: Brown/tan dirt tiles (terrain 1)
   - **WetSoil tiles**: Darker/wet dirt tiles (terrain 2)

3. **For Match Corners mode**, you need:
   - **Base center tiles** (one per terrain) - Godot will auto-generate edge/corner variations
   - OR **All 47 mask variations** explicitly defined (if you want full control)

4. **Current placeholder coordinates** in FarmingTerrain.tres:
   - Grass: `0:0/0 = 0` (needs verification)
   - Soil: `0:1/0 = 0` (needs verification)
   - WetSoil: `0:2/0 = 0` (needs verification)

5. **Terrain assignment format**:
   ```
   atlas_x:atlas_y/alternative = terrain_set:terrain_id
   ```
   For terrain_set 0:
   - Grass: `X:Y/0 = 0:0`
   - Soil: `X:Y/0 = 0:1`
   - WetSoil: `X:Y/0 = 0:2`

## Next Steps
1. Inspect tilesheet and identify actual coordinates for grass, soil, and wet soil tiles
2. Update FarmingTerrain.tres with correct coordinates
3. Test in Godot editor to verify terrain auto-tiling works correctly

