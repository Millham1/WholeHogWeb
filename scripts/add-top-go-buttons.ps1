param(
  [string]$Root = ".",
  [string]$BlindFile = "blind.html"
)

$ErrorActionPreference = "Stop"

$rootPath  = Resolve-Path $Root
$blindPath = Join-Path $rootPath $BlindFile

if (!(Test-Path $blindPath)) {
  Write-Error "blind file not found: $blindPath"
  exit 1
}

# Read file
$html = Get-Content -Path $blindPath -Raw

# If already present, exit quietly
if ($html -match 'id\s*=\s*"go-landing-top"' -and $html -match 'id\s*=\s*"go-leaderboard-top"') {
  Write-Host "Go-to buttons (below header) already present. Nothing to do."
  exit 0
}

# Block to insert just BELOW </header>
$block = @"
<div id="top-go-buttons" class="container" style="display:flex;gap:10px;align-items:center;justify-content:flex-start;margin-top:10px;margin-bottom:0;">
  <button type="button" class="btn btn-ghost" id="go-landing-top" onclick="location.href='landing.html'">Go to Landing</button>
  <button type="button" class="btn btn-ghost" id="go-leaderboard-top" onclick="location.href='leaderboard.html'">Go to Leaderboard</button>
</div>
"@

# Insert right after the closing </header> tag (first occurrence)
$pattern = '(?is)(</header\s*>)'
if ($html -match $pattern) {
  $updated = [regex]::Replace($html, $pattern, '$1' + "`r`n" + $block, 1)
} else {
  Write-Error "Couldn't find </header> in blind.html to place the buttons under."
  exit 1
}

# Backup and write
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $blindPath (Join-Path $rootPath ("blind.backup-" + $stamp + ".html")) -Force
$updated | Set-Content -Path $blindPath -Encoding UTF8

Write-Host "✅ Added Go-to buttons directly below the header in $BlindFile"
Write-Host ("Open: file:///" + ((Resolve-Path $blindPath).Path -replace '\\','/'))
