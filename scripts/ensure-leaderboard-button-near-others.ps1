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

# --- Load index.html
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$index    = Join-Path $rootPath "index.html"
if (!(Test-Path -LiteralPath $index)) { throw "index.html not found at: $index" }

$html = Get-Content -LiteralPath $index -Raw

# --- Collect all anchors with their positions
$reAnchor = '(?is)<a\b[^>]*href\s*=\s*[\u0022\u0027]([^\u0022\u0027>]+)[\u0022\u0027][^>]*>.*?<\/a>'
$matches  = [Regex]::Matches($html, $reAnchor)
if ($matches.Count -eq 0) { throw "No <a> tags found in index.html — can’t place the button." }

# --- Identify the On-Site / Blind anchors by URL (robust substrings)
$onsiteUrl = '(?i)on[\-\s_]?site'
$blindUrl  = '(?i)blind[\-\s_]?tast'

$onsite = $null; $blind = $null
foreach ($m in $matches){
  $url = $m.Groups[1].Value
  if (-not $onsite -and ($url -match $onsiteUrl)) { $onsite = $m }
  if (-not $blind  -and ($url -match $blindUrl )) { $blind  = $m }
  if ($onsite -and $blind) { break }
}

# If URLs didn’t match, try inner text scan (case-insensitive, ignores tags)
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
if (-not $onsite -or -not $blind){
  foreach ($m in $matches){
    $txt = (Get-InnerText $m.Value).ToLowerInvariant()
    if (-not $onsite -and ($txt -match 'go to .*on.*site')) { $onsite = $m }
    if (-not $blind  -and ($txt -match 'go to .*blind.*tast')) { $blind = $m }
    if ($onsite -and $blind) { break }
  }
}

# We need at least one of the two to know where to place
$anchorToClone = $onsite
if (-not $anchorToClone) { $anchorToClone = $blind }
if (-not $anchorToClone) { throw "Couldn’t locate the On-Site or Blind Taste button to clone. Paste that snippet and I’ll target it exactly." }

# Compute the group region: from earliest start to latest end among the two buttons we found
$groupStart = $anchorToClone.Index
$groupEnd   = $anchorToClone.Index + $anchorToClone.Length
if ($onsite){
  $groupStart = [Math]::Min($groupStart, $onsite.Index)
  $groupEnd   = [Math]::Max($groupEnd,   $onsite.Index + $onsite.Length)
}
if ($blind){
  $groupStart = [Math]::Min($groupStart, $blind.Index)
  $groupEnd   = [Math]::Max($groupEnd,   $blind.Index + $blind.Length)
}

# Expand backward to grab the opening parent container
$lookBehind = [Math]::Max(0, $groupStart - 3000)
$prefix = $html.Substring($lookBehind, $groupStart - $lookBehind)
$lastDiv     = $prefix.LastIndexOf('<div',     [StringComparison]::OrdinalIgnoreCase)
$lastSection = $prefix.LastIndexOf('<section', [StringComparison]::OrdinalIgnoreCase)
$lastNav     = $prefix.LastIndexOf('<nav',     [StringComparison]::OrdinalIgnoreCase)
$parentIdx   = [Math]::Max($lastDiv, [Math]::Max($lastSection, $lastNav))

$containerOpenIdx = ($parentIdx -ge 0) ? ($lookBehind + $parentIdx) : $groupStart
$openGt = $html.IndexOf('>', $containerOpenIdx)
if ($openGt -lt 0) { $openGt = $containerOpenIdx }

# Extract the container slice (limited forward window)
$windowEnd = [Math]::Min($html.Length, $groupEnd + 3000)
$containerSlice = $html.Substring($containerOpenIdx, $windowEnd - $containerOpenIdx)

# Check if a leaderboard anchor already exists **inside the same container**
if ([Regex]::IsMatch($containerSlice, '<a\b[^>]*href\s*=\s*[\u0022\u0027]leaderboard\.html[\u0022\u0027]', 'IgnoreCase')){
  # Ensure centering anyway, then done
  $htmlModified = $false
  $openTag = $html.Substring($containerOpenIdx, $openGt - $containerOpenIdx + 1)
  if ($openTag -notmatch 'wh-btn-row'){
    $newOpenTag = $o
