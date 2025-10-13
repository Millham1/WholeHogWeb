# final_center_buttons.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Read file
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# --- helpers ---
function Get-Class([string]$aHtml){
  if ($aHtml -match 'class\s*=\s*"([^"]+)"') { return $Matches[1] }
  elseif ($aHtml -match "class\s*=\s*'([^']+)'") { return $Matches[1] }
  else { return $null }
}
function Get-Text([string]$aHtml){
  $m = [regex]::Match($aHtml,'>([\s\S]*?)</a>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if ($m.Success) { return ($m.Groups[1].Value).Trim() } else { return $null }
}
function Normalize-Anchor([string]$aHtml){
  # Force inline layout so anchors don’t stack or stretch full width
  $m = [regex]::Match($aHtml,'(?is)^<a\b([^>]*)>')
  if (!$m.Success) { return $aHtml }
  $attrs = $m.Groups[1].Value
  $styleMatch = [regex]::Match($attrs,'(?is)\bstyle\s*=\s*"([^"]*)"')
  if ($styleMatch.Success) {
    $style = $styleMatch.Groups[1].Value
    if ($style -notmatch '(?i)\bdisplay\s*:') { $style += ';display:inline-flex' }
    if ($style -notmatch '(?i)\balign-items\s*:') { $style += ';align-items:center' }
    if ($style -notmatch '(?i)\bfloat\s*:') { $style += ';float:none!important' }
    if ($style -notmatch '(?i)\bwidth\s*:') { $style += ';width:auto!important' }
    if ($style -notmatch '(?i)\bwhite-space\s*:') { $style += ';white-space:nowrap' }
    $newAttrs = [regex]::Replace($attrs,'(?is)\bstyle\s*=\s*"[^"]*"', 'style="' + $style + '"', 1)
  } else {
    $newAttrs = $attrs.TrimEnd() + ' style="display:inline-flex;align-items:center;float:none!important;width:auto!important;white-space:nowrap"'
  }
  return '<a' + $newAttrs + '>' + $aHtml.Substring($m.Length)
}

# --- patterns (by href, robust to ./) ---
$rxOnHref = [regex]'(?is)<a\b[^>]*href\s*=\s*"(?:\./)?on-?site\.html"[^>]*>[\s\S]*?</a>'
$rxBtHref = [regex]'(?is)<a\b[^>]*href\s*=\s*"(?:\./)?blind-?taste\.html"[^>]*>[\s\S]*?</a>'
$rxLbHref = [regex]'(?is)<a\b[^>]*href\s*=\s*"(?:\./)?leaderboard\.html"[^>]*>[\s\S]*?</a>'

# Capture existing anchors (to reuse class/text)
$mOn = $rxOnHref.Match($html)
$mBt = $rxBtHref.Match($html)

if (-not $mBt.Success) { throw 'Could not find a link to "blind-taste.html" in landing.html.' }

$onClass = if ($mOn.Success) { Get-Class $mOn.Value } else { $null }
$btClass = Get-Class $mBt.Value
if (-not $btClass) { $btClass = $onClass }
if (-not $onClass) { $onClass = $btClass }
if (-not $btClass) { $btClass = "btn" }
if (-not $onClass) { $onClass = "btn" }
$lbClass = $btClass

$onText = if ($mOn.Success) { Get-Text $mOn.Value } else { "Go to On-Site" }
$btText = Get-Text $mBt.Value
if (-not $btText) { $btText = "Go to Blind Taste" }

# Build clean, normalized anchors
$onA = if ($mOn.Success) {
  Normalize-Anchor( ('<a href="./on-site.html" class="' + $onClass + '">' + $onText + '</a>') )
} else { $null }

$btA = Normalize-Anchor( '<a href="./blind-taste.html" class="' + $btClass + '">' + $btText + '</a>' )
$lbA = Normalize-Anchor( '<a href="./leaderboard.html" class="' + $lbClass + '">Go to Leaderboard</a>' )

# --- Remove ALL previous nav bits/duplicates ---
# prior WHOLEHOG blocks or wrappers
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<!--\s*WHOLEHOG:.*?-->(?:(?!<!--\s*/WHOLEHOG\s*-->).)*?<!--\s*/WHOLEHOG\s*-->','')

# remove any instances of the three anchors anywhere (we’ll reinsert one clean row)
$html = $rxLbHref.Replace($html,'')
$html = $rxOnHref.Replace($html,'')
$html = $rxBtHref.Replace($html,'')

# --- Build centered row (full-width container, centered content) ---
$anchors = @()
if ($onA) { $anchors += $onA }
$anchors += $btA
$anchors += $lbA

$row = '<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">' +
       ($anchors -join ' ') +
       '</div>'

# --- Insert row directly under banner: after </header>, else after <body>, else at top ---
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

Write-Host "Done: 1) removed duplicates, 2) centered a single three-button row, 3) matched styling. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green

