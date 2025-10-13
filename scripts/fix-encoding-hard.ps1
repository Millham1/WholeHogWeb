# fix-encoding-hard.ps1  (PowerShell 5.1 & 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ return $null }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  if($null -eq $Content){ return }
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_encoding_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did = $true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host "Backup saved: $bak" -ForegroundColor Yellow }
}

function Ensure-Utf8Meta([string]$HtmlPath){
  $html = Read-Text $HtmlPath
  if($null -eq $html){ return }
  $low  = $html.ToLowerInvariant()
  if($low.Contains("<meta charset=")){ return }   # already present
  $ixHead = $low.IndexOf("<head")
  if($ixHead -lt 0){ return }
  $gt = $html.IndexOf('>', $ixHead)
  if($gt -lt 0){ return }
  $inject = "`r`n  <meta charset=""utf-8""/>"
  $new = $html.Substring(0, $gt+1) + $inject + $html.Substring($gt+1)
  if($new -ne $html){
    Write-Text $HtmlPath $new
    Write-Host "Inserted <meta charset=""utf-8""> into $(Split-Path $HtmlPath -Leaf)" -ForegroundColor Cyan
  }
}

function Fix-Mojibake([string]$Path){
  $txt = Read-Text $Path
  if($null -eq $txt){ return }

  $orig = $txt

  # Map the most common broken sequences -> ASCII-safe replacements
  $repls = @(
    @{f='Ã¢â‚¬â€œ'; t='-'}   # en dash -> hyphen
    @{f='â€“';      t='-'}
    @{f='Ã¢â‚¬â€ '; t='--'}  # em dash -> double hyphen
    @{f='â€”';      t='--'}
    @{f='Ã¢â‚¬Â¦'; t='...'} # ellipsis -> three dots
    @{f='...';      t='...'}
    @{f='Ã¢â‚¬Ëœ'; t="'"}   # opening single
    @{f='Ã¢â‚¬â„¢'; t="'"}   # closing single
    @{f='â€˜';      t="'"}
    @{f='â€™';      t="'"}
    @{f='Ã¢â‚¬Å“'; t='"'}   # opening double
    @{f='Ã¢â‚¬Â'; t='"'}   # closing double
    @{f='â€œ';      t='"'}
    @{f='â€';      t='"'}
    @{f='Â ';       t=' '} # stray NBSP marker
    @{f='Â ';       t=' '}
    @{f='2–40';   t='2-40'}
    @{f='4–80';   t='4-80'}
    @{f='2Ã¢â‚¬â€œ40'; t='2-40'}
    @{f='4Ã¢â‚¬â€œ80'; t='4-80'}
    @{f='Loading...';      t='Loading...'}
    @{f='Select judge...'; t='Select judge...'}
    @{f='Select team...';  t='Select team...'}
  )

  foreach($r in $repls){
    $txt = $txt.Replace($r.f, $r.t)
  }

  if($txt -ne $orig){
    Write-Text $Path $txt
    Write-Host "Normalized mojibake in $(Split-Path $Path -Leaf)" -ForegroundColor Cyan
  }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'
$LandingJs   = Join-Path $WebRoot 'landing-sb.js'
$OnsiteJs    = Join-Path $WebRoot 'onsite-sb.js'
$CssPath     = Join-Path $WebRoot 'styles.css'

$toBackup = @()
foreach($f in @('landing.html','onsite.html','landing-sb.js','onsite-sb.js','styles.css')){
  $p = Join-Path $WebRoot $f
  if(Test-Path $p){ $toBackup += $f }
}
Backup-Once $toBackup

# Ensure UTF-8 meta on pages (affects how the browser reads the HTML itself)
Ensure-Utf8Meta $LandingHtml
Ensure-Utf8Meta $OnsiteHtml

# Normalize broken sequences everywhere (HTML + JS + CSS)
foreach($p in @($LandingHtml,$OnsiteHtml,$LandingJs,$OnsiteJs,$CssPath)){
  if(Test-Path $p){ Fix-Mojibake $p }
}

Write-Host "`nDone. Hard-refresh (Ctrl+F5) or open a private window to verify the Team/Judge selects are clean." -ForegroundColor Green


