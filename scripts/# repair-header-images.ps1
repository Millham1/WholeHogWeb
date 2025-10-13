# repair-header-images.ps1  (PowerShell 7)
param(
  [string]$WebRoot        = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$LeftImageFile  = "Legion whole hog logo.png",
  [string]$RightImageFile = "AL Medallion.png",
  [string]$HeaderHeight   = "2.25in"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path)){ throw "File not found: $Path" }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}

if(-not (Test-Path -LiteralPath $WebRoot)){ throw "Web root not found: $WebRoot" }

$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'
$CssPath     = Join-Path $WebRoot 'styles.css'

$missing = @()
foreach($f in @($LandingHtml,$OnsiteHtml,$CssPath)){ if(-not (Test-Path -LiteralPath $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`n" + ($missing -join "`n")) }

if(-not (Test-Path (Join-Path $WebRoot $LeftImageFile))){
  Write-Host "WARNING: Left image '$LeftImageFile' not found in $WebRoot" -ForegroundColor Yellow
}
if(-not (Test-Path (Join-Path $WebRoot $RightImageFile))){
  Write-Host "WARNING: Right image '$RightImageFile' not found in $WebRoot" -ForegroundColor Yellow
}

function Ensure-Header-Imgs([string]$HtmlPath){
  $html = Read-Text $HtmlPath
  $orig = $html

  # Find first <header>...</header>
  $reHeader = New-Object System.Text.RegularExpressions.Regex '(?is)<header\b[^>]*>.*?</header>'
  $mh = $reHeader.Match($html)
  if(-not $mh.Success){
    Write-Host "No <header> in $(Split-Path $HtmlPath -Leaf) — skipping." -ForegroundColor DarkGray
    return $false
  }

  $headerBlock = $mh.Value

  # Normalize the opening tag to inject inline height/centering using flex
  $reOpen = New-Object System.Text.RegularExpressions.Regex '(?is)<header\b[^>]*?>'
  $openTag = $reOpen.Match($headerBlock).Value
  if(-not $openTag){ return $false }

  # Ensure style with fixed height; keep any existing style
  $reStyle = New-Object System.Text.RegularExpressions.Regex '(?is)\bstyle\s*=\s*("|\')([^"\']*)\1'
  if($reStyle.IsMatch($openTag)){
    $styleBody = $reStyle.Match($openTag).Groups[2].Value
    # Remove prior height/min-height/line-height to avoid conflicts
    $styleBody = [regex]::Replace($styleBody, '(?i)\b(min-)?height\s*:\s*[^;]+;?', '')
    $styleBody = [regex]::Replace($styleBody, '(?i)\bline-height\s*:\s*[^;]+;?', '')
    # add our rules
    $styleBody = ($styleBody.Trim() + ' height:' + $HeaderHeight + '; min-height:' + $HeaderHeight + '; line-height:' + $HeaderHeight + '; display:flex; align-items:center; justify-content:center; position:relative;').Trim()
    $openTagNew = $reStyle.Replace($openTag, { param($m) 'style="' + $styleBody + '"' }, 1)
  } else {
    $openTagNew = $openTag -replace '>$', (' style="height:' + $HeaderHeight + '; min-height:' + $HeaderHeight + '; line-height:' + $HeaderHeight + '; display:flex; align-items:center; justify-content:center; position:relative;">')
  }
  if($openTagNew -ne $openTag){
    $headerBlock = $headerBlock -replace [regex]::Escape($openTag), [System.Text.RegularExpressions.Regex]::Escape('').Replace($openTagNew,'')
  }

  # Replace any existing left/right img tags cleanly
  $reLeft  = New-Object System.Text.RegularExpressions.Regex '(?is)<img\b[^>]*\bid\s*=\s*("|\')logoLeft\1[^>]*>'
  $reRight = New-Object System.Text.RegularExpressions.Regex '(?is)<img\b[^>]*\bclass\s*=\s*("|\')[^"\']*\bright-img\b[^"\']*\1[^>]*>'

  $leftTag  = '<img id="logoLeft"  src="' + $LeftImageFile + '"  alt="Whole Hog" class="wh-left"  />'
  $rightTag = '<img class="right-img wh-right" src="' + $RightImageFile + '" alt="American Legion" />'

  if($reLeft.IsMatch($headerBlock)){
    $headerBlock = $reLeft.Replace($headerBlock, $leftTag, 1)
  } else {
    # inject immediately after opening header tag
    $headerBlock = $headerBlock -replace '(?is)(<header\b[^>]*>)','$1' + $leftTag
  }

  if($reRight.IsMatch($headerBlock)){
    $headerBlock = $reRight.Replace($headerBlock, $rightTag, 1)
  } else {
    # inject before closing </header>
    $headerBlock = $headerBlock -replace '(?is)</header>',$rightTag + '</header>'
  }

  # Put header back
  $html = ($html.Substring(0,$mh.Index)) + $headerBlock + ($html.Substring($mh.Index + $mh.Length))

  if($html -ne $orig){
    Write-Text $HtmlPath $html
    Write-Host "Repaired header images in $(Split-Path $HtmlPath -Leaf)" -ForegroundColor Cyan
    return $true
  } else {
    Write-Host "No header changes in $(Split-Path $HtmlPath -Leaf)" -ForegroundColor DarkGray
    return $false
  }
}

$changed = $false
$changed = (Ensure-Header-Imgs $LandingHtml) -or $changed
$changed = (Ensure-Header-Imgs $OnsiteHtml)  -or $changed

# Minimal CSS to vertically center/fit images without fighting your theme
$css = Read-Text $CssPath
$marker = '/* WH header image fix */'
if($css -notmatch [regex]::Escape($marker)){
  $block = @"
$marker
header .wh-left { position:absolute; left:14px;  top:50%; transform:translateY(-50%); max-height:calc(100% - 18px); height:auto; width:auto; }
header .wh-right{ position:absolute; right:14px; top:50%; transform:translateY(-50%); max-height:calc(100% - 18px); height:auto; width:auto; }
header h1 { margin:0; font-weight:800; text-align:center; }
"@
  Write-Text $CssPath ($css + "`r`n" + $block + "`r`n")
  Write-Host "Appended header centering CSS to styles.css" -ForegroundColor Cyan
} else {
  Write-Host "Header centering CSS already present." -ForegroundColor DarkGray
}

Write-Host "`nDone. Hard-refresh (Ctrl+F5). If images still don’t show, confirm these files exist in your web folder:" -ForegroundColor Green
Write-Host " - $LeftImageFile"  -ForegroundColor Yellow
Write-Host " - $RightImageFile" -ForegroundColor Yellow
