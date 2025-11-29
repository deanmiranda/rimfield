# Farming System Testing Checklist

## ✅ Confirmed Working (User Verified)
- [x] **Crop Growth**: Carrots progress one stage per day when watered
- [x] **Dry Soil After Seeding**: Dry soil remains dry after planting seeds
- [x] **Watering Visual**: Watering correctly updates tile visuals
- [x] **No Crashes/Warnings**: System runs without errors

## 🧪 Additional Tests to Run

### 1. **Watering State Reversion (Critical)**
**What to test:** Watered tiles should revert to dry on the next day
- [ ] Water some soil tiles (should become "tilled")
- [ ] Water some planted crops (should become "planted_tilled")
- [ ] Sleep to next day
- [ ] **Expected:** All watered tiles should revert to dry:
  - "tilled" → "soil" (dry soil visual)
  - "planted_tilled" → "planted" (dry crop, soil underneath should be dry)

### 2. **Save/Load Persistence (Critical)**
**What to test:** All farm state should persist across save/load
- [ ] Till some soil, plant some seeds, water some tiles
- [ ] Let some crops grow to different stages (stage 0, 2, 4, etc.)
- [ ] Save the game
- [ ] Quit and reload
- [ ] **Expected:** 
  - All tile states restored correctly (soil, tilled, planted, planted_tilled)
  - All crop growth stages preserved
  - Crop sprites visible on crop layer
  - Soil visuals correct on farmable layer

### 3. **Multi-Day Growth Cycle**
**What to test:** Crops should grow consistently over multiple days
- [ ] Plant 6 seeds
- [ ] Water all 6
- [ ] Sleep (Day 1 → Day 2)
- [ ] **Expected:** All crops advance to stage 1
- [ ] Water all 6 again
- [ ] Sleep (Day 2 → Day 3)
- [ ] **Expected:** All crops advance to stage 2
- [ ] Continue until stage 5 (fully grown)
- [ ] **Expected:** Crops stop at stage 5 and don't advance further

### 4. **Unwatered Crops Don't Grow**
**What to test:** Crops should only grow if watered the previous day
- [ ] Plant 2 seeds
- [ ] Water only 1 seed
- [ ] Sleep
- [ ] **Expected:** 
  - Watered crop advances to stage 1
  - Unwatered crop stays at stage 0

### 5. **Crop Layer Visibility**
**What to test:** Crops should render on top of soil, not replace it
- [ ] Plant a seed on dry soil
- [ ] **Expected:** Crop sprite visible, dry soil visible underneath
- [ ] Water the planted crop
- [ ] **Expected:** Crop sprite still visible, wet soil (tilled) visible underneath
- [ ] Sleep to next day
- [ ] **Expected:** Crop sprite still visible, dry soil visible underneath

### 6. **Pickaxe Functionality**
**What to test:** Pickaxe should clear crops and reset tiles to grass
- [ ] Plant a seed and let it grow to stage 3
- [ ] Use pickaxe on the planted tile
- [ ] **Expected:** 
  - Crop sprite removed from crop layer
  - Tile reset to grass on farmable layer
  - GameState updated to "grass"

### 7. **Season/Year Rollover**
**What to test:** Absolute day calculation should work across season boundaries
- [ ] Plant and water crops on Day 28 of a season
- [ ] Sleep (Day 28 → Day 1 of next season)
- [ ] **Expected:** Crops should still grow correctly (absolute day tracking works)

## 📋 What the Changes Were Supposed to Do

### 1. **FarmingManager Linking**
- **Purpose:** Ensure FarmingManager has reference to farm scene for accessing crop layer
- **Status:** ✅ Fixed - `set_farm_scene()` called in `farm_scene._ready()`

### 2. **Crop Layering (Separate from Soil)**
- **Purpose:** Crops render on separate layer above soil, so you can see soil state underneath
- **Status:** ✅ Working - Crop layer created with `z_index = 1`
- **Visual Test:** You should see crop sprites on top of soil, not replacing it

### 3. **Save/Load System**
- **Purpose:** Persist both soil states and crop data (growth stages, watering info)
- **Status:** ⚠️ **NEEDS TESTING** - Please test save/load to verify

### 4. **Watering Tracking**
- **Purpose:** Track `last_watered_day_absolute` for accurate growth across season boundaries
- **Status:** ✅ Working - Uses `GameTimeManager.get_absolute_day()`

### 5. **Crop Growth Advancement**
- **Purpose:** Crops advance one stage per day if watered the previous day
- **Status:** ✅ **CONFIRMED WORKING** - You verified this!

### 6. **Watered State Reversion**
- **Purpose:** Watered tiles revert to dry on new day (watering lasts one day)
- **Status:** ⚠️ **NEEDS TESTING** - Please test sleeping after watering

### 7. **Farmable Area Detection**
- **Purpose:** Tools should only work on designated farmable tiles
- **Status:** ⚠️ **ARCHITECTURAL TODO** - Currently all tiles are farmable (may be by design)

## 🏗️ Architectural TODO

### Farmable Layer Architecture
**Issue:** Currently ALL tiles on the farm scene are farmable
**Question:** Is this intentional, or should there be a restricted farmable area?
**Options:**
1. **Current Behavior (All Tiles Farmable):** If this is the intended design, no changes needed
2. **Restricted Farmable Area:** If only certain tiles should be farmable:
   - Need to define farmable region (coordinate bounds, TileMap layer with specific tiles, etc.)
   - Update farmability check to only allow tools in that region
   - May need to adjust TileMap setup in Godot editor

**Action Required:** Determine desired farmable area architecture before implementing restrictions.

