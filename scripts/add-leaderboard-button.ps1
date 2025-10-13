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

# --- Load index.html
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$index    = Join-Path $rootPath "index.html"
if (!(Test-Path -LiteralPath $index)) { throw "index.html not found at: $index" }
$html = Get-Content -LiteralPath $index -Raw

# Already present?
if ($html -match 'href\s*=\s*["'']leaderboard\.html["'']') {
  Write-Host "Leaderboard button already present — ensuring centering only..."
}

# Patterns for anchors (robust to small typos and variants)
$anchorPatternTpl = '<a\b[^>]*href\s*=\s*["'']{0}["''][^>]*>.*?</a>'
$onsiteHrefPattern = '(?i)(?:on[\-\s_]?site(?:[\-\s_]?tasting)?|on[\-\s_]?site)[.]html'
$blindHrefPattern  = '(?i)(?:blind(?:[\-\s_]?taste)?)\.html'

# Also catch by link text if hrefs are non-standard
$onsiteTextPattern = '(?i)go\s*to\s*on[\-\s_]?site'
$blindTextPattern  = '(?i)go\s*to\s*blind\s*taste'

# Find onsite & blind anchors
$onsiteMatch = [Regex]::Match($html, [string]::Format($anchorPatternTpl, $onsiteHrefPattern), 'Singleline')
if (-not $onsiteMatch.Success) {
  $onsiteMatch = [Regex]::Match($html, "<a\b[^>]*>(?:(?!</a>).)*$onsiteTextPattern(?:(?!</a>).)*</a>", 'Singleline')
}
$blindMatch = [Regex]::Match($html,  [string]::Format($anchorPatternTpl, $blindHrefPattern), 'Singleline')
if (-not $blindMatch.Success) {
  $blindMatch = [Regex]::Match($html, "<a\b[^>]*>(?:(?!</a>).)*$blindTextPattern(?:(?!</a>).)*</a>", 'Singleline')
}

# Build Leaderboard anchor
$leaderAnchor = '<a href="leaderboard.html" class="btn btn-primary" style="display:inline-block;margin:.35rem .5rem;">Leaderboard</a>'

$modified = $false

# Insert the Leaderboard button right after the later of the two anchors
if ($onsiteMatch.Success -and $blindMatch.Success -and ($html -notmatch 'href\s*=\s*["'']leaderboard\.html["'']')) {
  $endA = $onsiteMatch.Index + $onsiteMatch.Length
  $endB = $blindMatch.Index + $blindMatch.Length
  $insertPos = [Math]::Max($endA, $endB)

  New-Backup -Path $index
  $html = $html.Insert($insertPos, "`r`n  $leaderAnchor")
  $modified = $true
}

# If we couldn't find both anchors, try an actions/buttons/cta container; otherwise append before </main> as fallback.
if (-not $modified -and ($html -notmatch 'href\s*=\s*["'']leaderboard\.html["'']')) {
  # Try known containers
  $containerMatch = [Regex]::Match($html, '<div[^>]*class\s*=\s*["''][^"']*(actions|buttons|cta)[^"']*["''][^>]*>', 'IgnoreCase')
  if ($containerMatch.Success) {
    # Insert just after the opening tag
    $insertPos = $containerMatch.Index + $containerMatch.Length
    New-Backup -Path $index
    $html = $html.Insert($insertPos, "`r`n  $leaderAnchor")
    $modified = $true
  } elseif ($html -match '</main\s*>') {
    New-Backup -Path $index
    $html = [Regex]::Replace($html, '</main\s*>', "  <!-- Leaderboard CTA -->`r`n  <div class=""wh-btn-row"">$leaderAnchor</div>`r`n</main>", 'IgnoreCase')
    $modified = $true
  }
}

# Ensure the three buttons are centered by styling the parent container that holds them.
# Strategy: find the nearest opening <div|section|nav> before the earlier of the two buttons and add a centering class/style.
function Add-CenteringToParent([string]$htmlRef, [int]$startIndex){
  $lookBehind = [Math]::Max(0, $startIndex - 2000)
  $slice = $htmlRef.Substring($lookBehind, $startIndex - $lookBehind)

  $divIdx     = $slice.LastIndexOf('<div',   [System.StringComparison]::OrdinalIgnoreCase)
  $sectionIdx = $slice.LastIndexOf('<section',[System.StringComparison]::OrdinalIgnoreCase)
  $navIdx     = $slice.LastIndexOf('<nav',   [System.StringComparison]::OrdinalIgnoreCase)
  $parentIdx  = [Math]::Max($divIdx, [Math]::Max($sectionIdx, $navIdx))
  if ($parentIdx -lt 0) { return $htmlRef }

  $parentAbs = $lookBehind + $parentIdx
  $gtIdx = $htmlRef.IndexOf('>', $parentAbs)
  if ($gtIdx -lt 0) { return $htmlRef }

  $openTag = $htmlRef.Substring($parentAbs, $gtIdx - $parentAbs + 1)
  if ($openTag -match 'wh-btn-row' -or $openTag -match 'justify-content' -or $openTag -match 'text-align\s*:\s*center') { return $htmlRef }

  $newOpenTag = $openTag
  if ($newOpenTag -match 'class\s*=\s*["'']') {
    $newOpenTag = [Regex]::Replace($newOpenTag, 'class\s*=\s*["'']', '$0wh-btn-row ', 'IgnoreCase')
  } elseif ($newOpenTag -match 'style\s*=\s*["'']') {
    $newOpenTag = [Regex]::Replace($newOpenTag, 'style\s*=\s*["'']', '$0display:flex;justify-content:center;gap:.75rem;flex-wrap:wrap;', 'IgnoreCase')
  } else {
    $newOpenTag = $newOpenTag.TrimEnd('>')
    $newOpenTag += ' class="wh-btn-row">'
  }

  return $htmlRef.Substring(0, $parentAbs) + $newOpenTag + $htmlRef.Substring($parentAbs + $openTag.Length)
}

# Determine where to add centering
$earliestBtnIdx = $null
if ($onsiteMatch.Success -and $blindMatch.Success) {
  $earliestBtnIdx = [Math]::Min($onsiteMatch.Index, $blindMatch.Index)
} elseif ($onsiteMatch.Success) {
  $earliestBtnIdx = $onsiteMatch.Index
} elseif ($blindMatch.Success) {
  $earliestBtnIdx = $blindMatch.Index
}

if ($earliestBtnIdx -ne $null) {
  $html = Add-CenteringToParent -htmlRef $html -startIndex $earliestBtnIdx
}

# Ensure a style block that centers .wh-btn-row (for the class approach)
if ($html -notmatch 'id=["'']wh-btn-row-style["'']') {
  $centerCss = '<style id="wh-btn-row-style">.wh-btn-row{display:flex;justify-content:center;gap:.75rem;flex-wrap:wrap}.wh-btn-row .btn{display:inline-block}</style>'
  if ($html -match '</head\s*>') {
    $html = [Regex]::Replace($html, '</head\s*>', "  $centerCss`r`n</head>", 'IgnoreCase')
  } else {
    $html = $centerCss + "`r`n" + $html
  }
}

# Save if changed or if we only added centering
if ($modified -or $html -match 'wh-btn-row-style' -or $html -match 'wh-btn-row') {
  if (-not $modified) { New-Backup -Path $index }
  [IO.File]::WriteAllText($index, $html, $Utf8NoBom)
  Write-Host "✅ Leaderboard button inserted and row centered."
} else {
  Write-Host "No changes made (could not find a safe spot). If your button hrefs use custom filenames, tell me and I’ll tune the matcher."
}

