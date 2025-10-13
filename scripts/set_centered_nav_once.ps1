# set_centered_nav_once.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# Read
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# 1) Detect your existing button class from current buttons (prefer Blind Taste, then On-Site)
$btnClass = "btn"
$rxBlind = '(?is)<a\b[^>]*class\s*=\s*"([^"]+)"[^>]*>[^<]*Go\s*to\s*Blind\s*-?\s*Taste[^<]*</a>'
$rxOn    = '(?is)<a\b[^>]*class\s*=\s*"([^"]+)"[^>]*>[^<]*Go\s*to\s*On\s*-?\s*Site[^<]*</a>'

$m = [regex]::Match($html, $rxBlind)
if ($m.Success) { $btnClass = $m.Groups[1].Value }
else {
  $m2 = [regex]::Match($html, $rxOn)
  if ($m2.Success) { $btnClass = $m2.Groups[1].Value }
}

# 2) Remove any existing nav block with the same id to avoid duplicates
$html = [regex]::Replace($html, '(?is)<div[^>]*\bid\s*=\s*"wholehog-nav"[^>]*>.*?</div>', '')

# 3) Build a single centered row (inline styles prevent right-floating/stacking); correct On-Site href
$anchorStyle = 'style="display:inline-block;white-space:nowrap;width:auto;float:none"'
$navRow =
  '<div id="wholehog-nav" ' +
  'style="width:100%;margin:12px auto;display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">' +
    '<a href="./onsite.html" class="' + $btnClass + '" ' + $anchorStyle + '>Go to On-Site</a> ' +
    '<a href="./blind-taste.html" class="' + $btnClass + '" ' + $anchorStyle + '>Go to Blind Taste</a> ' +
    '<a href="./leaderboard.html" class="' + $btnClass + '" ' + $anchorStyle + '>Go to Leaderboard</a>' +
  '</div>'

# 4) Insert the row immediately after </header>, else after <body>, else prepend
$inserted = $false
$mh = [regex]::Match($html, '(?is)</header\s*>')
if ($mh.Success) {
  $i = $mh.Index + $mh.Length
  $html = $html.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $html.Substring($i)
  $inserted = $true
} else {
  $mb = [regex]::Match($html, '(?is)<body\b[^>]*>')
  if ($mb.Success) {
    $i = $mb.Index + $mb.Length
    $html = $html.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $html.Substring($i)
    $inserted = $true
  }
}
if (-not $inserted) {
  $html = $navRow + "`r`n" + $html
}

# 5) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Centered nav set under header and On-Site link corrected. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
