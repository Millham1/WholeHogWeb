# repair_landing_nav.ps1 — center one row of 3 buttons on landing.html, delete duplicates
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
  $null
}
function Get-Href([string]$aHtml){
  if ($aHtml -match 'href\s*=\s*"([^"]+)"') { return $Matches[1] }
  elseif ($aHtml -match "href\s*=\s*'([^']+)'") { return $Matches[1] }
  $null
}
function Get-Inner([string]$aHtml){
  $m = [regex]::Match($aHtml,'(?is)^<a\b[^>]*>([\s\S]*?)</a>')
  if ($m.Success) { return $m.Groups[1].Value } else { return $null }
}
function Normalize-Anchor([string]$aHtml){
  # Force inline layout so anchors align horizontally even if site CSS tries to stack them
  $m = [regex]::Match($aHtml,'(?is)^<a\b([^>]*)>')
  if (!$m.Success) { return $aHtml }
  $attrs = $m.Groups[1].Value
  $styleMatch = [regex]::Match($attrs,'(?is)\bstyle\s*=\s*"([^"]*)"')
  if ($styleMatch.Success) {
    $style = $styleMatch.Groups[1].Value
    if ($style -notmatch '(?i)\bdisplay\s*:')     { $style += ';display:inline-flex' }
    if ($style -notmatch '(?i)\balign-items\s*:') { $style += ';align-items:center' }
    if ($style -notmatch '(?i)\bfloat\s*:')       { $style += ';float:none!important' }
    if ($style -notmatch '(?i)\bwidth\s*:')       { $style += ';width:auto!important' }
    if ($style -notmatch '(?i)\bwhite-space\s*:') { $style += ';white-space:nowrap' }
    $newAttrs = [regex]::Replace($attrs,'(?is)\bstyle\s*=\s*"[^"]*"', 'style="' + $style + '"', 1)
  } else {
    $newAttrs = $attrs.TrimEnd() + ' style="display:inline-flex;align-items:center;float:none!important;width:auto!important;white-space:nowrap"'
  }
  return '<a' + $newAttrs + '>' + $aHtml.Substring($m.Length)
}

# --- tolerant text-based patterns (ignore hrefs) ---
$rxOnText = [regex]'(?is)<a\b[^>]*>(?:(?!</a>).)*?Go\s*to\s*On\s*[-\s]*Site(?:(?!</a>).)*?</a>'
$rxBtText = [regex]'(?is)<a\b[^>]*>(?:(?!</a>).)*?Go\s*to\s*Blind\s*[-\s]*Taste(?:(?!</a>).)*?</a>'
$rxLbText = [regex]'(?is)<a\b[^>]*>(?:(?!</a>).)*?Go\s*to\s*Leader\s*[-\s]*board(?:(?!</a>).)*?</a>'

# Capture existing anchors (by visible text)
$mOn = $rxOnText.Match($html)
$mBt = $rxBtText.Match($html)
if (-not $mBt.Success) {
  # As a fallback, try by href containing 'blind' + 'taste'
  $mBt = [regex]::Match($html,'(?is)<a\b[^>]*href\s*=\s*"[^"]*blind[^"]*taste[^"]*"\s*[^>]*>[\s\S]*?</a>')
}
if (-not $mBt.Success) { throw 'Could not find your existing "Go to Blind Taste" button text in landing.html.' }

# Reuse classes/hrefs/innerHTML
$onA   = if ($mOn.Success) { $mOn.Value } else { $null }
$btA   = $mBt.Value
$onCls = if ($onA){ Get-Class $onA } else { $null }
$btCls = Get-Class $btA
$leaderCls = if ($btCls) { $btCls } elseif ($onCls) { $onCls } else { "btn" }

# Leaderboard anchor (matching class to your buttons)
$leaderHref = "./leaderboard.html"
$leaderInner = "Go to Leaderboard"
$lbA = '<a href="' + $leaderHref + '" class="' + $leaderCls + '">' + $leaderInner + '</a>'

# --- remove ALL previous nav bits & leaderboard duplicates anywhere ---
# 1) Any previous WHOLEHOG wrappers
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<!--\s*WHOLEHOG:.*?-->(?:(?!<!--\s*/WHOLEHOG\s*-->).)*?<!--\s*/WHOLEHOG\s*-->','')

# 2) remove any Leaderboard anchors anywhere (by text or by href with 'leader')
$html = $rxLbText.Replace($html,'')
$html = [regex]::Replace($html,'(?is)<a\b[^>]*href\s*=\s*"[^"]*leader[^"]*"\s*[^>]*>[\s\S]*?</a>','')

# 3) remove the specific captured On-Site and Blind-Taste anchors everywhere (we’ll reinsert clean row)
if ($mOn.Success){ $html = $html.Replace($onA,'') }
$html = $html.Replace($btA,'')

# Normalize anchors so site CSS can’t stack them
if ($onA){ $onA = Normalize-Anchor $onA }
$btA = Normalize-Anchor $btA
$lbA = Normalize-Anchor $lbA

# --- Build centered full-width row (order: On-Site, Blind Taste, Leaderboard) ---
$anchors = @()
if ($onA) { $anchors += $onA }
$anchors += $btA
$anchors += $lbA

$row = '<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">' +
       ($anchors -join ' ') +
       '</div>'

# --- Insert row directly under banner: after </header>, else after <body>, else prepend ---
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

Write-Host "Done: 1) removed duplicates, 2) built one centered three-button row under the banner, 3) matched styling. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
