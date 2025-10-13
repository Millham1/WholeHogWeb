param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "Target not found: $Path"
  exit 1
}

# Find backups like: leaderboard.html.bak_YYYYMMDD-HHMMSS
$pattern = "$Path.bak_*"
$backups = Get-ChildItem -File -LiteralPath (Split-Path -LiteralPath $Path -Parent) `
           | Where-Object { $_.Name -like "$(Split-Path -Leaf $Path).bak_*" } `
           | Sort-Object LastWriteTime -Descending

if (-not $backups) {
  Write-Error "No backups found matching: $pattern"
  exit 1
}

$latest = $backups[0]
$stamp  = Get-Date -Format yyyyMMdd-HHmmss
$damaged = "$Path.damaged_$stamp"

try {
  # Save the current (broken) file so nothing is lost
  if (Test-Path -LiteralPath $Path) {
    Copy-Item -LiteralPath $Path -Destination $damaged -Force
    Write-Host "Saved current file as: $damaged"
  }

  # Restore from the newest backup
  Copy-Item -LiteralPath $latest.FullName -Destination $Path -Force
  Write-Host "✅ Restored $Path from backup: $($latest.Name)"
} catch {
  Write-Error "Restore failed: $($_.Exception.Message)"
  exit 1
}
