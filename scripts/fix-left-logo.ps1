
# Minimal, PS 5.1-safe: swap/insert header logo and vertically center it.
param(
  [string]$WebRoot  = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$LogoFile = "Legion whole hog logo.png"  # must be in $WebRoot
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
  $bak = Join-Path $WebRoot ("BACKUP_logo_" + $stamp)
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

$landingHtml = Join-Path $WebRoot 'landing.html'
$onsiteHtml  = Join-Path $WebRoot 'onsite.html'
$cssPath     = Join-Path $WebRoot 'styles.css'

$missing = @()
foreach($f in @($landingHtml,$onsiteHtml,$cssPath)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`n" + ($missing -join "`n")) }

if(-not (Test-Path (Join-Path $WebRoot $LogoFile))){
  Write-Host "WARNING: '$LogoFile' not found in $WebRoot. The HTML will still point to it — place the image in the folder." -ForegroundColor Yellow
}

Backup-Once @('landing.html','onsite.html','styles.css')

function Patch-HeaderImg([string]$HtmlPath,[string]$NewSrc){
  $html = Read-Text $HtmlPath

  # Find first <header>...</header>
  $reHeader = New-Object System.Text.RegularExpressions.Regex '(?is)<header\b[^>]*>.*?</header>'
  $mHeader  = $reHeader.Match($html)
  if(-not $mHeader.Success){
    Write-Host "No <header> in $(Split-Path $HtmlPath -Leaf) — skipping." -ForegroundColor DarkGray
    return $false
  }
  $headerBlock = $mHeader.Value

  # Replace the FIRST <img ...> inside header with our logo; if no <img>, insert one.
  $reImg = New-Object System.Text.RegularExpressions.Regex '(?is)<img\b[^>]*>'
  if($reImg.IsMatch($headerBlock)){
    $newHeader = $reImg.Replace($headerBlock, ('<img id="logoLeft" src="' + $NewSrc + '" alt="Whole Hog" />'), 1)
    if($newHeader -ne $headerBlock){
      $newHtml = $html.Substring(0, $mHeader.Index) + $newHeader + $html.Substring($mHeader.Index + $mHeader.Length)
      Write-Text $HtmlPath $newHtml
      Write-Host "Updated header image in $(Split-Path $HtmlPath -Leaf) -> '$NewSrc'." -ForegroundColor Cyan
      return $true
    }
  } else {
    # No <img> — inject right after opening <header>
    $injected = $headerBlock -replace '(?is)(<header\b[^>]*>)', ('$1' + '<img id="logoLeft" src="' + $NewSrc + '" alt="Whole Hog" />')
    if($injected -ne $headerBlock){
      $newHtml = $html.Substring(0, $mHeader.Index) + $injected + $html.Substring($mHeader.Index + $mHeader.Length)
      Write-Text $HtmlPath $newHtml
      Write-Host "Inserted header image in $(Split-Path $HtmlPath -Leaf) -> '$NewSrc'." -ForegroundColor Cyan
      return $true
    }
  }

  Write-Host "No header image changes applied in $(Split-Path $HtmlPath -Leaf)." -ForegroundColor DarkGray
  return $false
}

$ok1 = Patch-HeaderImg $landingHtml $LogoFile
$ok2 = Patch-HeaderImg $onsiteHtml  $LogoFile

# Vertically center & left-align the logo; size to header height (non-destructive).
$css = Read-Text $cssPath
$marker = '/* === WHOLEHOG header logo centering === */'
if($css -notmatch [regex]::Escape($marker)){
  $rule = @"
$marker
header { position: relative; }
header img#logoLeft,
header .left-img,
header .brand-left img {
  position: absolute;
  left: 18px;
  top: 50%;
  transform: translateY(-50%);
  height: calc(100% - 24px); /* fits inside header height */
  width: auto;
  display: block;
}
"@
  $css = $css + "`r`n" + $rule + "`r`n"
  Write-Text $cssPath $css
  Write-Host "Appended centering CSS to styles.css" -ForegroundColor Cyan
} else {
  Write-Host "Centering CSS already present; left as-is." -ForegroundColor DarkGray
}

Write-Host "`nDone. Press Ctrl+F5 in the browser to bypass cache." -ForegroundColor Green

