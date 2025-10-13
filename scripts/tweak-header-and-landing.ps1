# PowerShell 5.1
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
  $bak = Join-Path $WebRoot ("BACKUP_hdr_" + $stamp)
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
foreach($f in @($LandingHtml,$OnsiteHtml,$CssPath)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`n" + ($missing -join "`n")) }

Backup-Once @('landing.html','onsite.html','styles.css')

# ---------- 1) Header +3/4" height on BOTH pages (via padding) ----------
$css = Read-Text $CssPath
$markerPad = '/* === WHOLEHOG: add 3/4in to header height === */'
if($css -notmatch [regex]::Escape($markerPad)){
$padRule = @'
/* === WHOLEHOG: add 3/4in to header height === */
/* Adds 0.375in top + 0.375in bottom = +0.75in total */
header {
  padding-top: 0.375in !important;
  padding-bottom: 0.375in !important;
}
'@
  $css = $css + "`r`n" + $padRule + "`r`n"
  Write-Text $CssPath $css
  Write-Host "Applied +3/4"" header padding in styles.css" -ForegroundColor Cyan
}else{
  Write-Host "Header padding already present; skipping." -ForegroundColor DarkGray
}

# ---------- 2) Insert centered Go-to-On-Site button right below header (landing page) ----------
$landing = Read-Text $LandingHtml

if($landing -notmatch 'id\s*=\s*"(goOnsiteRow|go-onsite-row)"'){
  $lower = $landing.ToLower()
  $idxCloseHeader = $lower.IndexOf('</header>')
  if($idxCloseHeader -ge 0){
$injection = @'
<div id="goOnsiteRow" class="goto-onsite">
  <a href="onsite.html" class="btn btn-black">Go to On-Site Scoring</a>
</div>
'@
    $before = $landing.Substring(0, $idxCloseHeader + 9)
    $after  = $landing.Substring($idxCloseHeader + 9)
    $landing = $before + "`r`n" + $injection + "`r`n" + $after
    Write-Text $LandingHtml $landing
    Write-Host "Inserted centered Go-to-On-Site button below the header on landing.html" -ForegroundColor Cyan
  } else {
    Write-Host "No </header> found in landing.html; button insertion skipped." -ForegroundColor DarkGray
  }
} else {
  Write-Host "Landing button container already exists; skipping insert." -ForegroundColor DarkGray
}

# ---------- 3) Landing accents (red/blue) + BLACK style for that specific button ----------
$css = Read-Text $CssPath
$markerAccent = '/* === WHOLEHOG: landing accents + black onsite button === */'
if($css -notmatch [regex]::Escape($markerAccent)){
$accent = @'
/* === WHOLEHOG: landing accents + black onsite button === */
:root {
  --wh-red:  #b10020;
  --wh-blue: #0b4fff;
}

/* gentle background tint */
body {
  background-image: linear-gradient(180deg, rgba(11,79,255,0.04), rgba(177,0,32,0.04) 40%, rgba(255,255,255,0) 70%);
  background-repeat: no-repeat;
}

/* headings / section titles in blue */
h1, h2, .section-title { color: var(--wh-blue); }

/* subtle red accent on top of cards */
.card, .panel, .box { border-top: 3px solid var(--wh-red); }

/* the container we inserted */
.goto-onsite {
  text-align: center;
  margin: 14px 0 22px 0;
}

/* black button, scoped just to this container */
.goto-onsite .btn-black {
  display: inline-block;
  padding: 10px 18px;
  background: #000000;
  color: #ffffff;
  text-decoration: none;
  border-radius: 8px;
  font-weight: 600;
  border: 1px solid #000000;
}
.goto-onsite .btn-black:hover,
.goto-onsite .btn-black:focus {
  filter: brightness(1.1);
  outline: none;
}
'@
  $css = $css + "`r`n" + $accent + "`r`n"
  Write-Text $CssPath $css
  Write-Host "Added landing accents and black button style to styles.css" -ForegroundColor Cyan
}else{
  Write-Host "Landing accents already present; skipping." -ForegroundColor DarkGray
}

Write-Host "`nDone. Ctrl+F5 to refresh the browser." -ForegroundColor Green

