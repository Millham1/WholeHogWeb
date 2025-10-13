param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) { Write-Error "File not found: $Path"; exit 1 }

# Read + backup (safe)
$abs = (Resolve-Path -LiteralPath $Path).Path
$html = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup created: $bak" -ForegroundColor Yellow

# Remove ONLY the last report button container: <div id="wh-build-report3-container"> ... </div>
$pattern = '(?is)\s*<div[^>]*\bid\s*=\s*["'']wh-build-report3-container["''][^>]*>.*?</div>\s*'
$updated = [regex]::Replace($html, $pattern, '', 'IgnoreCase, Singleline')

# Fallback: if someone edited the container but left the link, remove just the <a id="wh-build-report3-link">…</a>
if ($updated -eq $html) {
  $patternLink = '(?is)\s*<a[^>]*\bid\s*=\s*["'']wh-build-report3-link["''][^>]*>.*?</a>\s*'
  $updated = [regex]::Replace($html, $patternLink, '', 'IgnoreCase, Singleline')
}

if ($updated -ne $html) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Removed the remaining report button (wh-build-report3-container / link) and nothing else." -ForegroundColor Green
} else {
  Write-Host "ℹ️ Couldn’t find the final report button container/link. No changes made." -ForegroundColor Yellow
}
