# Absolute Path Replacement Map

## Summary
Found **5 absolute `/root/...` paths** in `scripts/singletons/hud.gd` that violate `.cursor/rules/godot.md` rule: "Never use absolute `/root/...` lookups."

---

## Path Map

| File | Line | Old Path | Context | Proposed Fix Type | Rationale |
|------|------|----------|---------|------------------|-----------|
| `scripts/singletons/hud.gd` | 28 | `/root/Farm` | `setup_hud()` - Check if farm scene exists | **(b) Injected reference** | Farm scene should inject itself via signal or method call |
| `scripts/singletons/hud.gd` | 31 | `/root/Farm/FarmingManager` | `setup_hud()` - Get FarmingManager | **(b) Injected reference** | Already has `set_farming_manager()` - use that instead |
| `scripts/singletons/hud.gd` | 37 | `/root/Farm/Hud/ToolSwitcher` | `setup_hud()` - Connect to ToolSwitcher | **(b) Injected reference** | Inject hud_instance reference, then use relative path |
| `scripts/singletons/hud.gd` | 45 | `/root/Farm/Hud/HUD/MarginContainer/HBoxContainer` | `setup_hud()` - Get tool buttons | **(b) Injected reference** | Cache from injected hud_instance |
| `scripts/singletons/hud.gd` | 95 | `/root/Farm/Hud/HUD/MarginContainer/HBoxContainer` | `_highlight_active_tool()` - Get tool buttons | **(b) Cached reference** | Use cached reference from setup |

---

## Fix Strategy

### Primary Approach: Injected References + Cached Refs

1. **Add injection method** `set_hud_scene_instance(hud_instance: Node)` to HUD singleton
2. **Cache references** in HUD singleton:
   - `var slots_container: HBoxContainer` (cached from hud_instance)
   - `var tool_switcher: Node` (cached from hud_instance)
3. **Update farm_scene.gd** to call injection method after instantiating HUD
4. **Remove absolute paths** and use cached references

### Benefits
- ✅ Follows `.cursor/rules/godot.md` (no absolute paths)
- ✅ Maintains current architecture (no scene restructuring)
- ✅ Performance improvement (cached refs vs repeated lookups)
- ✅ Extensible (works with any scene structure)

---

## Implementation Order

1. **hud.gd** - Add injection method and cache refs (HIGH PRIORITY)
2. **farm_scene.gd** - Call injection method (HIGH PRIORITY)

---

## Notes

- `farming_manager` already has injection via `set_farming_manager()` - just need to ensure it's called
- ToolSwitcher is a sibling of HUD in the scene tree - can use relative path once we have hud_instance
- All paths point to nodes within the instantiated `hud_instance` scene, so injection is the cleanest solution

