# fix_landing_button_placement.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Read the file
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# If we've already wrapped a nav once, just ensure Leaderboard exists and add centering if missing
if ($html -match 'id="wholehog-nav"') {
  # Ensure leaderboard link exists inside the wrapper
  if ($html -notmatch 'href\s*=\s*"\./leaderboard\.html"') {
    $leaderClass = "btn"
    if ($html -match '(?is)<div[^>]*id\s*=\s*"wholehog-nav"[^>]*>(.*?)</div>') {
      $inner = $Matches[1]
      # Try to reuse a class from the Blind Taste button if present
      if ($inner -match '(?is)<a[^>]*>\s*Go\s*to\s*Blind\s*Taste\s*</a>') {
        if ($Matches[0] -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }
      }
      $leaderAnchor = "<a href=""./leaderboard.html"" class=""$leaderClass"">Go to Leaderboard</a>"
      # Insert Leaderboard right after Blind Taste
      $inner2 = [regex]::Replace($inner,'(?is)(</a>\s*)(?=(?:[^<]|<(?!/a>))*Go\s*to\s*Leaderboard)','${1}',1) # no-op if already there
      if ($inner2 -eq $inner) {
        $inner2 = [regex]::Replace($inner,'(?is)(</a>\s*)(?=(?:[^<]|<(?!/a>))*Go\s*to\s*Blind\s*Taste\s*</a>)','${1}',1) # ensure proper anchor detection
        $inner2 = [regex]::Replace($inner2,'(?is)(<a[^>]*>\s*Go\s*to\s*Blind\s*Taste\s*</a>)',"`$1 $leaderAnchor",1)
      }
      $html = $html -replace '(?is)(<div[^>]*id\s*=\s*"wholehog-nav"[^>]*>).*?(</div>)',"`$1$inner2`$2"
    }
  }
  # Ensure centering styles are present
  if ($html -notmatch '(?is)<div[^>]*id\s*=\s*"wholehog-nav"[^>]*style=') {
    $html = $html -replace '(?is)<div([^>]*id\s*=\s*"wholehog-nav"[^>]*)>', '<div$1 style="display:flex;justify-content:center;gap:12px;flex-wrap:wrap;">'
  } elseif ($html -notmatch 'justify-content\s*:\s*center') {
    $html = $html -replace '(?is)(<div[^>]*id\s*=\s*"wholehog-nav"[^>]*style=")([^"]*)"', '$1$2;justify-content:center;gap:12px;flex-wrap:wrap"'
  }
} else {
  # Fresh placement: find the two existing anchors and rebuild that small region
  $rxOn  = [regex]::new('(?is)<a\b[^>]*>\s*Go\s*to\s*On\s*-\s*Site\s*</a>|<a\b[^>]*>\s*Go\s*to\s*On\s*Site\s*</a>')
  $rxBt  = [regex]::new('(?is)<a\b[^>]*>\s*Go\s*to\s*Blind\s*Taste\s*</a>')

  $mOn   = $rxOn.Match($html)
  $mBt   = $rxBt.Match($html)

  if (-not $mBt.Success) { throw "Could not find the ""Go to Blind Taste"" link in landing.html." }

  # Gather class for visual consistency (prefer Blind Taste button's class)
  $leaderClass = "btn"
  if ($mBt.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }
  elseif ($mOn.Success -and $mOn.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }

  $leaderAnchor = "<a href=""./leaderboard.html"" class=""$leaderClass"">Go to Leaderboard</a>"

  # Determine region to replace: span from the first of the two anchors to the end of the second
  if ($mOn.Success) {
    $start = [Math]::Min($mOn.Index, $mBt.Index)
    $end   = [Math]::Max($mOn.Index + $mOn.Length, $mBt.Index + $mBt.Length)
    $before = $html.Substring(0, $start)
    $mid    = $html.Substring($start, $end - $start)
    $after  = $html.Substring($end)

    # Order anchors as: On-Site, Blind Taste, Leaderboard
    $anchors = @()
    if ($mOn.Index -le $mBt.Index) { $anchors += $mOn.Value; $anchors += $mBt.Value }
    else { $anchors += $mBt.Value; $anchors += $mOn.Value } # preserve if reversed

    $newBlock = "<div id=""wholehog-nav"" style=""display:flex;justify-content:center;gap:12px;flex-wrap:wrap;"">" + ($anchors -join " ") + " " + $leaderAnchor + "</div>"

    $html = $before + $newBlock + $after
  } else {
    # Only Blind Taste found — insert Leaderboard right after it and wrap both
    $start = $mBt.Index
    $end   = $mBt.Index + $mBt.Length
    $before = $html.Substring(0, $start)
    $mid    = $mBt.Value
    $after  = $html.Substring($end)

    $newBlock = "<div id=""wholehog-nav"" style=""display:flex;justify-content:center;gap:12px;flex-wrap:wrap;"">" + $mid + " " + $leaderAnchor + "</div>"
    $html = $before + $newBlock + $after
  }
}

# Backup + write
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "Updated landing.html (backup: $([IO.Path]::GetFileName($bak)))" -ForegroundColor Green
