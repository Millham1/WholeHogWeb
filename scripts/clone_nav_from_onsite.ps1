# clone_nav_from_onsite.ps1
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

# Extract the EXACT style + nav used on On-Site
$rxStyle = @'
(?is)<style[^>]*\bid\s*=\s*"wh-nav-style"[^>]*>[\s\S]*?<\/style>
'@
$rxNav = @'
(?is)<div[^>]*\bid\s*=\s*"wholehog-nav"[^>]*>[\s\S]*?<\/div>
'@

$styleMatch = [regex]::Match($onsiteHtml, $rxStyle)
$navMatch   = [regex]::Match($onsiteHtml, $rxNav)

# Fallbacks (only if not present in onsite.html)
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
if (-not $navMatch.Success) {
  $navMatch = [pscustomobject]@{
    Value = @'
<div id="wholehog-nav">
  <a class="btn" href="./onsite.html">Home</a>
  <a class="btn" href="./leaderboard.html">Go to Leaderboard</a>
</div>
'@
  }
}

# Use the exact blocks from On-Site, but ensure On-Site link is ./onsite.html (normalize on-site → onsite)
$styleBlock = $styleMatch.Value
$navBlock   = $navMatch.Value
$navBlock   = [regex]::Replace($navBlock, '(?i)href\s*=\s*"(?:\./)?on-?site\.html"', 'href="./onsite.html"')
$navBlock   = [regex]::Replace($navBlock, "(?i)href\s*=\s*'(?:\./)?on-?site\.html'", "href='./onsite.html'")

# Clean landing: remove any prior injected styles/navs and scattered duplicates
$rxOldStyle1 = @'
(?is)<style[^>]*\bid\s*=\s*"wh-nav-style"[^>]*>[\s\S]*?<\/style>
'@
$rxOldStyle2 = @'
(?is)<style[^>]*\bid\s*=\s*"wholehog-nav-style"[^>]*>[\s\S]*?<\/style>
'@
$rxOldNav = @'
(?is)<div[^>]*\bid\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?<\/div>
'@
$landingHtml = [regex]::Replace($landingHtml, $rxOldStyle1, '')
$landingHtml = [regex]::Replace($landingHtml, $rxOldStyle2, '')
$landingHtml = [regex]::Replace($landingHtml, $rxOldNav, '')

# Also remove any scattered anchors to those 3 pages (so only the cloned row remains)
$rxOnHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bon-?site\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxBtHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bblind-?taste\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxLbHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bleaderboard\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$landingHtml = [regex]::Replace($landingHtml, $rxOnHref, '')
$landingHtml = [regex]::Replace($landingHtml, $rxBtHref, '')
$landingHtml = [regex]::Replace($landingHtml, $rxLbHref, '')

# Insert style into <head> (or prepend if no head)
if ($landingHtml -match '(?is)</head>') {
  $landingHtml = [regex]::Replace($landingHtml, '(?is)</head>', $styleBlock + "`r`n</head>", 1)
} else {
  $landingHtml = $styleBlock + "`r`n" + $landingHtml
}

# Insert nav immediately AFTER </header>. Fallback: right after <body>, else prepend
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

# Backup and write
$bak = "$landing.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $landing -Destination $bak -Force
Set-Content -LiteralPath $landing -Encoding UTF8 -Value $landingHtml

Write-Host "✅ Cloned nav from onsite.html into landing.html, placed directly after </header>. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $landing
