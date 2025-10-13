# inject_leaderboard_into_landing.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$landing = Join-Path $root "landing.html"
$leader  = Join-Path $root "leaderboard.html"

if (!(Test-Path $landing)) { throw "landing.html not found at $landing" }

# Read current landing and prepare snippet
$content = Get-Content -LiteralPath $landing -Raw -Encoding UTF8
$snippet = "<!-- WHOLEHOG: Leaderboard Button -->`r`n<div id=""wholehog-leaderboard-btn""><a href=""./leaderboard.html"" class=""btn"">Go to Leaderboard</a></div>`r`n<!-- /WHOLEHOG -->"

# Skip if already present
if ($content -match 'wholehog-leaderboard-btn') {
  Write-Host "Button already present. No changes made." -ForegroundColor Yellow
} else {
  # Choose insertion point
  if ($content -match '(?i)</main>') {
    $updated = [regex]::Replace($content,'(?i)</main>',$snippet + "`r`n</main>",1)
  } elseif ($content -match '(?i)</body>') {
    $updated = [regex]::Replace($content,'(?i)</body>',$snippet + "`r`n</body>",1)
  } else {
    $updated = $content + "`r`n" + $snippet
  }

  # Backup + write
  $bak = "$landing.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
  Copy-Item -LiteralPath $landing -Destination $bak -Force
  Set-Content -LiteralPath $landing -Encoding UTF8 -Value $updated
  Write-Host "Injected Leaderboard button into landing.html (backup: $([IO.Path]::GetFileName($bak)))" -ForegroundColor Green
}

# Ensure a simple leaderboard target exists (only if missing)
if (-not (Test-Path $leader)) {
  $leaderHtml = '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Leaderboard</title></head><body><h1>Leaderboard</h1><p><a href="./landing.html">Home</a></p></body></html>'
  Set-Content -LiteralPath $leader -Encoding UTF8 -Value $leaderHtml
  Write-Host "Created placeholder leaderboard.html" -ForegroundColor Green
} else {
  Write-Host "leaderboard.html already exists — left unchanged." -ForegroundColor DarkGray
}
