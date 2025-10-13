param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

$dir  = Split-Path -LiteralPath $Path -Parent
$base = Split-Path -LiteralPath $Path -Leaf

# gather likely backups alongside the file
$files = @()
$files += Get-ChildItem -LiteralPath $dir -File -Filter "$($base).bak*"
$files += Get-ChildItem -LiteralPath $dir -File -Filter "*.bak"        | Where-Object { $_.Name -match 'leaderboard' }
$files += Get-ChildItem -LiteralPath $dir -File -Filter "leaderboard*.html*"

# remove the live file and de-dup
$files = $files | Where-Object { $_.Name -ne $base } | Sort-Object FullName -Unique

if (-not $files -or $files.Count -eq 0) {
  Write-Error "No backups of leaderboard found in: $dir"
  exit 1
}

# choose by last write time (second most recent if available)
$candidates = $files | Sort-Object LastWriteTime -Descending
$choice = if ($candidates.Count -ge 2) { $candidates[1] } else { $candidates[0] }

# show what we’re restoring
Write-Host "Restoring from backup:" -ForegroundColor Cyan
$candidates | Select-Object Name, LastWriteTime | Format-Table

# backup current file first (so we can undo)
$pre = "$Path.pre-restore.bak"
Copy-Item -LiteralPath $Path -Destination $pre -Force

# restore
Copy-Item -LiteralPath $choice.FullName -Destination $Path -Force

Write-Host ""
Write-Host "✅ Restored '$base' from '$($choice.Name)'." -ForegroundColor Green
Write-Host "A backup of the current file was saved as '$pre'."
