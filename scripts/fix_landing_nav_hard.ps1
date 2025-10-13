# fix_landing_nav_hard.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# --- read file ---
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# --- helper: ensure anchor can sit inline (prevents full-width stacking) ---
function Normalize-Anchor([string]$aHtml){
  $m = [regex]::Match($aHtml,'(?is)^<a\b([^>]*)>')
  if (!$m.Success){ return $aHtml }
  $attrs = $m.Groups[1].Value
  $styleMatch = [regex]::Match($attrs,'(?is)\bstyle\s*=\s*"([^"]*)"')
  if ($styleMatch.Success) {
    $style = $styleMatch.Groups[1].Value
    if ($style -notmatch '(?i)\bdisplay\s*:') { $style += ';display:inline-block' }
    if ($style -notmatch '(?i)\bwidth\s*:')   { $style += ';width:auto' }
    $newAttrs = [regex]::Replace($attrs,'(?is)\bstyle\s*=\s*"[^"]*"', 'style="' + $style + '"', 1)
  } else {
    $newAttrs = $attrs.TrimEnd() + ' style="display:inline-block;width:auto"'
  }
  return '<a' + $newAttrs + '>' + $aHtml.Substring($m.Length)
}

# --- patterns for anchors ---
$rxOn  = [regex]'(?is)<a\b[^>]*>(?:(?!</a>).)*?Go\s*to\s*On\s*-?\s*Site(?:(?!</a>).)*?</a>'
$rxBt  = [regex]'(?is)<a\b[^>]*>(?:(?!</a>).)*?Go\s*to\s*Blind\s*Taste(?:(?!</a>).)*?</a>'
$rxLbH = [regex]'(?is)<a\b[^>]*href\s*=\s*"(?:\./)?leaderboard\.html"[^>]*>.*?</a>'

# --- capture first instances of On-Site and Blind Taste (to reuse their classes/markup) ---
$mOn = $rxOn.Match($html)
$mBt = $rxBt.Match($html)
if (-not $mBt.Success) { throw 'Could not find the "Go to Blind Taste" button in landing.html.' }

# Choose class for Leaderboard to match your buttons
$leaderClass = "btn"
if ($mBt.Value -match 'class\s*=\s*"([^"]+)"')       { $leaderClass = $Matches[1] }
elseif ($mOn.Success -and $mOn.Value -match 'class\s*=\s*"([^"]+)"') { $leaderClass = $Matches[1] }

# Normalize anchors (force inline-block so they align horizontally)
$onA = if ($mOn.Success) { Normalize-Anchor($mOn.Value) } else { $null }
$btA = Normalize-Anchor($mBt.Value)
$lbA = '<a href="./leaderboard.html" class="' + $leaderClass + '" style="display:inline-block;width:auto">Go to Leaderboard</a>'

# --- remove ALL old injected blocks/wrappers/duplicates everywhere ---
$html = [regex]::Replace($html,'(?is)<!--\s*WHOLEHOG:.*?-->(?:(?!<!--\s*/WHOLEHOG\s*-->).)*?<!--\s*/WHOLEHOG\s*-->','')
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>.*?</div>','')
# remove any stray leaderboard anchors anywhere
$html = $rxLbH.Replace($html,'')

# remove ALL occurrences of the original On-Site & Blind Taste anchors (we’ll reinsert one clean row)
$html = $rxOn.Replace($html,'')
$html = $rxBt.Replace($html,'')

# --- build centered row (On-Site, Blind Taste, Leaderboard) ---
$anchors = @()
if ($onA) { $anchors += $onA }
$anchors += $btA
$anchors += $lbA
$row = '<div id="wholehog-nav" style="display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;">' + ($anchors -join ' ') + '</div>'

# --- insert row right below the banner: after </header>, else right after <body> open, else at top of file ---
$inserted = $false
$mh = [regex]::Match($html,'(?is)</header\s*>')
if ($mh.Success) {
  $idx = $mh.Index + $mh.Length
  $html = $html.Substring(0,$idx) + "`r`n" + $row + "`r`n" + $html.Substring($idx)
  $inserted = $true
} else {
  $mb = [regex]::Match($html,'(?is)<body\b[^>]*>')
  if ($mb.Success) {
    $idx = $mb.Index + $mb.Length
    $html = $html.Substring(0,$idx) + "`r`n" + $row + "`r`n" + $html.Substring($idx)
    $inserted = $true
  }
}
if (-not $inserted) { $html = $row + "`r`n" + $html }

# --- backup + write ---
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html

Write-Host "Done: centered one-row nav inserted, duplicates removed. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green


