# place_center_leaderboard.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Read file
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# 1) Remove the previous bottom WHOLEHOG Leaderboard block (if any)
$html = [regex]::Replace($html, '(?is)<!--\s*WHOLEHOG:\s*Leaderboard\s*Button\s*-->.*?<!--\s*/WHOLEHOG\s*-->', '')

# 2) Locate existing anchors for On-Site and Blind Taste (keep exact HTML)
$rxOn = [regex]::new('(?is)<a\b[^>]*>.*?Go\s*to\s*On\s*-?\s*Site.*?<\/a>')
$rxBt = [regex]::new('(?is)<a\b[^>]*>.*?Go\s*to\s*Blind\s*Taste.*?<\/a>')

$mOn = $rxOn.Match($html)
$mBt = $rxBt.Match($html)

if (-not $mBt.Success) {
  throw 'Could not find the "Go to Blind Taste" button in landing.html. Tell me its exact text so I can match it.'
}

# 3) Determine classes to reuse for the new Leaderboard button
$leaderClass = "btn"
if ($mBt.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }
elseif ($mOn.Success -and $mOn.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }

$leaderA = "<a href=""./leaderboard.html"" class=""$leaderClass"">Go to Leaderboard</a>"

# 4) Build new centered wrapper with the three buttons (order: On-Site, Blind, Leaderboard)
$anchors = @()
if ($mOn.Success) {
  if ($mOn.Index -le $mBt.Index) { $anchors += $mOn.Value; $anchors += $mBt.Value }
  else { $anchors += $mBt.Value; $anchors += $mOn.Value }
} else {
  $anchors += $mBt.Value
}
$anchors += $leaderA

$wrapper = '<div id="wholehog-nav" style="display:flex;justify-content:center;gap:12px;flex-wrap:wrap;">' + ($anchors -join ' ') + '</div>'

# 5) Replace the region spanning the two existing anchors with the centered wrapper
$start = $mBt.Index
$end   = $mBt.Index + $mBt.Length
if ($mOn.Success) {
  $start = [Math]::Min($start, $mOn.Index)
  $end   = [Math]::Max($end,   $mOn.Index + $mOn.Length)
}

$before = $html.Substring(0, $start)
$after  = $html.Substring($end)
$html2  = $before + $wrapper + $after

# 6) Backup + write
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html2

Write-Host "Updated landing.html with centered three-button row (backup: $([IO.Path]::GetFileName($bak)))" -ForegroundColor Green
