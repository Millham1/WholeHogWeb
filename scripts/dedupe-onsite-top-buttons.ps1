param(
  [string]$Root = ".",
  [string]$OnsiteFile = "onsite.html"
)

$ErrorActionPreference = "Stop"

$rootPath = Resolve-Path $Root
$sitePath = Join-Path $rootPath $OnsiteFile
if (!(Test-Path $sitePath)) { Write-Error "On-site page not found: $sitePath"; exit 1 }

# Read file
$html = Get-Content -Path $sitePath -Raw

function Remove-DuplicatesByPattern {
  param(
    [string]$html,
    [string]$pattern  # (?is) inline opts (IgnoreCase+Singleline) already included
  )
  $matches = [regex]::Matches($html, $pattern)
  if ($matches.Count -le 1) { return $html } # nothing to dedupe

  # Remove all but the first occurrence, from end to start so indices stay valid
  for ($i = $matches.Count-1; $i -ge 1; $i--) {
    $m = $matches[$i]
    $html = $html.Remove($m.Index, $m.Length)
  }
  return $html
}

# Patterns (case-insensitive, singleline via (?is))
# Buttons or links that might have the IDs
$btnLanding     = '(?is)<(?:button|a)\b[^>]*\bid\s*=\s*"go-landing-top"[^>]*>.*?</(?:button|a)>'
$btnLeaderboard = '(?is)<(?:button|a)\b[^>]*\bid\s*=\s*"go-leaderboard-top"[^>]*>.*?</(?:button|a)>'
$btnBlind       = '(?is)<(?:button|a)\b[^>]*\bid\s*=\s*"go-blind-top"[^>]*>.*?</(?:button|a)>'

# Container div that holds the top buttons
$barPattern = '(?is)<div\b[^>]*\bid\s*=\s*"top-go-buttons"[^>]*>.*?</div>'

# 1) Keep only the first bar; remove later bars entirely
$bars = [regex]::Matches($html, $barPattern)
if ($bars.Count -gt 1) {
  for ($i = $bars.Count-1; $i -ge 1; $i--) {
    $m = $bars[$i]
    $html = $html.Remove($m.Index, $m.Length)
  }
}

# 2) Within the remaining HTML, keep only the first occurrence of each button/link id
$html = Remove-DuplicatesByPattern -html $html -pattern $btnLanding
$html = Remove-DuplicatesByPattern -html $html -pattern $btnLeaderboard
$html = Remove-DuplicatesByPattern -html $html -pattern $btnBlind

# 3) Tidy extra blank lines
$html = ($html -replace "(`r?`n){3,}", "`r`n`r`n")

# Backup and write
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $sitePath (Join-Path $rootPath ("onsite.backup-" + $stamp + ".html")) -Force
$html | Set-Content -Path $sitePath -Encoding UTF8

Write-Host "✅ Kept first set of Go-to buttons and removed all duplicates in ${OnsiteFile}."
Write-Host ("Open: file:///" + ((Resolve-Path $sitePath).Path -replace '\\','/'))
