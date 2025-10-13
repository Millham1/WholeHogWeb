# swap-logo.ps1  (PowerShell 5.1 compatible)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
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

# Ensure files exist
$missing = @()
foreach($f in @($landingHtml,$onsiteHtml,$cssPath)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count -gt 0){
  throw ("Missing required file(s):`n" + ($missing -join "`n"))
}

# 1) Choose the logo file (prefer existing, no subfolders)
$candidates = @(
  'Legion whole hog logo.png',
  'LegionWholeHog.png',
  'legion-whole-hog-logo.png',
  'Legion whole hog logo.jpg',
  'LegionWholeHog.jpg',
  'legion-whole-hog-logo.jpg'
)
$logoName = $null
foreach($c in $candidates){
  $p = Join-Path $WebRoot $c
  if(Test-Path $p){ $logoName = $c; break }
}
if(-not $logoName){
  $logoName = 'Legion whole hog logo.png'  # still wire to this; user can drop it in later
  Write-Host "WARNING: No logo image found. Referencing '$logoName'. Place this file next to your HTML pages." -ForegroundColor Yellow
}else{
  Write-Host "Using logo: $logoName" -ForegroundColor Green
}

# Backup originals
Backup-Once @('landing.html','onsite.html','styles.css')

# 2) Update HTML <img class="left-img" ... src="...">
function Patch-LeftImg([string]$HtmlPath, [string]$NewSrc){
  $html = Read-Text $HtmlPath
  $re = New-Object System.Text.RegularExpressions.Regex '(<img[^>]*class="left-img"[^>]*src=")[^"]*(")', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $new = $re.Replace($html, { param($m) $m.Groups[1].Value + $NewSrc + $m.Groups[2].Value }, 1)
  if($new -ne $html){
    Write-Text $HtmlPath $new
    Write-Host "Patched left image in: $(Split-Path $HtmlPath -Leaf)" -ForegroundColor Cyan
  } else {
    Write-Host "No left-img tag pattern changed in: $(Split-Path $HtmlPath -Leaf)" -ForegroundColor DarkGray
  }
}

Patch-LeftImg $landingHtml $logoName
Patch-LeftImg $onsiteHtml  $logoName

# 3) Update CSS for .header .left-img to fit inside header and center vertically
$css = Read-Text $cssPath
# Replace the entire .header .left-img { ... } block safely
$blockRe = New-Object System.Text.RegularExpressions.Regex '\.header\s*\.left-img\s*\{.*?\}', ([System.Text.RegularExpressions.RegexOptions]::Singleline)
$newBlock = @'
.header .left-img{
  position:absolute; left:18px; top:50%; transform:translateY(-50%);
  height: calc(100% - 24px);  /* fit within header height */
  width: auto;                 /* preserve aspect ratio */
  display:block;
}
'@
$css2 = $blockRe.Replace($css, $newBlock, 1)
if($css2 -ne $css){
  Write-Text $cssPath $css2
  Write-Host "Updated styles.css to fit logo within header bounds and center vertically." -ForegroundColor Cyan
} else {
  # If no block found, append a safe override at end
  $css2 = $css + "`r`n/* logo fit override */`r`n" + $newBlock + "`r`n"
  Write-Text $cssPath $css2
  Write-Host "Appended logo fit override to styles.css." -ForegroundColor Cyan
}

Write-Host "`nDone. Refresh your pages (Ctrl+F5). If the logo doesn’t show, place the image file '$logoName' in $WebRoot." -ForegroundColor Green
