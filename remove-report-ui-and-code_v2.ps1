param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

# Resolve absolute path + dir
$abs  = (Resolve-Path -LiteralPath $Path).Path
$dir  = [System.IO.Path]::GetDirectoryName($abs)

# Backup
$orig = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup created: $bak" -ForegroundColor Yellow

$updated = $orig
$changed = $false

function RxReplace([string]$input, [string]$pattern) {
  return [regex]::Replace($input, $pattern, '', 'IgnoreCase, Singleline')
}

# 1) Remove report containers/buttons (by ID)
$patterns = @(
  '\s*<div[^>]*\bid\s*=\s*"wh-build-report-container"[^>]*>.*?</div>\s*',
  '\s*<button[^>]*\bid\s*=\s*"wh-build-report-btn"[^>]*>.*?</button>\s*',
  '\s*<div[^>]*\bid\s*=\s*"wh-build-report2-container"[^>]*>.*?</div>\s*',
  '\s*<button[^>]*\bid\s*=\s*"wh-build-report2-btn"[^>]*>.*?</button>\s*',
  '\s*<div[^>]*\bid\s*=\s*"wh-report-hint"[^>]*>.*?</div>\s*'
)

foreach ($pat in $patterns) {
  $new = RxReplace $updated $pat
  if ($new -ne $updated) { $updated = $new; $changed = $true }
}

# 2) Remove inline report logic block
$patLogic = '\s*<script[^>]*\bid\s*=\s*"wh-build-report-logic"[^>]*>.*?</script>\s*'
$new = RxReplace $updated $patLogic
if ($new -ne $updated) { $updated = $new; $changed = $true }

# 3) Remove external include for wh-report.js
$patInclude = '\s*<script[^>]*\bsrc\s*=\s*"[^"]*wh-report\.js"[^>]*>\s*</script>\s*'
$new = RxReplace $updated $patInclude
if ($new -ne $updated) { $updated = $new; $changed = $true }

# 4) Save cleaned HTML
if ($changed) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Cleaned report buttons and code from: $abs" -ForegroundColor Green
} else {
  Write-Host "ℹ️ Nothing to remove (no matching report UI/scripts found in HTML)." -ForegroundColor Yellow
}

# 5) Delete wh-report.js on disk (non-fatal if missing)
$jsPath = Join-Path $dir 'wh-report.js'
if (Test-Path -LiteralPath $jsPath) {
  try {
    Remove-Item -LiteralPath $jsPath -Force
    Write-Host "🗑️  Deleted file: $jsPath" -ForegroundColor Green
  } catch {
    Write-Warning ("Could not delete ${jsPath}: " + $_.Exception.Message)
  }
} else {
  Write-Host "• No wh-report.js file to delete." -ForegroundColor DarkGray
}
