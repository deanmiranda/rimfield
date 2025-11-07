# Run from repo root (same level as project.godot)
$ErrorActionPreference = 'SilentlyContinue'
$violations = @()

Write-Host "=== Rule checks ==="

# 1) Absolute /root/ paths
$rootHits = Select-String -Path .\**\*.gd -Pattern '/root/' -CaseSensitive
if ($rootHits) { $violations += "Absolute /root/ paths found."; $rootHits | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no /root/ lookups" }

# 2) Ternary operators (disallowed)
$ternary = Select-String -Path .\**\*.gd -Pattern '\? *:'
if ($ternary) { $violations += "Ternary operators found."; $ternary | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no ternaries" }

# 3) Raw keycodes (should use InputMap)
$keycodes = Select-String -Path .\**\*.gd -Pattern 'KEY_|MOUSE_BUTTON_|JOY_'
if ($keycodes) { $violations += "Raw keycodes found (use InputMap)."; $keycodes | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no raw keycodes" }

# 4) get_node() review (advice; not a violation by itself)
$getnodes = Select-String -Path .\**\*.gd -Pattern 'get_node\('
if ($getnodes) { Write-Host "Review: get_node() occurrences (cache hot ones w/ @onready)"; $getnodes | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no get_node() found" }

# 5) _process() review (avoid heavy work)
$processes = Select-String -Path .\**\*.gd -Pattern '_process\s*\('
if ($processes) { Write-Host "Review: _process() occurrences (keep minimal)"; $processes | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no _process() found" }

# 6) Common magic numbers to push into Resources (advice)
$magic = Select-String -Path .\**\*.gd -Pattern '\b(10|12|24|30|60)\b'
if ($magic) { Write-Host "Review: potential magic numbers"; $magic | Format-Table Path, LineNumber, Line -AutoSize } else { Write-Host "OK: no obvious magic numbers" }

Write-Host "`n=== Summary ==="
if ($violations.Count -eq 0) {
  Write-Host "PASS: No rule violations found."
  exit 0
} else {
  Write-Host "FAIL: $($violations.Count) violation(s) detected."
  $violations | ForEach-Object { Write-Host " - $_" }
  exit 1
}
