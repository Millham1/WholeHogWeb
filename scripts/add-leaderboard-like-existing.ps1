[CmdletBinding()]
param([string]$Root=".")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Utf8 = [Text.UTF8Encoding]::new($false)

function New-Backup([Parameter(Mandatory)][string]$Path){
  if (Test-Path -LiteralPath $Path){
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
    Write-Host "Backup created: $Path.bak-$stamp"
  }
}

# ---- Load index.html
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$index    = Join-Path $rootPath "index.html"
if (!(Test-Path -LiteralPath $index)) { throw "index.html not found at: $index" }

$html = Get-Content -LiteralPath $index -Raw
$lc   = $html.ToLowerInvariant()

# If a Leaderboard button already exists in the same button block, bail out.
# We’ll still allow a header/nav link elsewhere to exist.
if ($lc.Contains('leaderboard.html')) {
  # Only bail if it’s already near the On-Site/Blind area; otherwise we’ll still add in-place.
  # We’ll decide this later; don’t early-exit.
}

# ---- Get all <a ...>...</a> with a simple, safe regex
$anchorPattern = "(?is)<a\b[^>]*>.*?</a>"
$anchors = [System.Text.RegularExpressions.Regex]::Matches($html, $anchorPattern)

function Get-InnerText([string]$aHtml){
  $gt  = $aHtml.IndexOf('>')
  $end = $aHtml.ToLowerInvariant().LastIndexOf('</a>')
  if ($gt -ge 0 -and $end -gt $gt) {
    $inner = $aHtml.Substring($gt+1, $end - ($gt+1))
    $inner = [Regex]::Replace($inner, '<[^>]+>', '')
    return ([Regex]::Replace($inner, '\s+', ' ')).Trim()
  }
  return ''
}

function Get-HrefLower([string]$aHtml){
  $lower = $aHtml.ToLowerInvariant()
  $i = $lower.IndexOf('href=')
  if ($i -lt 0) { return '' }
  $q = $aHtml.Substring($i+5,1)
  if ($q -ne '"' -and $q -ne "'") { return '' }
  $start = $i + 6
  $end = $aHtml.IndexOf($q, $start)
  if ($end -lt 0) { return '' }
  return $aHtml.Substring($start, $end - $start).ToLowerInvariant()
}

# Find On-Site / Blind anchors by href or by visible text
$onsite = $null; $blind = $null
foreach ($m in $anchors) {
  $a = $m.Value
  $href = Get-HrefLower $a
  $txt  = (Get-InnerText $a).ToLowerInvariant()

  if (-not $onsite) {
    if ($href.Contains('on-site') -or $href.Contains('onsite') -or $href.Contains('on_site') -or $txt -match 'go to .*on.*site') {
      $onsite = $m
    }
  }
  if (-not $blind) {
    if ( ($href.Contains('blind') -and ($href.Contains('taste') -or $href.Contains('tast'))) -or $txt -match 'go to .*blind.*tast' ) {
      $blind = $m
    }
  }
  if ($onsite -and $blind) { break }
}

# Choose an anchor to clone
$anchorToClone = $onsite
if (-not $anchorToClone) { $anchorToClone = $blind }
if (-not $anchorToClone) {
  throw "Couldn’t find a 'Go to On-Site' or 'Go to Blind Taste' button to clone. Please paste the 10–20 lines around those buttons from index.html and I’ll target it exactly."
}

# Compute insertion point: after the later of the two (if both), else right after the one we found
$insertPos = $anchorToClone.Index + $anchorToClone.Length
if ($onsite -and $blind) {
  $insertPos = [Math]::Max($onsite.Index + $onsite.Length, $blind.Index + $blind.Length)
}

# Check if a leaderboard link already exists inside the same block (within ±1200 chars)
$blockStart = [Math]::Max(0, $anchorToClone.Index - 1200)
$blockEnd   = [Math]::Min($html.Length, $insertPos + 1200)
$blockSlice = $html.Substring($blockStart, $blockEnd - $blockStart).ToLowerInvariant()
if ($blockSlice.Contains('href="leaderboard.html"') -or $blockSlice.Contains("href='leaderboard.html'")) {
  Write-Host "Leaderboard button already present near the other Go To buttons — no changes made."
  exit 0
}

# ---- Build the new anchor by cloning and retargeting
$new = $anchorToClone.Value
$lowerNew = $new.ToLowerInvariant()

# Set href to leaderboard.html
if ($lowerNew.Contains('href="')) {
  $s = $lowerNew.IndexOf('href="') + 6
  $e = $new.IndexOf('"', $s); if ($e -lt 0) { $e = $s }
  $new = $new.Substring(0,$s) + 'leaderboard.html' + $new.Substring($e)
} elseif ($lowerNew.Contains("href='")) {
  $s = $lowerNew.IndexOf("href='") + 6
  $e = $new.IndexOf("'", $s); if ($e -lt 0) { $e = $s }
  $new = $new.Substring(0,$s) + 'leaderboard.html' + $new.Substring($e)
} else {
  $gt = $new.IndexOf('>')
  if ($gt -gt 0) {
    $before = $new.Substring(0,$gt)
    $after  = $new.Substring($gt)
    $space  = ($before.EndsWith(' ') ? '' : ' ')
    $new    = $before + $space + 'href="leaderboard.html"' + $after
  }
}

# Replace inner text to "Go to Leaderboard" (preserve classes/styles; icons may be removed if they were text-only)
$gt = $new.IndexOf('>')
$close = $new.ToLowerInvariant().LastIndexOf('</a>')
if ($gt -ge 0 -and $close -gt $gt) {
  $inner = $new.Substring($gt+1, $close - ($gt+1))
  # Try token replacements first to keep inner markup
  $inner2 = [Regex]::Replace($inner, "(?i)on[\-\s_]?site(\s*tast(e|ing))?", "Leaderboard")
  $inner2 = [Regex]::Replace($inner2, "(?i)blind\s*tast(e|ing)?", "Leaderboard")
  # If no Leaderboard word after replacements, just set a clean label
  if ($inner2.ToLowerInvariant().IndexOf('leaderboard') -lt 0) { $inner2 = "Go to Leaderboard" }
  $new = $new.Substring(0,$gt+1) + $inner2 + $new.Substring($close)
}

# ---- Insert and save
New-Backup -Path $index
$html = $html.Insert($insertPos, "`r`n  " + $new)
[IO.File]::WriteAllText($index, $html, $Utf8)

Write-Host "✅ Added 'Go to Leaderboard' next to your existing buttons (same classes/styles)."
