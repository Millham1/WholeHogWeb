# force_center_nav.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# Read
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# Detect a button class from any existing nav-like anchors (prefer Blind Taste, then On-Site, then Leaderboard)
function Get-ClassFromAnchor([string]$a){
  if ($a -match 'class\s*=\s*"([^"]+)"') { return $Matches[1] }
  elseif ($a -match "class\s*=\s*'([^']+)'") { return $Matches[1] }
  return $null
}
function First([string]$text,[string]$rx){
  $m=[regex]::Match($text,$rx,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor `
                             [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if($m.Success){$m.Value}else{$null}
}

# Grab some candidates before we delete them
$candBlind = First $html '(?is)<a\b[^>]*>(?:(?!</a>).)*?go\s*to\s*blind\s*-?\s*taste(?:(?!</a>).)*?</a>'
$candOn    = First $html '(?is)<a\b[^>]*>(?:(?!</a>).)*?go\s*to\s*on\s*-?\s*site(?:(?!</a>).)*?</a>'
$candLead  = First $html '(?is)<a\b[^>]*>(?:(?!</a>).)*?go\s*to\s*leader\s*-?\s*board(?:(?!</a>).)*?</a>'

$btnClass  = (Get-ClassFromAnchor $candBlind) `
         ?? (Get-ClassFromAnchor $candOn) `
         ?? (Get-ClassFromAnchor $candLead) `
         ?? "btn"

# 1) Remove any previous injected wrappers
$html = [regex]::Replace($html,'(?is)<div[^>]*\bid\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')

# 2) Remove EVERY scattered nav anchor (by href **and** by text)
# Href-based (catch ./on-site.html, onsite.html, blind-taste variants, leaderboard)
$rxOnHref = '(?is)<a\b[^>]*href\s*=\s*["''][^"']*on[^"']*site[^"']*\.html[^"']*["''][^>]*>[\s\S]*?<\/a>'
$rxBtHref = '(?is)<a\b[^>]*href\s*=\s*["''][^"']*blind[^"']*taste[^"']*\.html[^"']*["''][^>]*>[\s\S]*?<\/a>'
$rxLbHref = '(?is)<a\b[^>]*href\s*=\s*["''][^"']*leader[^"']*board[^"']*\.html[^"']*["''][^>]*>[\s\S]*?<\/a>'
$html = [regex]::Replace($html,$rxOnHref,'')
$html = [regex]::Replace($html,$rxBtHref,'')
$html = [regex]::Replace($html,$rxLbHref,'')
# Text-based (in case the hrefs are unusual)
$rxOnTxt = '(?is)<a\b[^>]*>[\s\S]*?go\s*to\s*on\s*-?\s*site[\s\S]*?<\/a>'
$rxBtTxt = '(?is)<a\b[^>]*>[\s\S]*?go\s*to\s*blind\s*-?\s*taste[\s\S]*?<\/a>'
$rxLbTxt = '(?is)<a\b[^>]*>[\s\S]*?go\s*to\s*leader\s*-?\s*board[\s\S]*?<\/a>'
$html = [regex]::Replace($html,$rxOnTxt,'')
$html = [regex]::Replace($html,$rxBtTxt,'')
$html = [regex]::Replace($html,$rxLbTxt,'')
# Also remove any old style with our id just in case
$html = [regex]::Replace($html,'(?is)<style[^>]*id\s*=\s*"wholehog-nav-style"[^>]*>[\s\S]*?</style>','')

# 3) Build a single centered row under the banner
$anchorStyle = 'style="display:inline-block;white-space:nowrap;width:auto;float:none"'
$navRow = @"
<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center !important;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">
  <a href="./onsite.html" class="$btnClass" $anchorStyle>Go to On-Site</a>
  <a href="./blind-taste.html" class="$btnClass" $anchorStyle>Go to Blind Taste</a>
  <a href="./leaderboard.html" class="$btnClass" $anchorStyle>Go to Leaderboard</a>
</div>
"@

# 4) Insert directly after </header>, else after <body>, else prepend at top
$inserted = $false
$mh = [regex]::Match($html,'(?is)</header\s*>')
if ($mh.Success) {
  $i = $mh.Index + $mh.Length
  $html = $html.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $html.Substring($i)
  $inserted = $true
} else {
  $mb = [regex]::Match($html,'(?is)<body\b[^>]*>')
  if ($mb.Success) {
    $i = $mb.Index + $mb.Length
    $html = $html.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $html.Substring($i)
    $inserted = $true
  }
}
if (-not $inserted) { $html = $navRow + "`r`n" + $html }

# 5) Add a tiny, scoped style block to guarantee centering overrides
$style = @'
<style id="wholehog-nav-style">
  #wholehog-nav{
    width:100%; margin:12px auto;
    display:flex; justify-content:center !important; align-items:center;
    gap:12px; flex-wrap:wrap; text-align:center;
  }
  #wholehog-nav a{
    display:inline-block; white-space:nowrap; width:auto !important; float:none !important;
  }
</style>
'@
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$style + "`r`n</head>",1)
} else {
  $html = $style + "`r`n" + $html
}

# 6) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ One centered nav row inserted; old buttons removed; On-Site link fixed. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
