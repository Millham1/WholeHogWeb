# PowerShell 5.1 — adjust-header-and-buttons.ps1
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
  $bak = Join-Path $WebRoot ("BACKUP_hdrbtn_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did = $true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host ("Backup saved to {0}" -f $bak) -ForegroundColor Yellow }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'
$CssPath     = Join-Path $WebRoot 'styles.css'

$missing = @()
foreach($f in @($LandingHtml,$OnsiteHtml,$CssPath)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`r`n" + ($missing -join "`r`n")) }

Backup-Once @('landing.html','onsite.html','styles.css')

# ---- 1) Header: add +3/4" vertical space via padding, no height override ----
$css = Read-Text $CssPath
$markerHdr = '/* WHOLEHOG_HDR_PLUS_075IN */'
if($css -notmatch [regex]::Escape($markerHdr)){
$hdrRule = @'
/* WHOLEHOG_HDR_PLUS_075IN */
body header {
  padding-top: 0.375in !important;   /* top half of 0.75" */
  padding-bottom: 0.375in !important;/* bottom half of 0.75" */
  box-sizing: border-box !important;
}
/* keep header logos vertically centered if you use left/right images */
header img#logoLeft,
header .left-img,
header .brand-left img {
  position: absolute;
  left: 18px;
  top: 50%;
  transform: translateY(-50%);
  max-height: calc(100% - 18px);
  height: auto;
  width: auto;
  display: block;
}
header img#logoRight,
header .right-img,
header .brand-right img {
  position: absolute;
  right: 18px;
  top: 50%;
  transform: translateY(-50%);
  max-height: calc(100% - 18px);
  height: auto;
  width: auto;
  display: block;
}
'@
  $css = $css + "`r`n" + $hdrRule + "`r`n"
  Write-Host "Applied header +0.75in padding in styles.css" -ForegroundColor Cyan
} else {
  Write-Host "Header padding rule already present; leaving as-is." -ForegroundColor DarkGray
}

# ---- 2) Buttons: red background with black text; center onsite link under header ----
$css = Read-Text $CssPath
$markerBtns = '/* WHOLEHOG_BUTTONS_RED_BLACK */'
if($css -notmatch [regex]::Escape($markerBtns)){
$btnRules = @'
/* WHOLEHOG_BUTTONS_RED_BLACK */
:root{ --wh-red:#b10020; }

/* center a plain <a href="onsite.html"> directly under header */
a[href$="onsite.html"]{
  display:block;
  width:fit-content;
  margin:12px auto 20px auto;
  text-decoration:none;
}

/* make main action buttons red with black text */
a[href$="onsite.html"],
button, .btn, .button,
input[type=button], input[type=submit]{
  background: var(--wh-red) !important;
  color:#000 !important;
  border:1px solid var(--wh-red) !important;
  padding:10px 16px;
  border-radius:8px;
  font-weight:600;
  cursor:pointer;
}

/* small hover lift */
a[href$="onsite.html"]:hover,
button:hover, .btn:hover, .button:hover,
input[type=button]:hover, input[type=submit]:hover {
  filter: brightness(1.05);
}
'@
  $css = $css + "`r`n" + $btnRules + "`r`n"
  Write-Host "Added red/black button styles to styles.css" -ForegroundColor Cyan
} else {
  Write-Host "Red/black button styles already present; leaving as-is." -ForegroundColor DarkGray
}

Write-Text $CssPath $css
Write-Host "Done. Press Ctrl+F5 in the browser to bypass cache." -ForegroundColor Green



