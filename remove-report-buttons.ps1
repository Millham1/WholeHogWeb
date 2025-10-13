param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

# Read + backup
$abs = (Resolve-Path -LiteralPath $Path).Path
$html = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup created: $bak" -ForegroundColor Yellow

# Remove only the buttons with these exact ids; leave containers and scripts intact
$pattern = '\s*<button\b[^>]*\bid\s*=\s*["''](?:wh-build-report-btn|wh-build-report2-btn)["''][^>]*>.*?</button>\s*'

$updated = [regex]::Replace($html, $pattern, '', 'IgnoreCase, Singleline')

if ($updated -ne $html) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Removed report button(s) by id (left everything else as-is)." -ForegroundColor Green
} else {
  Write-Host "ℹ️ No report buttons with id 'wh-build-report-btn' or 'wh-build-report2-btn' found. No changes made." -ForegroundColor Yellow
}
