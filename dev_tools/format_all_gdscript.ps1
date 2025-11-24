# Format All GDScript Files
# This script uses gdformat to format all .gd files in the project

Write-Host "Formatting all GDScript files..." -ForegroundColor Cyan

# Check if gdformat is installed
try {
    $version = gdformat --version 2>&1
    Write-Host "Using gdformat: $version" -ForegroundColor Green
} catch {
    Write-Host "ERROR: gdformat is not installed!" -ForegroundColor Red
    Write-Host "Install with: pip install gdtoolkit" -ForegroundColor Yellow
    exit 1
}

# Find and format all .gd files
$gdFiles = Get-ChildItem -Path "scripts" -Recurse -Filter "*.gd"
$totalFiles = $gdFiles.Count
$currentFile = 0

foreach ($file in $gdFiles) {
    $currentFile++
    Write-Progress -Activity "Formatting GDScript Files" -Status "Processing $($file.Name)" -PercentComplete (($currentFile / $totalFiles) * 100)
    
    try {
        gdformat $file.FullName
        Write-Host "[OK] $($file.FullName)" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to format: $($file.FullName)" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nFormatting complete! Processed $totalFiles files." -ForegroundColor Cyan

