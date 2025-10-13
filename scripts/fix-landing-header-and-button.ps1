param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$HeaderHeightIn = "2.25in"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_fix_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did = $true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host "Backup saved to $bak" -ForegroundColor Yellow }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'
$CssPath     = Join-Path $WebRoot 'styles.css'

$missing = @()
foreach($f in @($LandingHtml,$OnsiteHtml)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`r`n" + ($missing -join "`r`n")) }
if(-not (Test-Path $CssPath)){ New-Item -ItemType File -Path $CssPath -Force | Out-Null }

Backup-Once @('landing.html','onsite.html','styles.css')

# 1) CSS override: header height + button colors
function Ensure-CssOverrides([string]$CssPathLocal, [string]$HeightIn){
  $css = Read-Text $CssPathLocal
  $marker = '/* WH: header & primary buttons overrides */'
  if($css -match [regex]::Escape($marker)){
    # Replace only the height value inside our block if it's different
    $css = [regex]::Replace($css,
      '(?s)(/\* WH: header & primary buttons overrides \*/.*?min-height:\s*)[^;]+(.*?height:\s*)[^;]+',
      ('$1' + $HeightIn + '$2' + $HeightIn))
    Write-Text $CssPathLocal $css
    return
  }

  $block = @"
$marker
/* Force taller header */
header, .site-header, .header, .app-header {
  min-height: $HeightIn !important;
  height: $HeightIn !important;
  display: block;
}

/* Primary buttons: red background with black text */
#btnGoOnsite, #btnAddTeam, #btnAddJudge,
a.btn-red-black, button.btn-red-black {
  background: #b10020 !important; /* red */
  color: #111 !important;         /* black text */
  border: 2px solid #111 !important;
  padding: 10px 18px !important;
  border-radius: 10px !important;
  font-weight: 700 !important;
  text-decoration: none !important;
  display: inline-block;
}
#btnGoOnsite:hover, #btnAddTeam:hover, #btnAddJudge:hover,
a.btn-red-black:hover, button.btn-red-black:hover {
  filter: brightness(0.97);
}

/* Center wrapper used below header on landing page */
#go-onsite-wrap { text-align: center; margin: 16px 0 24px; }
"@
  $css = $css + "`r`n" + $block + "`r`n"
  Write-Text $CssPathLocal $css
  Write-Host "Appended CSS overrides to styles.css" -ForegroundColor Cyan
}
Ensure-CssOverrides -CssPathLocal $CssPath -HeightIn $HeaderHeightIn

# 2) Inline style on <header> so it wins even if page-level CSS is odd
function ForceInlineHeaderHeight([string]$HtmlPath,[string]$HeightIn){
  $h = Read-Text $HtmlPath

  # First, if style already present, append heights
  $pat1 = '(?is)(<header\b[^>]*style\s*=\s*["''])([^"'']*)(["''])'
  $rep1 = '$1$2; height:' + $HeightIn + '; min-height:' + $HeightIn + '; line-height:' + $HeightIn + ';$3'
  $h2 = [regex]::Replace($h, $pat1, $rep1)

  # Then, for header tags with NO style attribute, add one
  $pat2 = '(?is)<header\b(?![^>]*\bstyle\b)([^>]*)>'
  $rep2 = '<header$1 style="height:' + $HeightIn + '; min-height:' + $HeightIn + '; line-height:' + $HeightIn + ';">'
  $h3 = [regex]::Replace($h2, $pat2, $rep2)

  if($h3 -ne $h){
    Write-Text $HtmlPath $h3
    Write-Host ("Set inline header height to {0} in {1}" -f $HeightIn,(Split-Path $HtmlPath -Leaf)) -ForegroundColor Cyan
  } else {
    Write-Host ("No <header> tag changed in {0} (already had correct height?)" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor DarkGray
  }
}
ForceInlineHeaderHeight -HtmlPath $LandingHtml -HeightIn $HeaderHeightIn
ForceInlineHeaderHeight -HtmlPath $OnsiteHtml  -HeightIn $HeaderHeightIn

# 3) landing.html: ensure ONE centered Go button just after </header>
function PatchLandingGoButton([string]$HtmlPath){
  $h = Read-Text $HtmlPath

  # Remove any previous injected wrapper or stray Go buttons
  $h = [regex]::Replace($h, '(?is)\s*<div\b[^>]*id=["'']go-onsite-wrap["''][\s\S]*?</div>\s*', '')
  $h = [regex]::Replace($h, '(?is)\s*<a\b[^>]*id=["'']btnGoOnsite["''][\s\S]*?</a>\s*', '')

  # Insert after </header>, else after <body>
  $afterHeader = [regex]::Match($h, '(?is)</header>')
  if($afterHeader.Success){
    $before = $h.Substring(0, $afterHeader.Index + $afterHeader.Length)
    $after  = $h.Substring($afterHeader.Index + $afterHeader.Length)
    $injection = @'
<div id="go-onsite-wrap">
  <a id="btnGoOnsite" href="onsite.html" class="btn-red-black">Go to On-Site Scoring</a>
</div>
'@
    $h = $before + "`r`n" + $injection + "`r`n" + $after
  } else {
    $bodyOpen = [regex]::Match($h, '(?is)<body\b[^>]*>')
    if($bodyOpen.Success){
      $idx = $bodyOpen.Index + $bodyOpen.Length
      $injection = @'
<div id="go-onsite-wrap" style="text-align:center;margin:16px 0 24px;">
  <a id="btnGoOnsite" href="onsite.html" class="btn-red-black">Go to On-Site Scoring</a>
</div>
'@
      $h = $h.Substring(0,$idx) + "`r`n" + $injection + "`r`n" + $h.Substring($idx)
    }
  }

  Write-Text $HtmlPath $h
  Write-Host "Landing: ensured a single centered Go button beneath the header." -ForegroundColor Cyan
}
PatchLandingGoButton -HtmlPath $LandingHtml

Write-Host "`nDone. Press Ctrl+F5 in the browser to bypass cache." -ForegroundColor Green






