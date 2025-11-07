## Summary
What changed and why.

## Checks
- [ ] No absolute `/root/...` paths in changed files
- [ ] No ternary operators introduced
- [ ] Input via `InputMap` only (no raw keycodes)
- [ ] `_process()` not used for UI polling
- [ ] Signals typed & declared at top; no duplicate `.connect()`
- [ ] Ran `scripts/verify_rules.ps1` locally → PASS

## Verification
- [ ] Game launches; HUD/inventory update via signals
- [ ] No duplicate-connection warnings; Orphan Nodes stable
- [ ] Profiler: no perf regression vs baseline
