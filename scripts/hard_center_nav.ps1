# hard_center_nav.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Read + backup
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8
$bak  = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# --- Helpers ---
function Extract-Class([string]$a){
  if ($a -match 'class\s*=\s*"([^"]+)"') { return $Matches[1] }
  elseif ($a -match "class\s*=\s*'([^']+)'") { return $Matches[1] }
  $null
}
function First-Match([string]$html, [string]$rx){
  $m=[regex]::Match($html,$rx); if($m.Success){$m}else{$null}
}

# --- Find existing anchors by href (robust to ./ and hyphens) ---
$rxOn = @'(?is)<a\b[^>]*href\s*=\s*["'][^"'>]*on-?site\.html[^"'>]*["'][^>]*>[\s\S]*?<\/a>'@
$rxBt = @'(?is)<a\b[^>]*href\s*=\s*["'][^"'>]*blind-?taste\.html[^"'>]*["'][^>]*>[\s\S]*?<\/a>'@
$rxLb = @'(?is)<a\b[^>]*href\s*=\s*["'][^"'>]*leaderboard\.html[^"'>]*["'][^>]*>[\s\S]*?<\/a>'@

$onM = First-Match $html $rxOn
$btM = First-Match $html $rxBt
$lbM = First-Match $html $rxLb

# Classes to reuse (prefer whichever exists)
$onClass = if($onM){ Extract-Class $onM.Value } else { $null }
$btClass = if($btM){ Extract-Class $btM.Value } else { $null }
$lbClass = $btClass ?? $onClass ?? "btn"

# --- Remove ALL scattered copies / older injected wrappers ---
# Remove any prior WHOLEHOG wrappers
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')
# Remove all three anchor types anywhere (we will reinsert one clean row)
$html = [regex]::Replace($html,$rxOn,'')
$html = [regex]::Replace($html,$rxBt,'')
$html = [regex]::Replace($html,$rxLb,'')
# Remove any old style with same id
$html = [regex]::Replace($html,'(?is)<style[^>]*id\s*=\s*"wholehog-nav-style"[^>]*>[\s\S]*?</style>','')

# --- Build fresh centered row (one place, under the banner) ---
$onHref = './onsite.html'         # <- force correct target
$btHref = './blind-taste.html'
$lbHref = './leaderboard.html'

# Use original classes if present; otherwise lbClass fallback
$onUseClass = $onClass ?? $lbClass
$btUseClass = $btClass ?? $lbClass

$navRow = @"
<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">
  <a href="$onHref" class="$onUseClass">Go to On-Site</a>
  <a href="$btHref" class="$btUseClass">Go to Blind Taste</a>
  <a href="$lbHref" class="$lbClass">Go to Leaderboard</a>
</div>
"@

# Insert immediately after </header>, else right after <body>, else prepend
$inserted=$false
$mh=[regex]::Match($html,'(?is)</header\s*>')
if($mh.Success){
  $i=$mh.Index+$mh.Length
  $html = $html.Substring(0,$i) + "`r`n$navRow`r`n" + $html.Substring($i)
  $inserted=$true
}else{
  $mb=[regex]::Match($html,'(?is)<body\b[^>]*>')
  if($mb.Success){
    $i=$mb.Index+$mb.Length
    $html = $html.Substring(0,$i) + "`r`n$navRow`r`n" + $html.Substring($i)
    $inserted=$true
  }
}
if(-not $inserted){ $html = $navRow + "`r`n" + $html }

# Add a tiny, scoped style to keep it centered (won’t affect anything else)
$style = @'
<style id="wholehog-nav-style">
  #wholehog-nav{ width:100%; margin:12px auto; display:flex; justify-content:center; align-items:center; gap:12px; flex-wrap:wrap; text-align:center; }
  #wholehog-nav a{ display:inline-block; white-space:nowrap; width:auto !important; float:none !important; }
</style>
'@
if($html -match '(?is)</head>'){
  $html = [regex]::Replace($html,'(?is)</head>',$style + "`r`n</head>",1)
}else{
  $html = $style + "`r`n" + $html
}

# --- Write back ---
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Centered one-row nav under header and corrected On-Site link. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $file
