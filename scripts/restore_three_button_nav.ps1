# restore_three_button_nav.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$landing = Join-Path $root "landing.html"
$onsite  = Join-Path $root "onsite.html"

if (!(Test-Path $landing)) { throw "landing.html not found at $landing" }
if (!(Test-Path $onsite))  { throw "onsite.html not found at $onsite"  }

# Read files
$landingHtml = Get-Content -LiteralPath $landing -Raw -Encoding UTF8
$onsiteHtml  = Get-Content -LiteralPath $onsite  -Raw -Encoding UTF8

# Backup landing
$bak = "$landing.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $landing -Destination $bak -Force

# --- Extract the working style and button class from onsite.html ---
$rxStyleOnsite = @'
(?is)<style[^>]*\bid\s*=\s*"wh-nav-style"[^>]*>[\s\S]*?<\/style>
'@
$rxNavOnsite = @'
(?is)<div[^>]*\bid\s*=\s*"wholehog-nav"[^>]*>[\s\S]*?<\/div>
'@

$styleMatch = [regex]::Match($onsiteHtml, $rxStyleOnsite)
$navMatch   = [regex]::Match($onsiteHtml, $rxNavOnsite)

# Get a button class from the first <a> in onsite's nav (fallback to "btn")
$btnClass = "btn"
if ($navMatch.Success) {
  $mBtn = [regex]::Match($navMatch.Value, '(?is)<a\b[^>]*class\s*=\s*"([^"]+)"')
  if ($mBtn.Success) { $btnClass = $mBtn.Groups[1].Value }
}

# If onsite doesn't have the style block (unlikely), use a safe default identical to onsite format
if (-not $styleMatch.Success) {
  $styleMatch = [pscustomobject]@{
    Value = @'
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
  }
}

# --- Remove any old nav/style blocks from landing so we don't have duplicates ---
$rxOldNavs = @'
(?is)<div[^>]*\bid\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?<\/div>
'@
$rxOldStyles = @'
(?is)<style[^>]*\bid\s*=\s*"(?:wh-nav-style|wholehog-nav-style)"[^>]*>[\s\S]*?<\/style>
'@
$landingHtml = [regex]::Replace($landingHtml, $rxOldNavs, '')
$landingHtml = [regex]::Replace($landingHtml, $rxOldStyles, '')

# --- Insert the working style into <head> (or prepend if no head) ---
$styleBlock = $styleMatch.Value
if ($landingHtml -match '(?is)</head>') {
  $landingHtml = [regex]::Replace($landingHtml, '(?is)</head>', $styleBlock + "`r`n</head>", 1)
} else {
  $landingHtml = $styleBlock + "`r`n" + $landingHtml
}

# --- Build a THREE-button nav (same class as onsite) ---
$navBlock = @"
<div id="wholehog-nav">
  <a class="$btnClass" href="./onsite.html">Go to On-Site</a>
  <a class="$btnClass" href="./blind-taste.html">Go to Blind Taste</a>
  <a class="$btnClass" href="./leaderboard.html">Go to Leaderboard</a>
</div>
"@

# --- Place the nav immediately AFTER </header> (fallback: after <body>, else prepend) ---
$inserted = $false
$mh = [regex]::Match($landingHtml, '(?is)</header\s*>')
if ($mh.Success) {
  $i = $mh.Index + $mh.Length
  $landingHtml = $landingHtml.Substring(0,$i) + "`r`n" + $navBlock + "`r`n" + $landingHtml.Substring($i)
  $inserted = $true
} else {
  $mb = [regex]::Match($landingHtml, '(?is)<body\b[^>]*>')
  if ($mb.Success) {
    $i = $mb.Index + $mb.Length
    $landingHtml = $landingHtml.Substring(0,$i) + "`r`n" + $navBlock + "`r`n" + $landingHtml.Substring($i)
    $inserted = $true
  }
}
if (-not $inserted) { $landingHtml = $navBlock + "`r`n" + $landingHtml }

# --- Write back and open ---
Set-Content -LiteralPath $landing -Encoding UTF8 -Value $landingHtml
Write-Host "✅ Restored THREE-button centered nav under header (On-Site / Blind Taste / Leaderboard). Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $landing
