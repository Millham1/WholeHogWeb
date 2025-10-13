[CmdletBinding()]
param([string]$Root=".")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

function New-Backup([Parameter(Mandatory)][string]$Path){
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
    Write-Host "Backup created: $Path.bak-$stamp"
  }
}

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$target   = Join-Path $rootPath "leaderboard.html"
if (!(Test-Path -LiteralPath $target)) { throw "leaderboard.html not found at: $target" }

$html = Get-Content -LiteralPath $target -Raw

# Common title variants to replace (case-insensitive)
$variants = @(
  "Whole Hog On-Site Scoring",
  "Whole Hog On Site Scoring",
  "Whole Hog On–Site Scoring",  # en dash
  "Whole Hog On—Site Scoring",  # em dash
  "On-Site Scoring",
  "On Site Scoring",
  "On–Site Scoring",
  "On—Site Scoring"
)

$changed = $false
foreach ($v in $variants) {
  $before = $html
  $html   = [Regex]::Replace($html, [Regex]::Escape($v), "Leaderboard", "IgnoreCase")
  if ($html -ne $before) { $changed = $true }
}

# If nothing matched, try replacing the first <h1> inside <header> with "Leaderboard"
if (-not $changed) {
  $before = $html
  $html   = [Regex]::Replace(
              $html,
              "(<header\b[^>]*>.*?<h1\b[^>]*>)(.*?)(</h1>)",
              '$1Leaderboard$3',
              [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline
           )
  if ($html -ne $before) { $changed = $true }
}

if ($changed) {
  New-Backup -Path $target
  [IO.File]::WriteAllText($target, $html, $Utf8NoBom)
  Write-Host "✅ Header text in leaderboard.html set to 'Leaderboard'. (Hard refresh the page: Ctrl+F5)"
} else {
  Write-Warning "Couldn’t find the title to change. Two quick options:"
  Write-Host "1) Tell me the exact current header text and I’ll target it precisely."
  Write-Host "2) One-liner—replace your exact title string:"
  Write-Host '   $t = (Get-Content -Raw .\leaderboard.html); $t = $t -replace [regex]::Escape("Whole Hog On-Site Scoring"), "Leaderboard"; [IO.File]::WriteAllText(".\leaderboard.html",$t,[Text.UTF8Encoding]::new($false))'
}
