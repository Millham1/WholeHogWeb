param(
  [string]$Root = ".",
  [string]$OnsiteFile = "onsite.html"
)

$ErrorActionPreference = "Stop"

$rootPath = Resolve-Path $Root
$sitePath = Join-Path $rootPath $OnsiteFile
if (!(Test-Path $sitePath)) { Write-Error "On-site page not found: $sitePath"; exit 1 }

# Read file
$html = Get-Content -Path $sitePath -Raw

# Helpers
function Find-CI([string]$hay, [string]$needle, [int]$start = 0) {
  [System.Globalization.CultureInfo]::InvariantCulture.CompareInfo.IndexOf(
    $hay, $needle, $start, [System.Globalization.CompareOptions]::IgnoreCase
  )
}

# 1) Remove ANY existing top-go-buttons containers and any stray duplicate buttons by id
$low = $html.ToLowerInvariant()

# Remove all containers whose id contains "top-go-buttons"
while ($true) {
  $idIx = Find-CI $low 'id="top-go-buttons'
  if ($idIx -lt 0) { break }
  $divStart = $low.LastIndexOf('<div', $idIx)
  if ($divStart -lt 0) { break }
  $divEnd   = Find-CI $low '</div>' $divStart
  if ($divEnd -lt 0) { break }
  $endPos   = $divEnd + 6
  $html = $html.Remove($divStart, $endPos - $divStart)
  $low  = $html.ToLowerInvariant()
}

# Remove any stray duplicate buttons anywhere (ids we manage)
$btnIds = @('go-landing-top','go-leaderboard-top','go-blind-top')
foreach ($bid in $btnIds) {
  $needle = 'id="' + $bid + '"'
  $low = $html.ToLowerInvariant()
  while ($true) {
    $ix = Find-CI $low $needle
    if ($ix -lt 0) { break }
    $open = $low.LastIndexOf('<button', $ix)
    if ($open -lt 0) { break }
    $close = Find-CI $low '</button>' $ix
    if ($close -lt 0) { break }
    $html = $html.Remove($open, ($close - $open) + 9)
    $low  = $html.ToLowerInvariant()
  }
}

# 2) Build the canonical bar
$bar = @"
<div id="top-go-buttons" class="container" style="display:flex;gap:10px;align-items:center;justify-content:flex-start;margin-top:10px;margin-bottom:0;">
  <button type="button" class="btn btn-ghost" id="go-landing-top" onclick="location.href='landing.html'">Go to Landing</button>
  <button type="button" class="btn btn-ghost" id="go-leaderboard-top" onclick="location.href='leaderboard.html'">Go to Leaderboard</button>
  <button type="button" class="btn btn-ghost" id="go-blind-top" onclick="location.href='blind.html'">Go to Blind Taste</button>
</div>
"@

# 3) Insert the bar right under </header>, or after <body> if no header, else prepend
$low = $html.ToLowerInvariant()
$hdrIx = $low.IndexOf('</header>')
if ($hdrIx -ge 0) {
  $insertPos = $hdrIx + 9
  $html = $html.Substring(0,$insertPos) + "`r`n" + $bar + $html.Substring($insertPos)
} else {
  $bodyIx = Find-CI $html '<body'
  if ($bodyIx -ge 0) {
    $gtIx = $html.IndexOf('>', $bodyIx)
    if ($gtIx -ge 0) {
      $pos = $gtIx + 1
      $html = $html.Substring(0,$pos) + "`r`n" + $bar + $html.Substring($pos)
    } else {
      $html = $bar + "`r`n" + $html
    }
  } else {
    $html = $bar + "`r`n" + $html
  }
}

# 4) Backup and write
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $sitePath (Join-Path $rootPath ("onsite.backup-" + $stamp + ".html")) -Force
$html | Set-Content -Path $sitePath -Encoding UTF8

Write-Host "✅ Reset top button bar: kept a single set (Landing, Leaderboard, Blind) below the header in ${OnsiteFile}."
Write-Host ("Open: file:///" + ((Resolve-Path $sitePath).Path -replace '\\','/'))
