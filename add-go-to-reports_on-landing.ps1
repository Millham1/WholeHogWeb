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

# If a Reports link already exists anywhere in the nav, skip
if ($html -match '(?is)<nav[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>.*?\bhref\s*=\s*["''][^"''>]*\breports\.html["'']') {
  Write-Host "• 'Go to Reports' already present in #wholehog-nav. No changes made." -ForegroundColor Yellow
  exit 0
}

# Anchor to insert (match existing markup: no class attr needed)
$anchor = '  <a href="./reports.html">Go to Reports</a>'

# Append inside <nav id="wholehog-nav">...</nav> just before </nav>
$pattern = '(?is)(<nav\b[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
$updated = [regex]::Replace($html, $pattern, {
  param($m)
  $open  = $m.Groups[1].Value
  $inner = $m.Groups[2].Value.TrimEnd()
  $close = $m.Groups[3].Value
  $open + $inner + "`r`n" + $anchor + "`r`n" + $close
}, 1)

if ($updated -ne $html) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Added 'Go to Reports' inside #wholehog-nav (aligned with others)." -ForegroundColor Green
} else {
  Write-Host "⚠ Could not find <nav id=""wholehog-nav"">. No changes made." -ForegroundColor Yellow
}
