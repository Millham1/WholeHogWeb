# final_fix_button_row.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Read landing
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# If there's already a WHOLEHOG wrapper, just ensure Leaderboard is present and centered
if ($html -match '(?is)<div[^>]*id\s*=\s*"wholehog-nav"[^>]*>') {
  # Add Leaderboard after Blind Taste if missing
  if ($html -notmatch '(?is)href\s*=\s*"\./leaderboard\.html"') {
    # Detect the Blind Taste anchor's class to reuse
    $leaderClass = "btn"
    $btMatch = [regex]::Match($html,'(?is)<a\b[^>]*>\s*Go\s*to\s*Blind\s*Taste\s*</a>')
    if ($btMatch.Success -and $btMatch.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }
    elseif ($html -match '(?is)<a\b[^>]*>\s*Go\s*to\s*On\s*-?\s*Site\s*</a>' -and $Matches[0] -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }

    $leaderA = "<a href=""./leaderboard.html"" class=""$leaderClass"">Go to Leaderboard</a>"
    # Insert right after the Blind Taste anchor inside the wrapper
    $html = [regex]::Replace($html,
      '(?is)(<div[^>]*id\s*=\s*"wholehog-nav"[^>]*>.*?<a\b[^>]*>\s*Go\s*to\s*Blind\s*Taste\s*</a>\s*)(?=)',
      "`${1}$leaderA ",
      1
    )
  }

  # Ensure the wrapper has centering styles
  if ($html -notmatch '(?is)<div[^>]*id\s*=\s*"wholehog-nav"[^>]*style=') {
    $html = [regex]::Replace($html,'(?is)<div([^>]*id\s*=\s*"wholehog-nav"[^>]*)>','<div$1 style="display:flex;justify-content:center;gap:12px;flex-wrap:wrap;">',1)
  } elseif ($html -notmatch '(?is)justify-content\s*:\s*center') {
    $html = [regex]::Replace($html,'(?is)(<div[^>]*id\s*=\s*"wholehog-nav"[^>]*style=")([^"]*)"', '$1$2;justify-content:center;gap:12px;flex-wrap:wrap"',1)
  }

} else {
  # Fresh placement:
  # Capture the full <a>...</a> for "On-Site" (hyphen optional) and "Blind Taste"
  $rxOn  = [regex]::new('(?is)<a\b[^>]*>[^<]*Go\s*to\s*On\s*-?\s*Site[^<]*</a>')
  $rxBt  = [regex]::new('(?is)<a\b[^>]*>[^<]*Go\s*to\s*Blind\s*Taste[^<]*</a>')

  $mOn = $rxOn.Match($html)
  $mBt = $rxBt.Match($html)

  if (-not $mBt.Success) { throw 'Could not find the "Go to Blind Taste" link in landing.html.' }

  # Reuse classes from Blind Taste (or On-Site) for visual consistency
  $leaderClass = "btn"
  if ($mBt.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }
  elseif ($mOn.Success -and $mOn.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }

  $leaderA = "<a href=""./leaderboard.html"" class=""$leaderClass"">Go to Leaderboard</a>"

  # Determine replacement region: from earliest of (On-Site, Blind) to latest of them
  $start = $mBt.Index
  $end   = $mBt.Index + $mBt.Length
  if ($mOn.Success) {
    $start = [Math]::Min($mOn.Index, $start)
    $end   = [Math]::Max($mOn.Index + $mOn.Length, $end)
  }

  $before = $html.Substring(0, $start)
  $mid    = $html.Substring($start, $end - $start)
  $after  = $html.Substring($end)

  # Ensure order: On-Site, Blind Taste, Leaderboard
  $anchors = @()
  if ($mOn.Success -and $mOn.Index -le $mBt.Index) { $anchors += $mOn.Value; $anchors += $mBt.Value }
  elseif ($mOn.Success) { $anchors += $mBt.Value; $anchors += $mOn.Value }
  else { $anchors += $mBt.Value } # only Blind found
  $newBlock = '<div id="wholehog-nav" style="display:flex;justify-content:center;gap:12px;flex-wrap:wrap;">' + ($anchors -join ' ') + ' ' + $leaderA + '</div>'

  $html = $before + $newBlock + $after
}

# Backup + write
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "Updated landing.html (backup: $([IO.Path]::GetFileName($bak)))" -ForegroundColor Green
