# fix_landing_nav_final.ps1 (defensive .Count fix + centered three-button row)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$landing = Join-Path $root "landing.html"
$onsite  = Join-Path $root "onsite.html"

if (!(Test-Path $landing)) { throw "landing.html not found at $landing" }
if (!(Test-Path $onsite))  { throw "onsite.html not found at $onsite"  }

function Read-All([string]$p){ Get-Content -LiteralPath $p -Raw -Encoding UTF8 }
function FirstMatch($text,$rx){ $m=[regex]::Match($text,$rx,'IgnoreCase,Singleline'); if($m.Success){$m}else{$null} }
function GetClassTokens([string]$aHtml){
  if ($aHtml -match 'class\s*=\s*"([^"]+)"') { return $Matches[1].Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries) }
  elseif ($aHtml -match "class\s*=\s*'([^']+)'") { return $Matches[1].Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries) }
  else { return @() }
}
function CleanTokens($tokens){
  $bad = 'pull-right|float-right|right|ml-auto|mr-auto|text-right'
  $arr = @($tokens) # coerce to array to avoid .Count issues
  return @($arr | Where-Object { $_ -and ($_ -notmatch "(?i)^($bad)$") })
}

$landingHtml = Read-All $landing
$onsiteHtml  = Read-All $onsite

# backup
Copy-Item -LiteralPath $landing -Destination "$landing.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak" -Force

# 1) get a working button class from onsite nav (first <a> inside #wholehog-nav)
$rxOnsiteNav = @'
(?is)<div[^>]*\bid\s*=\s*"wholehog-nav"[^>]*>[\s\S]*?<\/div>
'@
$navM = FirstMatch $onsiteHtml $rxOnsiteNav
$btnClass = "btn"
if($navM){
  $aM = [regex]::Match($navM.Value,'(?is)<a\b[^>]*class\s*=\s*"([^"]+)"')
  if(-not $aM.Success){ $aM = [regex]::Match($navM.Value,"(?is)<a\b[^>]*class\s*=\s*'([^']+)'" ) }
  if($aM.Success){
    $tokens = GetClassTokens $aM.Value
    $tokens = CleanTokens $tokens
    if (@($tokens).Count -gt 0) { $btnClass = ($tokens -join ' ') }
  }
}

# 2) clean landing: remove any prior injected nav/styles and any scattered old anchors
$rxOldNavs = @'
(?is)<div[^>]*\bid\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?<\/div>
'@
$rxOldStyles = @'
(?is)<style[^>]*\bid\s*=\s*"(?:wh-nav-style|wholehog-nav-style)"[^>]*>[\s\S]*?<\/style>
'@
$rxOnHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bon-?site\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxBtHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bblind-?taste\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$rxLbHref = @'
(?is)<a\b[^>]*href\s*=\s*["'][^"']*\bleaderboard\.html[^"']*["'][^>]*>[\s\S]*?<\/a>
'@
$landingHtml = [regex]::Replace($landingHtml,$rxOldNavs,'')
$landingHtml = [regex]::Replace($landingHtml,$rxOldStyles,'')
$landingHtml = [regex]::Replace($landingHtml,$rxOnHref,'')
$landingHtml = [regex]::Replace($landingHtml,$rxBtHref,'')
$landingHtml = [regex]::Replace($landingHtml,$rxLbHref,'')

# 3) style block identical to onsite, plus anchor hard overrides
$styleBlock = @'
<style id="wh-nav-style">
  #wholehog-nav{
    width:100%; margin:12px auto;
    display:flex; justify-content:center; align-items:center;
    gap:12px; flex-wrap:wrap; text-align:center;
  }
  #wholehog-nav a{
    display:inline-flex; align-items:center; white-space:nowrap;
    width:auto !important; float:none !important; margin:0 !important;
  }
</style>
'@
if ($landingHtml -match '(?is)</head>') {
  $landingHtml = [regex]::Replace($landingHtml,'(?is)</head>',$styleBlock + "`r`n</head>",1)
} else {
  $landingHtml = $styleBlock + "`r`n" + $landingHtml
}

# 4) build a fresh three-button row using the cleaned class
$anchorStyle = 'style="display:inline-flex;align-items:center;white-space:nowrap;width:auto!important;float:none!important;margin:0!important"'
$navRow =
  '<div id="wholehog-nav">' +
    '<a class="' + $btnClass + '" href="./onsite.html" '      + $anchorStyle + '>Go to On-Site</a>' +
    '<a class="' + $btnClass + '" href="./blind-taste.html" ' + $anchorStyle + '>Go to Blind Taste</a>' +
    '<a class="' + $btnClass + '" href="./leaderboard.html" ' + $anchorStyle + '>Go to Leaderboard</a>' +
  '</div>'

# 5) insert immediately after </header>, else after <body>, else prepend
$inserted = $false
$mh = [regex]::Match($landingHtml,'(?is)</header\s*>')
if ($mh.Success) {
  $i = $mh.Index + $mh.Length
  $landingHtml = $landingHtml.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $landingHtml.Substring($i)
  $inserted = $true
} else {
  $mb = [regex]::Match($landingHtml,'(?is)<body\b[^>]*>')
  if ($mb.Success) {
    $i = $mb.Index + $mb.Length
    $landingHtml = $landingHtml.Substring(0,$i) + "`r`n" + $navRow + "`r`n" + $landingHtml.Substring($i)
    $inserted = $true
  }
}
if (-not $inserted) { $landingHtml = $navRow + "`r`n" + $landingHtml }

# 6) write back
Set-Content -LiteralPath $landing -Encoding UTF8 -Value $landingHtml
Write-Host "✅ Landing nav rebuilt: centered three-button row with drift-proof anchors. Backup created." -ForegroundColor Green
Start-Process $landing
