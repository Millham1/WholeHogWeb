# revert_landing_start_of_day.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$landing = Join-Path $root "landing.html"
if (!(Test-Path $landing)) { throw "landing.html not found at $landing" }

# Gather backups like: landing.html.20251009_153012.bak
$allBackups = Get-ChildItem -Path $root -File -Filter "landing.html.*.bak" |
  Where-Object { $_.Name -match '^landing\.html\.\d{8}_\d{6}\.bak$' }

if (-not $allBackups) { throw "No landing.html backups found in $root." }

# Pick earliest from today; else earliest overall
$today = (Get-Date).ToString('yyyyMMdd')
$todayBackups = $allBackups | Where-Object { $_.Name -like "landing.html.$today*_*.bak" -or $_.Name -like "landing.html.$today*.bak" }

function Get-Stamp([string]$name) {
  if ($name -match '^landing\.html\.(\d{8})_(\d{6})\.bak$') {
    return [datetime]::ParseExact("$($Matches[1])$($Matches[2])","yyyyMMddHHmmss",$null)
  } else {
    return (Get-Item $name).LastWriteTime
  }
}

$pickFrom = if ($todayBackups) { $todayBackups } else { $allBackups }
$chosen = $pickFrom | Sort-Object @{Expression={ Get-Stamp $_.Name }} | Select-Object -First 1

# Safety snapshot of current file
$nowBak = "$landing.$((Get-Date).ToString('yyyyMMdd_HHmmss')).pre-revert.bak"
Copy-Item -LiteralPath $landing -Destination $nowBak -Force

# Restore
Copy-Item -LiteralPath $chosen.FullName -Destination $landing -Force

Write-Host "✅ Reverted landing.html to: $($chosen.Name)" -ForegroundColor Green
Write-Host "ℹ️ Current (pre-revert) saved as: $([IO.Path]::GetFileName($nowBak))" -ForegroundColor Yellow
Start-Process $landing
