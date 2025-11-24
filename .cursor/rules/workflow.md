# Rimfield Development Workflow Rules

## Primary Rule: Follow NEXT_STEPS.md

**CRITICAL:** Always reference and follow `NEXT_STEPS.md` as the single source of truth for current development priorities.

### When to Update NEXT_STEPS.md:
1. **When user mentions a new bug** → Add it to the appropriate section with:
   - Clear problem description
   - Expected behavior
   - Files to investigate/fix
   - Priority level

2. **When user confirms a bug is fixed** → Update status to ✅ FIXED with:
   - Brief description of the fix
   - Files modified
   - Any follow-up testing needed

3. **After completing a task** → Mark as complete and update status

4. **When priorities change** → Reorganize tasks using best architectural practices:
   - Dependencies first (can't fix B until A is done)
   - Foundation before features (core systems before polish)
   - High-impact, low-effort items prioritized
   - Related bugs grouped together

## Bug Fixing Workflow

### Rule 1: One Bug at a Time
- **NEVER** work on multiple bugs simultaneously
- Focus exclusively on the highest priority bug in NEXT_STEPS.md
- Complete current bug before asking about or starting the next one

### Rule 2: Always Confirm Before Moving On
- After implementing a fix, **ALWAYS** ask: "Is [bug name] fixed? Please test and confirm."
- **ONLY** move to the next bug after user confirms current bug is fixed
- If bug is not fixed, iterate on the same bug until resolved

### Rule 3: Prioritization Logic
When organizing NEXT_STEPS.md, use this priority order:
1. **Blocking bugs** (prevent core functionality)
2. **Data loss bugs** (items destroyed, saves corrupted)
3. **Critical UX bugs** (game-breaking user experience)
4. **High-impact, low-effort fixes** (quick wins)
5. **Medium priority bugs** (annoying but not blocking)
6. **Polish and optimization** (nice-to-have)

Group related bugs together to avoid context switching.

## Communication Style

### Keep Responses Concise
- **Code updates first** - Show the changes made
- **Brief testing instructions** - What to test, what to look for
- **No long explanations** - User will review code and ask if needed

### Response Format:
```
[Brief status update]

**Files Modified:**
- `path/to/file.gd` - What changed

**Testing Instructions:**
1. Test scenario A
2. Test scenario B
3. Expected result

**Next:** Please test and confirm if [bug name] is fixed.
```

### When User Provides Feedback:
- **Pass:** Update NEXT_STEPS.md → Mark bug as ✅ FIXED → Ask about next bug
- **Fail:** Analyze debug output → Fix issue → Provide new testing instructions
- **New Bug:** Add to NEXT_STEPS.md → Prioritize → Ask if we should switch focus

## Code Update Guidelines

### Before Making Changes:
1. Read NEXT_STEPS.md to understand current priority
2. Identify the specific bug/task to work on
3. Read relevant code sections
4. Plan the fix

### Check Existing Patterns Before Suggesting Code Changes:
When encountering errors about missing InputMap actions, project settings, or configuration:
1. **First check** if similar/related actions or settings already exist in `project.godot` or project settings
2. **If a pattern exists**, suggest following that pattern (e.g., adding missing actions to InputMap) rather than code workarounds
3. **Prefer configuration changes** over code changes when an established pattern exists
4. **Only suggest code workarounds** if no configuration pattern exists or if explicitly requested

**Example:** If code uses `Input.is_action_just_pressed("ui_mouse_left")` and errors about `"ui_mouse_right"` missing:
- ✅ **Do:** Check if `ui_mouse_left` exists in InputMap → If yes, suggest adding `ui_mouse_right` to match the pattern
- ❌ **Don't:** Immediately suggest changing code to use `Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)` without checking existing patterns

### When Making Changes:
1. Make focused, targeted fixes
2. Update only what's necessary
3. Preserve debug prints until bugs are confirmed fixed
4. Follow `.cursor/rules/godot.md` coding standards

### After Making Changes:
1. Update NEXT_STEPS.md with status
2. Provide testing instructions
3. Ask for confirmation

## Example Workflow

**User:** "Bug: Items are destroyed when dropping on different item type"

**AI Response:**
1. Add bug to NEXT_STEPS.md under "Critical Bugs"
2. Investigate code
3. Implement fix
4. Update NEXT_STEPS.md: "✅ FIXED - Updated swap logic in drop_data()"
5. Provide testing instructions
6. Ask: "Please test right-click drag 2 items from stack of 7, drop on slot with different item type. Items should swap, not destroy. Is this fixed?"

**User:** "Fixed!"

**AI Response:**
1. Mark bug as ✅ FIXED in NEXT_STEPS.md
2. Ask: "Great! Next priority is [next bug]. Should I start on that?"

## Anti-Patterns to Avoid

❌ **Don't:** Work on multiple bugs at once  
❌ **Don't:** Move to next bug without confirmation  
❌ **Don't:** Write long explanations unless asked  
❌ **Don't:** Skip updating NEXT_STEPS.md  
❌ **Don't:** Assume a bug is fixed without confirmation  
❌ **Don't:** Reorganize priorities without considering dependencies  

✅ **Do:** One bug at a time  
✅ **Do:** Always confirm before moving on  
✅ **Do:** Keep responses concise  
✅ **Do:** Update NEXT_STEPS.md immediately  
✅ **Do:** Ask for confirmation after fixes  
✅ **Do:** Prioritize based on dependencies and impact  

