param(
  [Parameter(Mandatory=$true)]
  [string]$LandingPath
)

if (-not (Test-Path -LiteralPath $LandingPath)) {
  Write-Error "File not found: $LandingPath"
  exit 1
}

# Read + backup
$abs  = (Resolve-Path -LiteralPath $LandingPath).Path
$html = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup: $bak"

# If a Reports link already exists inside #top-go-buttons, do nothing
if ($html -match '(?is)<[^>]+\bid\s*=\s*["'']top-go-buttons["''][^>]*>.*?href\s*=\s*["''][^"''>]*reports\.html["'']') {
  Write-Host "• A 'Go to Reports' link already exists in #top-go-buttons. No changes made." -ForegroundColor Yellow
  exit 0
}

# Anchor to insert (matches site style: class="go-btn")
$anchor = '  <a class="go-btn" id="go-reports" href="reports.html">Go to Reports</a>'

# Insert the anchor immediately after the opening tag of #top-go-buttons (nav or div)
$pattern = '(?is)(<(?<tag>nav|div)\b[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)'
$updated = [regex]::Replace($html, $pattern, {
  param($m)
  $m.Groups[1].Value + "`r`n" + $anchor
}, 1)

if ($updated -ne $html) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Added 'Go to Reports' button to $abs (aligned with existing Go To buttons)." -ForegroundColor Green
} else {
  Write-Host "⚠ Could not find a #top-go-buttons container (nav/div). No changes made." -ForegroundColor Yellow
}
