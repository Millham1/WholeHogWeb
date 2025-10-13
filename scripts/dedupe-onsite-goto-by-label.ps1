param(
  [string]$Root = ".",
  [string]$OnsiteFile = "onsite.html"
)

$ErrorActionPreference = "Stop"

function Find-CI([string]$hay, [string]$needle, [int]$start = 0) {
  [System.Globalization.CultureInfo]::InvariantCulture.CompareInfo.IndexOf(
    $hay, $needle, $start, [System.Globalization.CompareOptions]::IgnoreCase
  )
}

$rootPath = Resolve-Path $Root
$sitePath = Join-Path $rootPath $OnsiteFile
if (!(Test-Path $sitePath)) { Write-Error "On-site page not found: $sitePath"; exit 1 }

# Load
$html = Get-Content -Path $sitePath -Raw

# Labels we will dedupe (keep first, remove later)
$labels = @('Go to Landing','Go to Leaderboard','Go to Blind Taste')

# Remove duplicates for one label (button or link with same visible text)
function Remove-Duplicates-ForLabel {
  param([string]$html, [string]$label)

  $low = $html.ToLowerInvariant()
  $needle = $label.ToLowerInvariant()

  # find all label positions
  $hits = @()
  $from = 0
  while ($true) {
    $ix = $low.IndexOf($needle, $from)
    if ($ix -lt 0) { break }
    $hits += $ix
    $from = $ix + 1
  }
  if ($hits.Count -le 1) { return $html } # nothing to remove

  # Keep first occurrence; remove the rest
  for ($i = 1; $i -lt $hits.Count; $i++) {
    $ixLabel = $hits[$i]
    $low = $html.ToLowerInvariant()

    # Try enclosing <button>...</button>
    $openBtn = $low.LastIndexOf('<button', $ixLabel)
    $closeBtn = Find-CI $low '</button>' $ixLabel

    $removed = $false
    if ($openBtn -ge 0 -and $closeBtn -ge 0) {
      $html = $html.Remove($openBtn, ($closeBtn - $openBtn) + 9)
      $removed = $true
    } else {
      # Try enclosing <a>...</a>
      $openA = $low.LastIndexOf('<a', $ixLabel)
      $closeA = Find-CI $low '</a>' $ixLabel
      if ($openA -ge 0 -and $closeA -ge 0) {
        $html = $html.Remove($openA, ($closeA - $openA) + 4)
        $removed = $true
      }
    }

    if ($removed) {
      # Recompute the remaining hit positions since string changed.
      $low = $html.ToLowerInvariant()
      $hits = @()
      $from = 0
      while ($true) {
        $ix = $low.IndexOf($needle, $from)
        if ($ix -lt 0) { break }
        $hits += $ix
        $from = $ix + 1
      }
      # After recomputing, continue from current i (which now points to next occurrence)
    } else {
      # Could not confidently remove (should be rare); skip this instance
      continue
    }
  }

  return $html
}

# Backup
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $sitePath (Join-Path $rootPath ("onsite.backup-" + $stamp + ".html")) -Force

# Apply dedupe for each target label
foreach ($label in $labels) {
  $html = Remove-Duplicates-ForLabel -html $html -label $label
}

# Write back
$html | Set-Content -Path $sitePath -Encoding UTF8

Write-Host "✅ Removed duplicate Go-to buttons while keeping the first occurrence of each (Landing, Leaderboard, Blind)."
Write-Host ("Open: file:///" + ((Resolve-Path $sitePath).Path -replace '\\','/'))
