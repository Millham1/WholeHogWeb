# fix-mojibake-selects.ps1  (PS 5.1 & 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ return $null }
  [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  if($null -eq $Content){ return }
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path,$Content,[Text.Encoding]::UTF8)
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_mojibake_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did=$true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host "Backup saved: $bak" -ForegroundColor Yellow }
}

function Ensure-Utf8Meta([string]$HtmlPath){
  $html = Read-Text $HtmlPath
  if($null -eq $html){ return }
  $low = $html.ToLower()
  if($low.Contains("<meta charset=")) { return }
  $headIdx = $low.IndexOf("<head")
  if($headIdx -lt 0){ return }
  $gt = $html.IndexOf('>',$headIdx)
  if($gt -lt 0){ return }
  $injection = "`r`n  <meta charset=""utf-8""/>"
  $new = $html.Substring(0,$gt+1) + $injection + $html.Substring($gt+1)
  if($new -ne $html){
    Write-Text $HtmlPath $new
    Write-Host "Inserted <meta charset=""utf-8""> into $(Split-Path $HtmlPath -Leaf)" -ForegroundColor Cyan
  }
}

function Normalize-SelectText([string]$Path){
  $txt = Read-Text $Path
  if($null -eq $txt){ return }
  # Build the Unicode characters we want to normalize without pasting them directly:
  $ellipsis = [string][char]0x2026
  $ldq      = [string][char]0x201C   # “
  $rdq      = [string][char]0x201D   # ”
  $lsq      = [string][char]0x2018   # ‘
  $rsq      = [string][char]0x2019   # ’
  $nbsp     = [string][char]0x00A0   # NBSP

  $orig = $txt

  # Common select/placeholder texts
  $txt = $txt.Replace("Loading$ellipsis","Loading...").Replace("Loading...", "Loading...")
  $txt = $txt.Replace("Select team$ellipsis","Select team...").Replace("Select judge$ellipsis","Select judge...")
  $txt = $txt.Replace("Choose$ellipsis","Choose...")

  # Curly quotes -> straight
  $txt = $txt.Replace($ldq,'"').Replace($rdq,'"').Replace($lsq,"'").Replace($rsq,"'")

  # Strip stray NBSPs that sometimes show up as weird characters
  $txt = $txt.Replace($nbsp,' ')

  if($txt -ne $orig){
    Write-Text $Path $txt
    Write-Host "Normalized text in $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
  }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'
$LandingJs   = Join-Path $WebRoot 'landing-sb.js'
$OnsiteJs    = Join-Path $WebRoot 'onsite-sb.js'

Backup-Once @('landing.html','onsite.html','landing-sb.js','onsite-sb.js','styles.css')

# Ensure UTF-8 meta on pages
Ensure-Utf8Meta $LandingHtml
Ensure-Utf8Meta $OnsiteHtml

# Normalize labels/placeholders in HTML & JS that drive the selects
Normalize-SelectText $LandingHtml
Normalize-SelectText $OnsiteHtml
Normalize-SelectText $LandingJs
Normalize-SelectText $OnsiteJs

Write-Host "`nDone. Hard-refresh (Ctrl+F5) both pages and re-check the Team/Judge selects." -ForegroundColor Green
