# add-blind-button-row.ps1 (PS 5.1 & 7)

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

$landing = Join-Path $WebRoot 'landing.html'
if(-not (Test-Path $landing)){ throw "landing.html not found at $landing" }

# Backup
$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$backup = Join-Path $WebRoot ("BACKUP_landing_" + $stamp + ".html")
Copy-Item $landing $backup -Force
Write-Host "Backup saved: $backup" -ForegroundColor Yellow

$html = Read-Text $landing

# Remove any previously inserted navRow block
$patNav = '(?is)<div\s+id=["' + "'" + ']navRow["' + "'" + '][^>]*>.*?</div>'
if([regex]::IsMatch($html, $patNav)){
  $html = [regex]::Replace($html, $patNav, '')
}

# Build our centered row (inline styles to avoid CSS dependencies)
$navRow = @'
<div id="navRow" style="display:flex;gap:16px;justify-content:center;align-items:center;margin:18px 0;">
  <a id="btnGoOnsite"
     href="onsite.html"
     style="background:#b10020;color:#111;border:2px solid #111;padding:10px 18px;border-radius:10px;font-weight:700;text-decoration:none;display:inline-block;">
    Go to On-Site Scoring
  </a>
  <a id="btnGoBlind"
     href="blind.html"
     style="background:#b10020;color:#111;border:2px solid #111;padding:10px 18px;border-radius:10px;font-weight:700;text-decoration:none;display:inline-block;">
    Go to Blind Taste
  </a>
</div>
'@

# Insert right after the first </header>. If not found, insert after <body>
$matchHeader = [regex]::Match($html, '(?is)</header>')
if($matchHeader.Success){
  $insertAt = $matchHeader.Index + $matchHeader.Length
  $newHtml = $html.Substring(0,$insertAt) + "`r`n" + $navRow + "`r`n" + $html.Substring($insertAt)
} else {
  $matchBody = [regex]::Match($html, '(?is)<body[^>]*>')
  if($matchBody.Success){
    $insertAt = $matchBody.Index + $matchBody.Length
    $newHtml = $html.Substring(0,$insertAt) + "`r`n" + $navRow + "`r`n" + $html.Substring($insertAt)
  } else {
    throw "Could not find </header> or <body> to place the buttons."
  }
}

Write-Text $landing $newHtml
Write-Host "Inserted one centered row with two buttons under the header." -ForegroundColor Cyan
Write-Host "Reload landing.html (Ctrl+F5 to bypass cache)." -ForegroundColor Green
