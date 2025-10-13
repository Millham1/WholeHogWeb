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
function Backup-Once([string]$FilePath){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path (Split-Path $FilePath -Parent) ("BACKUP_before_cleanup_" + $stamp + ".html")
  Copy-Item $FilePath $bak -Force
  Write-Host "Backup saved: $bak" -ForegroundColor Yellow
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$LandingHtml = Join-Path $WebRoot 'landing.html'
if(-not (Test-Path $LandingHtml)){ throw "landing.html not found at $LandingHtml" }

# Read and backup
$html = Read-Text $LandingHtml
Backup-Once $LandingHtml

# Remove any previously-inserted wrappers/anchors/buttons for "Go to On-Site Scoring"
$patterns = @(
  # Our previous wrapper div
  '(?is)\s*<div\b[^>]*id=["'']go-onsite-wrap["''][\s\S]*?</div>\s*',
  # Anchor with known id
  '(?is)\s*<a\b[^>]*id=["'']btnGoOnsite["''][\s\S]*?</a>\s*',
  # Class-based anchor (if used)
  '(?is)\s*<a\b[^>]*class=["''][^"'']*\bbtn-go-onsite\b[^"'']*["''][\s\S]*?</a>\s*',
  # Generic <a> that links to onsite.html and mentions on-site in text
  '(?is)\s*<a\b[^>]*href=["'']\s*onsite\.html\s*["''][^>]*>[\s\S]*?on-?\s*site[\s\S]*?</a>\s*',
  # Buttons that navigate to onsite.html
  '(?is)\s*<button\b[^>]*onclick=["''][^"'']*onsite\.html[^"'']*["''][^>]*>[\s\S]*?on-?\s*site[\s\S]*?</button>\s*'
)

$removed = 0
foreach($pat in $patterns){
  $new = [regex]::Replace($html, $pat, { param($m) $script:removed++; return "" })
  $html = $new
}
Write-Host ("Removed {0} existing Go-to-Onsite button(s)/wrapper(s)." -f $removed) -ForegroundColor DarkGray

# Insert a single centered button just after </header> (preferred), else right after <body>
$injection = @'
<div id="go-onsite-wrap" style="text-align:center;margin:16px 0 24px;">
  <a id="btnGoOnsite" href="onsite.html" class="btn-red-black">Go to On-Site Scoring</a>
</div>
'@

$inserted = $false
$match = [regex]::Match($html, '(?is)</header>')
if($match.Success){
  $idx = $match.Index + $match.Length
  $html = $html.Substring(0,$idx) + "`r`n" + $injection + "`r`n" + $html.Substring($idx)
  $inserted = $true
} else {
  $mBody = [regex]::Match($html, '(?is)<body\b[^>]*>')
  if($mBody.Success){
    $idx = $mBody.Index + $mBody.Length
    $html = $html.Substring(0,$idx) + "`r`n" + $injection + "`r`n" + $html.Substring($idx)
    $inserted = $true
  }
}

if($inserted){
  Write-Text $LandingHtml $html
  Write-Host "Inserted a single centered Go button beneath the header." -ForegroundColor Cyan
} else {
  Write-Host "Could not find </header> or <body> to inject the button. No changes written." -ForegroundColor Red
}

Write-Host "`nDone. Refresh the browser with Ctrl+F5 to bypass cache." -ForegroundColor Green
