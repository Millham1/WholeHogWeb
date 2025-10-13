[CmdletBinding()]
param(
  [string]$Root = ".",
  [string]$Target = "leaderboard.html"
)

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

$rootPath   = (Resolve-Path -LiteralPath $Root).Path
$targetPath = Join-Path $rootPath $Target
if (!(Test-Path -LiteralPath $targetPath)) { throw "File not found: $targetPath" }

# Load page
$html = Get-Content -LiteralPath $targetPath -Raw

# Find the header block
$match = [Regex]::Match($html, '<header\b[^>]*>.*?</header>', 'IgnoreCase,Singleline')
if (-not $match.Success) { throw "No <header>...</header> block found in $Target." }

$hdr  = $match.Value
$orig = $hdr

# Replace common variants of the text (handles On-Site / On Site / en/em dash)
$patterns = @(
  'Whole\s*Hog\s*On[\-\u2013\u2014 ]?Site\s*Scoring',  # "Whole Hog On-Site Scoring"
  'On[\-\u2013\u2014 ]?Site\s*Scoring'                 # "On-Site Scoring"
)
foreach ($p in $patterns) {
  $hdr = [Regex]::Replace($hdr, $p, 'Leaderboard', 'IgnoreCase')
}

# If nothing changed, add a page-only title inside the header and hide common title nodes
if ($hdr -eq $orig) {
  # Inject CSS once to hide typical title elements so we don't show two titles
  if ($html -notmatch 'id="wh-lb-fallback"') {
    $css = '<style id="wh-lb-fallback">.page-title,.site-title,[data-role=title],[role=heading]{display:none!important}</style>'
    if ($html -match '</head\s*>') {
      $html = [Regex]::Replace($html, '</head\s*>', "  $css`r`n</head>", 'IgnoreCase')
    } else {
      $html = "$css`r`n$html"
    }
  }
  # Append our explicit title just before </header>
  $hdr = $orig -replace '</header>', '<div class="wh-page-title" style="margin-left:.5rem;font-weight:700;font-size:1.2rem;">Leaderboard</div></header>'
}

# Reinsert the edited header into the document
$html =
  $html.Substring(0, $match.Index) +
  $hdr +
  $html.Substring($match.Index + $match.Length)

# Also set the <title> tag
if ($html -match '<title\b[^>]*>.*?</title>') {
  $html = [Regex]::Replace($html, '<title\b[^>]*>.*?</title>', '<title>Leaderboard | Whole Hog</title>', 'IgnoreCase,Singleline')
}

# Save with backup
New-Backup -Path $targetPath
[IO.File]::WriteAllText($targetPath, $html, $Utf8NoBom)

Write-Host "✅ Updated header text in $Target to 'Leaderboard'. Use Ctrl+F5 to hard refresh."
