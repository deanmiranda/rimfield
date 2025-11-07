# Run from project root (folder with project.godot)
$errors = @()

Write-Host "=== Rule checks ==="

# 1) Absolute /root/ paths
$rootHits = Select-String -Path .\**\*.gd -Pattern '/root/' -CaseSensitive -ErrorAction SilentlyContinue
if ($rootHits) { $errors += "Absolute /root/ paths found."; $rootHits | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no /root/ lookups" }

# 2) Ternary operators
$ternary = Select-String -Path .\**\*.gd -Pattern '\? *:' -ErrorAction SilentlyContinue
if ($ternary) { $errors += "Ternary operators found."; $ternary | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no ternaries" }

# 3) Keycodes (should use InputMap actions instead)
$keycodes = Select-String -Path .\**\*.gd -Pattern 'KEY_|MOUSE_BUTTON_|JOY_' -ErrorAction SilentlyContinue
if ($keycodes) { $errors += "Keycodes found (use InputMap)."; $keycodes | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no raw keycodes" }

# 4) get_node() calls (just to review hot paths)
$getnodes = Select-String -Path .\**\*.gd -Pattern 'get_node\(' -ErrorAction SilentlyContinue
if ($getnodes) { Write-Host "Review: get_node() occurrences (cache hot ones w/ @onready)"; $getnodes | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no get_node() found" }

# 5) _process() (ensure it’s minimal)
$processes = Select-String -Path .\**\*.gd -Pattern '_process\s*\(' -ErrorAction SilentlyContinue
if ($processes) { Write-Host "Review: _process() occurrences (avoid heavy work)"; $processes | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no _process() found" }

# 6) Common “magic numbers” to move to Resource
$magic = Select-String -Path .\**\*.gd -Pattern '\b(10|12|24|30|60)\b' -ErrorAction SilentlyContinue
if ($magic) { Write-Host "Review: potential magic numbers"; $magic | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no obvious magic numbers" }

Write-Host "`n=== Summary ==="
if ($errors.Count -eq 0) { Write-Host "PASS: No rule violations found." } else {
  Write-Host "FAIL: $($errors.Count) issues:"; $errors | ForEach-Object { Write-Host " - $_" }
}
