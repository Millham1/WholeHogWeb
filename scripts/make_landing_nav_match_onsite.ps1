# make_landing_nav_match_onsite.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup + read
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# --- Remove any prior injected wrappers/styles and any scattered duplicates of the three nav links ---
$rxWrapper = @'
(?is)<div[^>]*\bid\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?<\/div>
'@
$rxStyleOld1 = @'
(?is)<style[^>]*\bid\s*=\s*"wh-nav-style"[^>]*>[\s\S]*?<\/style>
'@
$rxStyleOld2 = @'
(?is)<style[^>]*\bid\s*=\s*"wholehog-nav-style"[^>]*>[\s\S]*?<\/style>
'@
# Remove anchors by href (onsite/on-site, blind-taste, leaderboard)
$rxOnHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*(?:\bon-?site|\/on-?site|\/onsite)\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxBtHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bblind-?taste\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxLbHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bleaderboard\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@

$html = [regex]::Replace($html, $rxWrapper, '')
$html = [regex]::Replace($html, $rxStyleOld1, '')
$html = [regex]::Replace($html, $rxStyleOld2, '')
$html = [regex]::Replace($html, $rxOnHref, '')
$html = [regex]::Replace($html, $rxBtHref, '')
$html = [regex]::Replace($html, $rxLbHref, '')

# --- Insert the SAME scoped CSS used on On-Site (wins specificity without touching the rest) ---
$styleBlock = @'
<style id="wh-nav-style">
  #wholehog-nav{
    width:100%; margin:12px auto;
    display:flex; justify-content:center; align-items:center;
    gap:12px; flex-wrap:wrap; text-align:center;
  }
  #wholehog-nav a{
    display:inline-block; white-space:nowrap; width:auto; float:none !important;
  }
</style>
'@
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html, '(?is)</head>', $styleBlock + "`r`n</head>", 1)
} else {
  $html = $styleBlock + "`r`n" + $html
}

# --- Build the SAME nav block, but with the 3 landing links ---
$navRow = @'
<div id="wholehog-nav">
  <a class="btn" href="./onsite.html">Go to On-Site</a>
  <a class="btn" href="./blind-taste.html">Go to Blind Taste</a>
  <a class="btn" href="./leaderboard.html">Go to Leaderboard</a>
</div>
'@

# --- Place it IMMEDIATELY after </header> (first element after the banner). Fallback: after <body>, else prepend. ---
$inserted = $false
$mh = [regex]::Match($html, '(?is)</header\s*>')
if ($mh.Success) {
  $i = $mh.Index + $mh.Length
  $html = $html.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $html.Substring($i)
  $inserted = $true
} else {
  $mb = [regex]::Match($html, '(?is)<body\b[^>]*>')
  if ($mb.Success) {
    $i = $mb.Index + $mb.Length
    $html = $html.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $html.Substring($i)
    $inserted = $true
  }
}
if (-not $inserted) { $html = $navRow + "`r`n" + $html }

# --- Write back ---
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Landing nav now matches On-Site: single centered row under header, On-Site → ./onsite.html. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
