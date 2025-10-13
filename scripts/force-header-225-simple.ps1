param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$HeaderHeight = "2.25in"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path)){ throw "File not found: $Path" }
  [System.IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  [System.IO.File]::WriteAllText($Path,$Content,[Text.Encoding]::UTF8)
}
function Backup([string]$Path){
  $bak = "$Path.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  Copy-Item -LiteralPath $Path -Destination $bak -Force
  Write-Host "Backup: $bak" -ForegroundColor Yellow
}

# High-priority CSS block we’ll inject into <head> (safe, non-destructive)
function Build-Css([string]$H){
@"
<!-- WH HARD HEADER START -->
<style id="wh-hard-header">
:root { --wh-header-h: $H; }
header, .header, .app-header, .site-header, #header {
  min-height: var(--wh-header-h) !important;
  height: var(--wh-header-h) !important;
  position: relative !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
}
header h1, .header h1, .app-header h1, .site-header h1, #header h1 {
  margin: 0 !important;
  line-height: 1.1 !important;
}
/* Left logo (common IDs/classes or first image) */
header img#logoLeft,
header .left-img,
header .brand-left img,
#header img#logoLeft,
#header .left-img,
#header .brand-left img,
header img:first-of-type {
  position: absolute !important;
  left: 14px !important;
  top: 50% !important;
  transform: translateY(-50%) !important;
  height: calc(100% - 20px) !important;  /* fit inside header */
  width: auto !important;
}
/* Right logo (common classes or last image) */
header img.right-img,
header .brand-right img,
#header img.right-img,
#header .brand-right img,
header img:last-of-type {
  position: absolute !important;
  right: 14px !important;
  top: 50% !important;
  transform: translateY(-50%) !important;
  height: calc(100% - 20px) !important;
  width: auto !important;
}
</style>
<!-- WH HARD HEADER END -->
"@
}

function PatchHeadCss([string]$FilePath,[string]$CssBlock){
  $html = Read-Text $FilePath
  $orig = $html

  $start = "<!-- WH HARD HEADER START -->"
  $end   = "<!-- WH HARD HEADER END -->"

  $si = $html.IndexOf($start,[StringComparison]::OrdinalIgnoreCase)
  $ei = $html.IndexOf($end,[StringComparison]::OrdinalIgnoreCase)
  if($si -ge 0 -and $ei -gt $si){
    $ei += $end.Length
    $html = $html.Substring(0,$si) + $CssBlock + $html.Substring($ei)
  } else {
    $headClose = $html.IndexOf("</head>",[StringComparison]::OrdinalIgnoreCase)
    if($headClose -ge 0){
      $html = $html.Substring(0,$headClose) + "`r`n" + $CssBlock + "`r`n" + $html.Substring($headClose)
    } else {
      $html = $CssBlock + "`r`n" + $html
    }
  }

  if($html -ne $orig){
    Backup $FilePath
    Write-Text $FilePath $html
    Write-Host ("Patched: {0}" -f (Split-Path $FilePath -Leaf)) -ForegroundColor Cyan
  } else {
    Write-Host ("No change: {0} (already patched?)" -f (Split-Path $FilePath -Leaf)) -ForegroundColor DarkGray
  }
}

# Build once
$css = Build-Css $HeaderHeight

# Apply to the pages that exist
$targets = @('landing.html','onsite.html','blind.html') | ForEach-Object { Join-Path $WebRoot $_ } | Where-Object { Test-Path $_ }
if(-not $targets.Count){ throw "No target pages found in $WebRoot" }

foreach($f in $targets){ PatchHeadCss $f $css }

# Quick sanity: warn if expected images aren’t referenced (so you can correct src if needed)
$expectedLeft  = "Legion whole hog logo.png"
$expectedRight = "AL Medallion.png"
foreach($f in $targets){
  $h = Read-Text $f
  if($h -notmatch [regex]::Escape($expectedLeft)){
    Write-Host ("NOTE: {0} does not reference '{1}'. Verify the left logo src." -f (Split-Path $f -Leaf), $expectedLeft) -ForegroundColor Yellow
  }
  if($h -notmatch [regex]::Escape($expectedRight)){
    Write-Host ("NOTE: {0} does not reference '{1}'. Verify the right logo src." -f (Split-Path $f -Leaf), $expectedRight) -ForegroundColor Yellow
  }
}

Write-Host "`nDone. Press Ctrl+F5 to hard-refresh each page." -ForegroundColor Green
