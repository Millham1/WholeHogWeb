# repair_center_nav_static.ps1
# Rebuilds a single centered row of 3 buttons under your banner (no runtime JS).
# Keeps your original On-Site / Blind Taste button HTML, deletes duplicates, creates matching Leaderboard.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# -------- helpers --------
function Read-AllText([string]$p){ Get-Content -LiteralPath $p -Raw -Encoding UTF8 }
function StripTags([string]$html){ [regex]::Replace($html,'<[^>]+>',' ') }
function NormText([string]$s){ (($s -replace '\s+',' ').Trim()).ToLower() }
function First-Match([string]$html, [string]$pattern){
  $m = [regex]::Match($html,$pattern,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if($m.Success){ return $m } else { return $null }
}
function All-Anchors([string]$html){
  [regex]::Matches($html,'(?is)<a\b[^>]*>[\s\S]*?<\/a>') | ForEach-Object { $_.Value }
}
function Get-Class([string]$aHtml){
  if ($aHtml -match 'class\s*=\s*"([^"]+)"') { return $Matches[1] }
  elseif ($aHtml -match "class\s*=\s*'([^']+)'") { return $Matches[1] }
  else { return $null }
}
function Get-Href([string]$aHtml){
  if ($aHtml -match 'href\s*=\s*"([^"]+)"') { return $Matches[1] }
  elseif ($aHtml -match "href\s*=\s*'([^']+)'") { return $Matches[1] }
  else { return $null }
}

# -------- read & clean prior injections/duplicates --------
$html = Read-AllText $file

# remove earlier injected wrappers/scripts/styles and stray leaderboard anchors
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<!--\s*WHOLEHOG:.*?-->(?:(?!<!--\s*/WHOLEHOG\s*-->).)*?<!--\s*/WHOLEHOG\s*-->','')
$html = [regex]::Replace($html,'(?is)<script[^>]*id\s*=\s*"wholehog-[^"]*"[^>]*>[\s\S]*?</script>','')
$html = [regex]::Replace($html,'(?is)<style[^>]*id\s*=\s*"wholehog-[^"]*"[^>]*>[\s\S]*?</style>','')
# remove any leaderboard anchors anywhere (by text or href containing 'leader')
$html = [regex]::Replace($html,'(?is)<a\b[^>]*>(?:(?!</a>).)*?go\s*to\s*leader\s*[-\s]*board(?:(?!</a>).)*?</a>','')
$html = [regex]::Replace($html,'(?is)<a\b[^>]*href\s*=\s*"[^"]*leader[^"]*"[^>]*>[\s\S]*?</a>','')

# -------- find your original On-Site & Blind Taste anchors by visible text --------
$anchors = All-Anchors $html
$onAnchor  = $null
$btAnchor  = $null

foreach($a in $anchors){
  $inner = StripTags(([regex]::Replace($a,'(?is)^<a\b[^>]*>|</a>$','')))
  $t = NormText $inner
  if (-not $onAnchor -and ($t -match 'go\s*to' -and ( ($t -match 'on\s*-\s*site') -or ($t -match '\bonsite\b') ) ) ) { $onAnchor = $a; continue }
  if (-not $btAnchor -and ($t -match 'go\s*to' -and $t -match 'blind' -and $t -match 'taste') ) { $btAnchor = $a; continue }
}

# if not found, try href-based fallback (on-site.html / blind-taste.html)
if (-not $onAnchor) {
  $onAnchor = ($anchors | Where-Object { ($_ -like '*href*') -and (NormText (Get-Href $_)) -like '*on*site*' } | Select-Object -First 1)
}
if (-not $btAnchor) {
  $btAnchor = ($anchors | Where-Object { ($_ -like '*href*') -and (NormText (Get-Href $_)) -like '*blind*taste*' } | Select-Object -First 1)
}

# -------- construct new row content --------
# Use your exact original anchor HTMLs if found; otherwise create reasonable fallbacks
$onHtml = $onAnchor
$btHtml = $btAnchor
if (-not $onHtml) { $onHtml = '<a href="./on-site.html" class="btn">Go to On-Site</a>' }
if (-not $btHtml) { $btHtml = '<a href="./blind-taste.html" class="btn">Go to Blind Taste</a>' }

# Leaderboard uses the same class as Blind Taste if available, else On-Site, else 'btn'
$lbClass = (Get-Class $btHtml)
if (-not $lbClass) { $lbClass = (Get-Class $onHtml) }
if (-not $lbClass) { $lbClass = 'btn' }
$lbHtml = '<a href="./leaderboard.html" class="' + $lbClass + '">Go to Leaderboard</a>'

# Now remove ANY remaining occurrences of the original on/blind anchors (to avoid duplicates when we reinsert)
if ($onAnchor) { $html = $html.Replace($onAnchor,'') }
if ($btAnchor) { $html = $html.Replace($btAnchor,'') }

# Build centered horizontal row (no inline button overrides; rely on container CSS below)
$row = '<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">' +
       $onHtml + ' ' + $btHtml + ' ' + $lbHtml + '</div>'

# -------- inject a tiny scoped CSS (static, not runtime) --------
$styleBlock = @"
<style id="wholehog-nav-style">
  #wholehog-nav { width:100%; margin:12px auto; display:flex; justify-content:center; align-items:center; gap:12px; flex-wrap:wrap; text-align:center; }
  #wholehog-nav a { display:inline-block; white-space:nowrap; width:auto; float:none !important; }
</style>
"@

if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$styleBlock + "`r`n</head>",1)
} else {
  # if no head, prepend at top (safe)
  $html = $styleBlock + "`r`n" + $html
}

# -------- place the row under the banner (after </header> if present, else right after <body>) --------
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
if (-not $inserted) {
  # as last resort, prepend
  $html = $row + "`r`n" + $html
}

# -------- backup + write --------
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html

Write-Host "✅ Rebuilt one centered horizontal row (On-Site • Blind Taste • Leaderboard). Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
