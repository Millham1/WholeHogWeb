# fix_landing_nav_centered.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup + read
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

function FirstMatch($text, $rx) {
  $m = [regex]::Match($text, $rx, 'IgnoreCase,Singleline')
  if ($m.Success) { return $m } else { return $null }
}
function ExtractClass($a) {
  if ($a -match 'class\s*=\s*"([^"]+)"') { return $Matches[1] }
  elseif ($a -match "class\s*=\s*'([^']+)'") { return $Matches[1] }
  return $null
}

# Try to detect your existing button class from current buttons (by text labels)
$rxBlindText = @'
(?is)<a\b[^>]*class\s*=\s*"([^"]+)"[^>]*>[\s\S]*?go\s*to\s*blind\s*-?\s*taste[\s\S]*?</a>
'@
$rxOnText = @'
(?is)<a\b[^>]*class\s*=\s*"([^"]+)"[^>]*>[\s\S]*?go\s*to\s*on\s*-?\s*site[\s\S]*?</a>
'@
$rxLeadText = @'
(?is)<a\b[^>]*class\s*=\s*"([^"]+)"[^>]*>[\s\S]*?go\s*to\s*leader\s*-?\s*board[\s\S]*?</a>
'@

$btnClass = "btn"
$m = FirstMatch $html $rxBlindText
if ($m) { $btnClass = $m.Groups[1].Value }
else {
  $m = FirstMatch $html $rxOnText
  if ($m) { $btnClass = $m.Groups[1].Value }
  else {
    $m = FirstMatch $html $rxLeadText
    if ($m) { $btnClass = $m.Groups[1].Value }
  }
}

# Remove any previous injected wrappers
$rxWrapper = @'
(?is)<div[^>]*\bid\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>
'@
$html = [regex]::Replace($html, $rxWrapper, '')

# Remove ANY scattered nav anchors (by href and by text)
$rxOnHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bon[- ]?site\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxBtHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bblind[- ]?taste\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxLbHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bleader[^"']*board\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxOnTxt = @'
(?is)<a\b[^>]*>[\s\S]*?go\s*to\s*on\s*-?\s*site[\s\S]*?<\/a>
'@
$rxBtTxt = @'
(?is)<a\b[^>]*>[\s\S]*?go\s*to\s*blind\s*-?\s*taste[\s\S]*?<\/a>
'@
$rxLbTxt = @'
(?is)<a\b[^>]*>[\s\S]*?go\s*to\s*leader\s*-?\s*board[\s\S]*?<\/a>
'@

$html = [regex]::Replace($html, $rxOnHref, '')
$html = [regex]::Replace($html, $rxBtHref, '')
$html = [regex]::Replace($html, $rxLbHref, '')
$html = [regex]::Replace($html, $rxOnTxt, '')
$html = [regex]::Replace($html, $rxBtTxt, '')
$html = [regex]::Replace($html, $rxLbTxt, '')

# Build one centered row (correct On-Site link)
$anchorStyle = 'style="display:inline-block;white-space:nowrap;width:auto;float:none"'
$navRow = @"
<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center !important;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">
  <a href="./onsite.html" class="$btnClass" $anchorStyle>Go to On-Site</a>
  <a href="./blind-taste.html" class="$btnClass" $anchorStyle>Go to Blind Taste</a>
  <a href="./leaderboard.html" class="$btnClass" $anchorStyle>Go to Leaderboard</a>
</div>
"@

# Insert directly after </header>, else after <body>, else prepend
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

# Tiny, scoped style to guarantee centering
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

# Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ One centered nav row inserted and On-Site link set. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
