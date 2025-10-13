param(
  [string]$Root = ".",
  [string]$OnsiteFile = "onsite.html"  # change if your file is named differently
)

$ErrorActionPreference = "Stop"

$rootPath = Resolve-Path $Root
$sitePath = Join-Path $rootPath $OnsiteFile
if (!(Test-Path $sitePath)) { Write-Error "On-site page not found: $sitePath"; exit 1 }

# Read file
$html = Get-Content -Path $sitePath -Raw

function Find-CI([string]$hay, [string]$needle, [int]$start = 0) {
  return [System.Globalization.CultureInfo]::InvariantCulture.CompareInfo.IndexOf($hay, $needle, $start, [System.Globalization.CompareOptions]::IgnoreCase)
}

# 1) Remove any old standalone "top-go-blind" wrapper block
$low = $html.ToLowerInvariant()
$idx = 0
while ($true) {
  $divStart = Find-CI $low '<div' $idx
  if ($divStart -lt 0) { break }
  $divEnd = Find-CI $low '</div>' $divStart
  if ($divEnd -lt 0) { break }
  $chunk = $low.Substring($divStart, ($divEnd - $divStart) + 6)
  if ($chunk.Contains('id="top-go-blind"')) {
    $html = $html.Remove($divStart, ($divEnd - $divStart) + 6)
    $low  = $html.ToLowerInvariant()
    $idx  = 0
  } else {
    $idx = $divStart + 1
  }
}

# Blind button HTML (PowerShell-escaped quotes)
$blindBtn = '<button type="button" class="btn btn-ghost" id="go-blind-top" onclick="location.href=''blind.html''">Go to Blind Taste</button>'

# 2) Find a shared top buttons container (id starts with "top-go-buttons")
$low = $html.ToLowerInvariant()
$containerStart = -1
$containerEnd   = -1
$scan = 0
while ($true) {
  $divStart = Find-CI $low '<div' $scan
  if ($divStart -lt 0) { break }
  $divEnd = Find-CI $low '</div>' $divStart
  if ($divEnd -lt 0) { break }
  $chunk = $low.Substring($divStart, ($divEnd - $divStart) + 6)
  if ($chunk.Contains('id="top-go-buttons')) {
    $containerStart = $divStart
    $containerEnd   = $divEnd + 6
    break
  }
  $scan = $divStart + 1
}

if ($containerStart -ge 0) {
  # Update existing bar
  $block    = $html.Substring($containerStart, $containerEnd - $containerStart)
  $blockLow = $block.ToLowerInvariant()

  # Remove any existing Blind button inside this bar (avoid duplicates)
  $blindIx = Find-CI $blockLow 'id="go-blind-top"'
  if ($blindIx -ge 0) {
    $openIx  = $blockLow.LastIndexOf('<button', $blindIx)
    $closeIx = Find-CI $blockLow '</button>' $blindIx
    if ($openIx -ge 0 -and $closeIx -ge 0) {
      $block    = $block.Remove($openIx, ($closeIx - $openIx) + 9)
      $blockLow = $block.ToLowerInvariant()
    }
  }

  # Place Blind immediately after Leaderboard button if present; else append
  $lbIx = Find-CI $blockLow 'id="go-leaderboard-top"'
  if ($lbIx -ge 0) {
    $endLb = Find-CI $blockLow '</button>' $lbIx
    if ($endLb -ge 0) {
      $insertPos = $endLb + 9
      $block = $block.Insert($insertPos, "`r`n  $blindBtn")
    } else {
      $block = $block.TrimEnd() + "`r`n  $blindBtn`r`n"
    }
  } else {
    $block = $block.TrimEnd() + "`r`n  $blindBtn`r`n"
  }

  # Write back
  $html = $html.Remove($containerStart, $containerEnd - $containerStart).Insert($containerStart, $block)
}
else {
  # Create the shared bar under </header>
  $newBar = @"
<div id="top-go-buttons" class="container" style="display:flex;gap:10px;align-items:center;justify-content:flex-start;margin-top:10px;margin-bottom:0;">
  <button type="button" class="btn btn-ghost" id="go-landing-top" onclick="location.href='landing.html'">Go to Landing</button>
  <button type="button" class="btn btn-ghost" id="go-leaderboard-top" onclick="location.href='leaderboard.html'">Go to Leaderboard</button>
  $blindBtn
</div>
"@
  $low = $html.ToLowerInvariant()
  $hdrIx = $low.IndexOf('</header>')
  if ($hdrIx -ge 0) {
    $insertPos = $hdrIx + 9
    $html = $html.Substring(0,$insertPos) + "`r`n" + $newBar + $html.Substring($insertPos)
  } else {
    # Fallback: after <body>, else prepend
    $bodyIx = Find-CI $html '<body'
    if ($bodyIx -ge 0) {
      $gtIx = $html.IndexOf('>', $bodyIx)
      if ($gtIx -ge 0) {
        $pos = $gtIx + 1
        $html = $html.Substring(0,$pos) + "`r`n" + $newBar + $html.Substring($pos)
      } else {
        $html = $newBar + "`r`n" + $html
      }
    } else {
      $html = $newBar + "`r`n" + $html
    }
  }
}

# Backup and write
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $sitePath (Join-Path $rootPath ("onsite.backup-" + $stamp + ".html")) -Force
$html | Set-Content -Path $sitePath -Encoding UTF8

Write-Host "✅ Aligned 'Go to Blind Taste' button to the right of 'Go to Leaderboard' in ${OnsiteFile}."
Write-Host ("Open: file:///" + ((Resolve-Path $sitePath).Path -replace '\\','/'))

