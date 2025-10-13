param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup-Once([string]$FilePath){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path (Split-Path $FilePath -Parent) ("BACKUP_before_dedup_" + $stamp + ".html")
  Copy-Item $FilePath $bak -Force
  Write-Host "Backup saved: $bak" -ForegroundColor Yellow
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$LandingHtml = Join-Path $WebRoot 'landing.html'
if(-not (Test-Path $LandingHtml)){ throw "landing.html not found at $LandingHtml" }

# Read and backup
$html = Read-Text $LandingHtml
Backup-Once $LandingHtml

# ---- Remove ALL existing “Go to On-Site Scoring” buttons/links/wrappers safely ----
# Use patterns that only contain double quotes inside (PowerShell single-quoted outside) to avoid escaping issues.

$patterns = @(
  # Any wrapper div that looks like a prior injection: id/class includes go-onsite/go-onsite-wrap
  '(?is)\s*<div[^>]*\b(?:id|class)\b[^>]*\bgo-?onsite(?:-wrap)?\b[^>]*>.*?</div>\s*',

  # Any anchor or button that directly targets onsite.html via href or onclick
  '(?is)\s*<(?:a|button)\b[^>]*(?:href|onclick)\s*=\s*"[^"]*onsite\.html[^"]*"[^>]*>.*?</(?:a|button)>\s*',

  # Specifically by id from earlier iterations
  '(?is)\s*<a\b[^>]*\bid\s*=\s*"btnGoOnsite"[^>]*>.*?</a>\s*'
)

$totalRemoved = 0
foreach($pat in $patterns){
  $before = $html
  $html   = [regex]::Replace($html, $pat, '')
  if($html -ne $before){
    $removed = ([regex]::Matches($before, $pat)).Count
    $totalRemoved += $removed
  }
}

# Also sweep any now-empty simple divs left behind
$html = [regex]::Replace($html, '(?is)<div\b[^>]*>\s*</div>', '')

Write-Host ("Removed {0} existing button/link wrapper(s)." -f $totalRemoved) -ForegroundColor DarkGray

# ---- Insert exactly one centered button right after </header>, else right after <body> ----
$injection = @'
<div id="go-onsite-wrap" style="text-align:center;margin:16px 0 24px;">
  <a id="btnGoOnsite" href="onsite.html" class="btn-red-black">Go to On-Site Scoring</a>
</div>
'@

$inserted = $false
$mHeaderClose = [regex]::Match($html, '(?is)</header>')
if($mHeaderClose.Success){
  $idx = $mHeaderClose.Index + $mHeaderClose.Length
  $html = $html.Substring(0,$idx) + "`r`n" + $injection + "`r`n" + $html.Substring($idx)
  $inserted = $true
} else {
  $mBodyOpen = [regex]::Match($html, '(?is)<body\b[^>]*>')
  if($mBodyOpen.Success){
    $idx = $mBodyOpen.Index + $mBodyOpen.Length
    $html = $html.Substring(0,$idx) + "`r`n" + $injection + "`r`n" + $html.Substring($idx)
    $inserted = $true
  }
}

if($inserted){
  Write-Text $LandingHtml $html
  Write-Host "Inserted exactly one centered Go button beneath the header." -ForegroundColor Cyan
} else {
  Write-Host "Could not locate </header> or <body> to inject the button. No changes written." -ForegroundColor Red
}

Write-Host "`nDone. Hard-refresh the page (Ctrl+F5)." -ForegroundColor Green

