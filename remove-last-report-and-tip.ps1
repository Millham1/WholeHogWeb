param(
  [Parameter(Mandatory = $true)]
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

# Helper for regex replace with flags
function RxReplace([string]$input, [string]$pattern) {
  return [regex]::Replace($input, $pattern, '', 'IgnoreCase, Singleline')
}

$updated = $html

# 1) Remove by known IDs (button AND/OR container)
$patterns = @(
  '\s*<div[^>]*\bid\s*=\s*["'']wh-build-report-container["''][^>]*>.*?</div>\s*',
  '\s*<button[^>]*\bid\s*=\s*["'']wh-build-report-btn["''][^>]*>.*?</button>\s*',
  '\s*<div[^>]*\bid\s*=\s*["'']wh-build-report2-container["''][^>]*>.*?</div>\s*',
  '\s*<button[^>]*\bid\s*=\s*["'']wh-build-report2-btn["''][^>]*>.*?</button>\s*',
  '\s*<div[^>]*\bid\s*=\s*["'']wh-report-hint["''][^>]*>.*?</div>\s*'
)
foreach ($pat in $patterns) { $updated = RxReplace $updated $pat }

# 2) Fallback: remove any button whose visible text matches the labels
#    (in case the id was missing/changed)
$fallbacks = @(
  '(?is)\s*<button\b[^>]*>[^<]*Build\s+Detailed\s+Report\s*\(CSV\)[^<]*</button>\s*',
  '(?is)\s*<button\b[^>]*>[^<]*Build\s+Report\s*\(CSV\)[^<]*</button>\s*'
)
foreach ($pat in $fallbacks) { $updated = [regex]::Replace($updated, $pat, '', 'IgnoreCase') }

# 3) Fallback: if the tip text exists without the id, remove that block
$tipFallback = '(?is)\s*<div\b[^>]*>\s*Tip:\s*Press\s*<strong>Ctrl\s*\+\s*Alt\s*\+\s*R</strong>.*?</div>\s*'
$updated = RxReplace $updated $tipFallback

# Write out only if changed
if ($updated -ne $html) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Removed the lingering report button and tip (left everything else intact)." -ForegroundColor Green
} else {
  Write-Host "ℹ️ Nothing matched: no report buttons/tip found. No changes made." -ForegroundColor Yellow
}
