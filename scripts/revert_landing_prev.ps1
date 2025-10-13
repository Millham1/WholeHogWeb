# revert_landing_prev.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = 'C:\Users\millh_y3006x1\Desktop\WholeHogWeb'
$landing = Join-Path $root 'landing.html'

if (!(Test-Path $landing)) { throw "landing.html not found at $landing" }

# Find backups we created like: landing.html.20251009_153012.bak
$backups = Get-ChildItem -Path $root -File |
  Where-Object { $_.Name -like 'landing.html.*.bak' } |
  Sort-Object LastWriteTime -Descending

if ($backups.Count -lt 1) { throw "No landing.html backups found in $root." }
if ($backups.Count -lt 2) { Write-Warning "Only one backup found. Reverting to the only backup."; }

# Choose the next-to-last if available, otherwise the only one
$chosen = if ($backups.Count -ge 2) { $backups[1] } else { $backups[0] }

# Safety backup of current file before revert
$nowBak = "$landing.$((Get-Date).ToString('yyyyMMdd_HHmmss')).pre-revert.bak"
Copy-Item -LiteralPath $landing -Destination $nowBak -Force

# Restore
Copy-Item -LiteralPath $chosen.FullName -Destination $landing -Force

Write-Host "✅ Reverted landing.html to backup: $($chosen.Name)" -ForegroundColor Green
Write-Host "ℹ️ Current version saved as: $([IO.Path]::GetFileName($nowBak))" -ForegroundColor Yellow
Start-Process $landing
