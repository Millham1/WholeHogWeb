# use_backup_onsite.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root   = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$src    = Join-Path $root "onsite_backup.html"
$dest1  = Join-Path $root "onsite.html"
$dest2  = Join-Path $root "on-site.html"  # keep old link path working too

if (!(Test-Path $src)) { throw "onsite_backup.html not found at $src" }

# Backup current onsite.html if present
if (Test-Path $dest1) {
  Copy-Item -LiteralPath $dest1 -Destination "$dest1.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak" -Force
}

# Read backup
$html = Get-Content -LiteralPath $src -Raw -Encoding UTF8

# Remove any previous injected WHOLEHOG block
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"wholehog-nav"[^>]*>[\s\S]*?</div>','')

# Only insert nav if both links aren’t already present
$hasHome = $html -match '(?is)<a\b[^>]*href\s*=\s*"\.\/landing\.html"'
$hasLb   = $html -match '(?is)<a\b[^>]*href\s*=\s*"\.\/leaderboard\.html"'

if (-not ($hasHome -and $hasLb)) {
  $nav = @"
<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">
  <a class="btn" href="./landing.html">Home</a>
  <a class="btn" href="./leaderboard.html">Go to Leaderboard</a>
</div>
"@

  if ($html -match '(?is)</header\s*>') {
    $html = [regex]::Replace($html,'(?is)</header\s*>',"</header>`r`n$nav",1)
  }
  elseif ($html -match '(?is)<body\b[^>]*>') {
    $html = [regex]::Replace($html,'(?is)<body\b[^>]*>','$0' + "`r`n" + $nav,1)
  }
  else {
    $html = $nav + "`r`n" + $html
  }
}

# Write onsite.html
Set-Content -LiteralPath $dest1 -Encoding UTF8 -Value $html

# Also write on-site.html so existing links don’t break
Set-Content -LiteralPath $dest2 -Encoding UTF8 -Value $html

Write-Host "✅ Restored from onsite_backup.html -> onsite.html (and on-site.html). Mini-nav ensured under header." -ForegroundColor Green
Start-Process $dest1
