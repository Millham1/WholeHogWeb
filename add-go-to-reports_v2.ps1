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

# If Reports link already present anywhere in the doc, skip
if ($html -match '(?is)\bhref\s*=\s*["''][^"''>]*\breports\.html["'']') {
  Write-Host "• A link to reports.html already exists. No changes made." -ForegroundColor Yellow
  exit 0
}

# Anchor to insert (matches site style)
$anchor = '<a class="go-btn" id="go-reports" href="reports.html">Go to Reports</a>'

$updated = $html
$done    = $false

function RxReplace([string]$input, [string]$pattern, [string]$replacement) {
  return [regex]::Replace($input, $pattern, $replacement, 'IgnoreCase, Singleline')
}

# --- Primary: insert inside id="top-go-buttons" (any tag) right after its opening tag ---
if (-not $done) {
  $pattern = '(?is)(<(?<tag>[a-z0-9:-]+)\b[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)'
  $try = [regex]::Replace($updated, $pattern, {
    param($m)
    $m.Groups[1].Value + "`r`n  " + $anchor
  }, 1)
  if ($try -ne $updated) {
    $updated = $try; $done = $true
    Write-Host "✓ Inserted inside #top-go-buttons." -ForegroundColor Green
  }
}

# --- Fallback A: find a nav/div that contains at least two 'go-btn' anchors; append before its closing tag ---
if (-not $done) {
  $pattern = '(?is)(?<open><(?<tag>nav|div)\b[^>]*>)(?<inner>.*?\bclass\s*=\s*["''][^"']*\bgo-btn\b[^"']*["''].*?\bclass\s*=\s*["''][^"']*\bgo-btn\b[^"']*["''].*?)(?<close></\k<tag>>)'
  $try = [regex]::Replace($updated, $pattern, {
    param($m)
    $m.Groups['open'].Value + $m.Groups['inner'].Value + "`r`n  " + $anchor + "`r`n" + $m.Groups['close'].Value
  }, 1)
  if ($try -ne $updated) {
    $updated = $try; $done = $true
    Write-Host "✓ Inserted into existing Go To buttons container (fallback A)." -ForegroundColor Green
  }
}

# --- Fallback B: find a nav/div with any known Go To link; append before its closing tag ---
if (-not $done) {
  $known = '(?:landing\.html|onsite\.html|blind\.html|sauce\.html|leaderboard\.html)'
  $pattern = "(?is)(?<open><(?<tag>nav|div)\b[^>]*>)(?<inner>.*?\bhref\s*=\s*['""][^'"']*(?:$known)['"'].*?)(?<close></\k<tag>>)"
  $try = [regex]::Replace($updated, $pattern, {
    param($m)
    $m.Groups['open'].Value + $m.Groups['inner'].Value + "`r`n  " + $anchor + "`r`n" + $m.Groups['close'].Value
  }, 1)
  if ($try -ne $updated) {
    $updated = $try; $done = $true
    Write-Host "✓ Inserted next to existing Go To link (fallback B)." -ForegroundColor Green
  }
}

if ($done) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Added 'Go to Reports' button aligned with the others." -ForegroundColor Green
} else {
  Write-Host "⚠ Could not find a Go To buttons container. No changes made." -ForegroundColor Yellow
  Write-Host "If the buttons live in a different container, tell me its id or paste a small snippet and I’ll target it exactly."
}
