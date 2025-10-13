[CmdletBinding()]
param([string]$Root=".")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

function New-Backup([Parameter(Mandatory)][string]$Path){
  if (Test-Path -LiteralPath $Path){
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
    Write-Host "Backup created: $Path.bak-$stamp"
  }
}

# Load index.html
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$index    = Join-Path $rootPath "index.html"
if (!(Test-Path -LiteralPath $index)) { throw "index.html not found at: $index" }
$html = Get-Content -LiteralPath $index -Raw

# Helper: find anchor by href pattern or visible text (uses [\u0022\u0027] for quotes)
function Find-Anchor {
  param(
    [string]$Html,
    [string]$HrefRegex,   # e.g. '(?i)on[\-\s_]?site\.html'
    [string]$TextRegex    # e.g. '(?i)go\s*to\s*on[\-\s_]?site'
  )
  $anchorTpl = '<a\b[^>]*href\s*=\s*[\u0022\u0027]{0}[\u0022\u0027][^>]*>.*?</a>'
  if ($HrefRegex) {
    $pat = [string]::Format($anchorTpl, $HrefRegex)
    $m = [Regex]::Match($Html, $pat, 'Singleline')
    if ($m.Success) { return $m }
  }
  if ($TextRegex) {
    $pat2 = '<a\b[^>]*>(?:(?!</a>).)*' + $TextRegex + '(?:(?!</a>).)*</a>'
    $m2 = [Regex]::Match($Html, $pat2, 'Singleline')
    if ($m2.Success) { return $m2 }
  }
  return $null
}

# Patterns for your two existing buttons
$onsiteHref = '(?i)(?:on[\-\s_]?site(?:[\-\s_]?tast(?:e|ing))?|onsite)\.html'
$blindHref  = '(?i)(?:blind(?:[\-\s_]?taste|[\-\s_]?tasting)?)\.html'
$onsiteTxt  = '(?i)go\s*to\s*on[\-\s_]?site'
$blindTxt   = '(?i)go\s*to\s*blind\s*taste'

$onsiteMatch = Find-Anchor -Html $html -HrefRegex $onsiteHref -TextRegex $onsiteTxt
$blindMatch  = Find-Anchor -Html $html -HrefRegex $blindHref  -TextRegex $blindTxt

# Already has Leaderboard?
$leaderExists = [Regex]::IsMatch($html, '<a\b[^>]*href\s*=\s*[\u0022\u0027]leaderboard\.html[\u0022\u0027]', 'IgnoreCase')
$leaderAnchor = '<a href="leaderboard.html" class="btn btn-primary" style="display:inline-block;margin:.35rem .5rem;">Leaderboard</a>'

$modified = $false

# Insert Leaderboard right after the later of the two anchors
if (-not $leaderExists -and $onsiteMatch -and $blindMatch) {
  $insertPos = [Math]::Max($onsiteMatch.Index + $onsiteMatch.Length, $blindMatch.Index + $blindMatch.Length)
  New-Backup -Path $index
  $html = $html.Insert($insertPos, "`r`n  $leaderAnchor")
  $modified = $true
  Write-Host "Inserted Leaderboard next to On-Site and Blind buttons."
}

# If we couldn’t find both, try a generic actions/buttons/cta container
if (-not $leaderExists -and -not $modified) {
  $containerMatch = [Regex]::Match($html, '<div[^>]*class\s*=\s*[\u0022\u0027][^>]*(actions|buttons|cta)[^>]*[\u0022\u0027][^>]*>', 'IgnoreCase')
  if ($containerMatch.Success) {
    New-Backup -Path $index
    $html = $html.Insert($containerMatch.Index + $containerMatch.Length, "`r`n  $leaderAnchor")
    $modified = $true
    Write-Host "Inserted Leaderboard inside actions/buttons/cta container."
  }
}

# Fallback: add before </main>
if (-not $leaderExists -and -not $modified -and $html -match '</main\s*>') {
  New-Backup -Path $index
  $html = [Regex]::Replace($html, '</main\s*>', "  <!-- Leaderboard CTA -->`r`n  <div class=""wh-btn-row"">$leaderAnchor</div>`r`n</main>", 'IgnoreCase')
  $modified = $true
  Write-Host "Inserted Leaderboard before </main> as fallback."
}

# Center the row containing the buttons by tagging the nearest parent container
function Add-CenteringToParent([string]$htmlRef, [int]$startIndex){
  $lookBehind = [Math]::Max(0, $startIndex - 3000)
  $slice = $htmlRef.Substring($lookBehind, $startIndex - $lookBehind)

  $divIdx     = $slice.LastIndexOf('<div',     [System.StringComparison]::OrdinalIgnoreCase)
  $sectionIdx = $slice.LastIndexOf('<section', [System.StringComparison]::OrdinalIgnoreCase)
  $navIdx     = $slice.LastIndexOf('<nav',     [System.StringComparison]::OrdinalIgnoreCase)
  $parentIdx  = [Math]::Max($divIdx, [Math]::Max($sectionIdx, $navIdx))
  if ($parentIdx -lt 0) { return $htmlRef }

  $parentAbs = $lookBehind + $parentIdx
  $gtIdx = $htmlRef.IndexOf('>', $parentAbs)
  if ($gtIdx -lt 0) { return $htmlRef }

  $openTag = $htmlRef.Substring($parentAbs, $gtIdx - $parentAbs + 1)
  if ($openTag -match 'wh-btn-row' -or $openTag -match 'justify-content' -or $openTag -match 'text-align\s*:\s*center') { return $htmlRef }

  $newOpenTag = $openTag
  if ($newOpenTag -match 'class\s*=\s*[\u0022\u0027]') {
    $newOpenTag = [Regex]::Replace($newOpenTag, 'class\s*=\s*[\u0022\u0027]', '$0wh-btn-row ', 'IgnoreCase')
  } elseif ($newOpenTag -match 'style\s*=\s*[\u0022\u0027]') {
    $newOpenTag = [Regex]::Replace($newOpenTag, 'style\s*=\s*[\u0022\u0027]', '$0display:flex;justify-content:center;gap:.75rem;flex-wrap:wrap;', 'IgnoreCase')
  } else {
    $newOpenTag = $newOpenTag.TrimEnd('>')
    $newOpenTag += ' class="wh-btn-row">'
  }

  return $htmlRef.Substring(0, $parentAbs) + $newOpenTag + $htmlRef.Substring($parentAbs + $openTag.Length)
}

# Decide where to center based on earliest of the two known buttons
$earliestIdx = $null
if     ($onsiteMatch -and $blindMatch) { $earliestIdx = [Math]::Min($onsiteMatch.Index, $blindMatch.Index) }
elseif ($onsiteMatch)                  { $earliestIdx = $onsiteMatch.Index }
elseif ($blindMatch)                   { $earliestIdx = $blindMatch.Index }

if ($earliestIdx -ne $null) {
  if (-not $modified) { New-Backup -Path $index }  # backup even if only styling
  $html = Add-CenteringToParent -htmlRef $html -startIndex $earliestIdx
}

# Add CSS once for .wh-btn-row centering, if used
if (-not [Regex]::IsMatch($html, 'id\s*=\s*[\u0022\u0027]wh-btn-row-style[\u0022\u0027]', 'IgnoreCase')) {
  $centerCss = '<style id="wh-btn-row-style">.wh-btn-row{display:flex;justify-content:center;gap:.75rem;flex-wrap:wrap}.wh-btn-row .btn{display:inline-block}</style>'
  if ($html -match '</head\s*>') {
    $html = [Regex]::Replace($html, '</head\s*>', "  $centerCss`r`n</head>", 'IgnoreCase')
  } else {
    $html = $centerCss + "`r`n" + $html
  }
}

# Save if anything changed or we centered
if ($modified -or $html -match 'wh-btn-row-style' -or $html -match 'wh-btn-row') {
  [IO.File]::WriteAllText($index, $html, $Utf8NoBom)
  Write-Host "✅ Leaderboard button placed with On-Site & Blind buttons and centered."
} else {
  Write-Host "No changes made. If your button filenames/text differ, paste that snippet and I’ll tailor the matcher."
}


