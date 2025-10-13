# fix-landing-dedup-and-center-buttons.ps1  (PowerShell 5.1 & 7)
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

# 1) Remove our previously inserted nav row (if any)
$patNavRow = '(?is)<div\s+id="navRow"[^>]*>.*?</div>'
$html = [regex]::Replace($html, $patNavRow, '')

# 2) Remove other onsite/blind buttons/links anywhere else (so we won’t have duplicates)
#    Keep these patterns simple and run both double-quote and single-quote variants.

# a) Explicit IDs we may have used before
$patIdOnsite = '(?is)<a\b[^>]*id="btnGoOnsite"[^>]*>.*?</a>'
$patIdBlind  = '(?is)<a\b[^>]*id="btnGoBlind"[^>]*>.*?</a>'
$html = [regex]::Replace($html, $patIdOnsite, '')
$html = [regex]::Replace($html, $patIdBlind,  '')

# b) href="onsite.html" / href='onsite.html'
$patOnsiteHrefD = '(?is)<a\b[^>]*href\s*=\s*"\s*onsite\.html\s*"[^>]*>.*?</a>'
$patOnsiteHrefS = "(?is)<a\b[^>]*href\s*=\s*'\s*onsite\.html\s*'[^>]*>.*?</a>"
$html = [regex]::Replace($html, $patOnsiteHrefD, '')
$html = [regex]::Replace($html, $patOnsiteHrefS, '')

# c) href="blind.html" / href='blind.html'
$patBlindHrefD = '(?is)<a\b[^>]*href\s*=\s*"\s*blind\.html\s*"[^>]*>.*?</a>'
$patBlindHrefS = "(?is)<a\b[^>]*href\s*=\s*'\s*blind\.html\s*'[^>]*>.*?</a>"
$html = [regex]::Replace($html, $patBlindHrefD, '')
$html = [regex]::Replace($html, $patBlindHrefS, '')

# d) <button onclick="...onsite.html...">...</button> (double/single quote)
$patOnsiteBtnD = '(?is)<button\b[^>]*onclick\s*=\s*"[^"]*onsite\.html[^"]*"[^>]*>.*?</button>'
$patOnsiteBtnS = "(?is)<button\b[^>]*onclick\s*=\s*'[^']*onsite\.html[^']*'[^>]*>.*?</button>"
$html = [regex]::Replace($html, $patOnsiteBtnD, '')
$html = [regex]::Replace($html, $patOnsiteBtnS, '')

# e) <button onclick="...blind.html...">...</button> (double/single quote)
$patBlindBtnD = '(?is)<button\b[^>]*onclick\s*=\s*"[^"]*blind\.html[^"]*"[^>]*>.*?</button>'
$patBlindBtnS = "(?is)<button\b[^>]*onclick\s*=\s*'[^']*blind\.html[^']*'[^>]*>.*?</button>"
$html = [regex]::Replace($html, $patBlindBtnD, '')
$html = [regex]::Replace($html, $patBlindBtnS, '')

# 3) Insert a SINGLE centered row BELOW the header with two buttons.
#    Layout: grid with two equal columns, container centered → one button appears left of center, the other right of center.
$navRow = @'
<div id="navRow" style="display:grid;grid-template-columns:1fr 1fr;gap:24px;max-width:640px;margin:18px auto 10px;align-items:center;justify-items:center;">
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

$matchHeaderClose = [regex]::Match($html, '(?is)</header>')
if($matchHeaderClose.Success){
  $insertAt = $matchHeaderClose.Index + $matchHeaderClose.Length
  $html = $html.Substring(0,$insertAt) + "`r`n" + $navRow + "`r`n" + $html.Substring($insertAt)
} else {
  # fallback: right after <body>
  $matchBodyOpen = [regex]::Match($html, '(?is)<body[^>]*>')
  if($matchBodyOpen.Success){
    $insertAt = $matchBodyOpen.Index + $matchBodyOpen.Length
    $html = $html.Substring(0,$insertAt) + "`r`n" + $navRow + "`r`n" + $html.Substring($insertAt)
  } else {
    throw "Could not find </header> or <body> to insert the button row."
  }
}

Write-Text $landing $html
Write-Host "Deduped other buttons and inserted a single centered row under the header." -ForegroundColor Cyan
Write-Host "Reload landing.html (Ctrl+F5) to see it." -ForegroundColor Green
