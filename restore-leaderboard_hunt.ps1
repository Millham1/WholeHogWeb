# restore-leaderboard_hunt.ps1
$targetName = 'leaderboard.html'
$here = (Get-Location).Path

Write-Host "Searching for backups under: $here" -ForegroundColor Cyan

# Find backups matching common patterns
$backups = @()
$backups += Get-ChildItem -Path $here -Recurse -File -Filter "$targetName.bak_*" -ErrorAction SilentlyContinue
$backups += Get-ChildItem -Path $here -Recurse -File -Filter "*.bak" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'leaderboard' }

if (-not $backups -or $backups.Count -eq 0) {
  Write-Error "No backups found matching '$targetName.bak_*' or '*.bak' containing 'leaderboard' anywhere under $here."
  Write-Host "If you used a different backup suffix, tell me and I’ll adjust the finder. You can also check:" -ForegroundColor Yellow
  Write-Host " - Windows: Right-click the folder > Properties > 'Previous Versions' (if File History/Restore Points enabled)."
  Write-Host " - Your editor's local history (VS Code: View > Command Palette > 'Local History:...' or extensions)."
  exit 1
}

# Pick newest by LastWriteTime
$latest = $backups | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host ("Found backup: {0} (modified {1})" -f $latest.FullName, $latest.LastWriteTime) -ForegroundColor Green

$targetPath = Join-Path $here $targetName

# Save current broken file, if it exists
if (Test-Path -LiteralPath $targetPath) {
  $stamp = Get-Date -Format yyyyMMdd-HHmmss
  $damaged = "$targetPath.damaged_$stamp"
  Copy-Item -LiteralPath $targetPath -Destination $damaged -Force
  Write-Host "Saved current file as: $damaged" -ForegroundColor Yellow
}

# Restore backup to target
Copy-Item -LiteralPath $latest.FullName -Destination $targetPath -Force
Write-Host "✅ Restored $targetName from: $($latest.FullName)" -ForegroundColor Green
