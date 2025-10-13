param(
  [string]$Root = ".",
  [string]$OnsiteFile = "onsite.html"
)

$ErrorActionPreference = "Stop"

# Resolve paths
$rootPath = Resolve-Path $Root
$sitePath = Join-Path $rootPath $OnsiteFile
if (!(Test-Path $sitePath)) { Write-Error "On-site page not found: $sitePath"; exit 1 }

# Find the newest onsite.backup-*.html to restore from
$backup = Get-ChildItem -Path $rootPath -Filter "onsite.backup-*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $backup) {
  Write-Error "No backup files found (onsite.backup-*.html). Cannot restore."
  exit 1
}

Write-Host "Restoring from: $($backup.FullName)"

# Safety snapshot of current onsite.html
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$safety = Join-Path $rootPath ("onsite.pre-restore-" + $stamp + ".html")
Copy-Item $sitePath $safety -Force

# Restore from backup
Copy-Item $backup.FullName $sitePath -Force

# Load restored content
$html = Get-Content -Path $sitePath -Raw
$low  = $html.ToLowerInvariant()

# Helper: case-insensitive index search
function Find-CI([string]$hay, [string]$needle, [int]$start = 0) {
  return [System.Globalization.CultureInfo]::InvariantCulture.CompareInfo.IndexOf(
    $hay, $needle, $start, [System.Globalization.CompareOptions]::IgnoreCase
  )
}

# 1) Locate the FIRST top-go-buttons container by id
$firstIdIx = Find-CI $low 'id="top-go-buttons"'
if ($firstIdIx -ge 0) {
  # Find opening <div ...> start (walk back to nearest "<div")
  $divStart = $low.LastIndexOf('<div', $firstIdIx)
  if ($divStart -lt 0) { $divStart = $low.LastIndexOf('<section', $firstIdIx) } # rare fallback if header uses <section>
  if ($divStart -lt 0) { Write-Host "⚠️ Could not find container start for top-go-buttons. Will insert a fresh bar under </header>."; $divStart = -1 }

  # Find closing </div> after id (simple forward scan)
  $divEnd = -1
  if ($divStart -ge 0) {
    $divEnd = Find-CI $low '</div>' $divStart
    if ($divEnd -lt 0) { Write-Host "⚠️ Could not find container end; will insert new bar."; $divStart = -1 }
  }

  if ($divStart -ge 0 -and $divEnd -ge 0) {
    # Preserve the opening tag exactly; replace INNER with canonical 3 buttons
    $openTagEnd = $html.IndexOf('>', $divStart)
    if ($openTagEnd -lt 0 -or $openTagEnd > $divEnd) {
      Write-Host "⚠️ Container tag malformed; will insert new bar."
    } else {
      $openTag   = $html.Substring($divStart, $openTagEnd - $divStart + 1) # includes '>'
      $closeTag  = $html.Substring($divEnd, 6) # '</div>'
      $innerStart = $openTagEnd + 1
      $innerEnd   = $divEnd

      # Canonical inner buttons (exactly 3, in order)
      $inner = @'
  <button type="button" class="btn btn-ghost" id="go-landing-top" onclick="location.href='landing.html'">Go to Landing</button>
  <button type="button" class="btn btn-ghost" id="go-leaderboard-top" onclick="location.href='leaderboard.html'">Go to Leaderboard</button>
  <button type="button" class="btn btn-ghost" id="go-blind-top" onclick="location.href='blind.html'">Go to Blind Taste</button>
'@

      # Replace inner only
      $html = $html.Substring(0, $innerStart) + "`r`n" + $inner + "`r`n" + $html.Substring($innerEnd)
      $low  = $html.ToLowerInvariant()

      Write-Host "✅ Rebuilt buttons INSIDE existing top-go-buttons container."
    }
  }
} else {
  Write-Host "ℹ️ No top-go-buttons container found in restored file."
}

# 2) Remove ANY additional top-go-buttons containers beyond the first
$low = $html.ToLowerInvariant()
$firstAfter = Find-CI $low 'id="top-go-buttons"'
if ($firstAfter -ge 0) {
  # Get bounds of the first container
  $firstDivStart = $low.LastIndexOf('<div', $firstAfter)
  if ($firstDivStart -ge 0) {
    $firstDivEnd = Find-CI $low '</div>' $firstDivStart
    if ($firstDivEnd -ge 0) {
      $keepTo = $firstDivEnd + 6
      # Now remove any further occurrences
      $searchFrom = $keepTo
      while ($true) {
        $nextId = Find-CI $low 'id="top-go-buttons"' $searchFrom
        if ($nextId -lt 0) { break }
        $divStart2 = $low.LastIndexOf('<div', $nextId)
        if ($divStart2 -lt 0) { break }
        $divEnd2 = Find-CI $low '</div>' $divStart2
        if ($divEnd2 -lt 0) { break }
        $endPos2 = $divEnd2 + 6
        $html = $html.Remove($divStart2, $endPos2 - $divStart2)
        $low  = $html.ToLowerInvariant()
        $searchFrom = $divStart2 # continue after removal
        Write-Host "• Removed extra top-go-buttons container."
      }
    }
  }
}

# 3) If there was no container, insert a clean bar right under </header> (do NOT touch other content)
if (Find-CI $low 'id="top-go-buttons"' -lt 0) {
  $bar = @'
<div id="top-go-buttons" class="container" style="display:flex;gap:10px;align-items:center;justify-content:flex-start;margin-top:10px;margin-bottom:0;">
  <button type="button" class="btn btn-ghost" id="go-landing-top" onclick="location.href='landing.html'">Go to Landing</button>
  <button type="button" class="btn btn-ghost" id="go-leaderboard-top" onclick="location.href='leaderboard.html'">Go to Leaderboard</button>
  <button type="button" class="btn btn-ghost" id="go-blind-top" onclick="location.href='blind.html'">Go to Blind Taste</button>
</div>
'@

  $hdrIx = $low.IndexOf('</header>')
  if ($hdrIx -ge 0) {
    $insertPos = $hdrIx + 9
    $html = $html.Substring(0,$insertPos) + "`r`n" + $bar + "`r`n" + $html.Substring($insertPos)
    Write-Host "✅ Inserted a new top-go-buttons bar under </header>."
  } else {
    # as a minimal fallback, insert after <body>
    $bodyIx = Find-CI $html '<body'
    if ($bodyIx -ge 0) {
      $gtIx = $html.IndexOf('>', $bodyIx)
      if ($gtIx -ge 0) {
        $pos = $gtIx + 1
        $html = $html.Substring(0,$pos) + "`r`n" + $bar + "`r`n" + $html.Substring($pos)
        Write-Host "✅ Inserted a new top-go-buttons bar after <body>."
      }
    }
  }
}

# 4) Write back
$html | Set-Content -Path $sitePath -Encoding UTF8

Write-Host "✅ Restored page and fixed buttons."
Write-Host "• Safety snapshot saved to: $safety"
Write-Host ("• Final page: file:///" + ((Resolve-Path $sitePath).Path -replace '\\','/'))
