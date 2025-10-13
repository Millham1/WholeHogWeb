param(
  [Parameter(Mandatory=$true)] [string]$OnsitePath,
  [Parameter(Mandatory=$true)] [string]$SaucePath
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p, [string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $s, $enc)
}
function Backup([string]$p){
  if (!(Test-Path $p)) { throw "File not found: $p" }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $bak = "$p.$stamp.bak"
  Copy-Item $p $bak -Force
  Write-Host "🔒 Backup: $bak"
  return $bak
}

# Internal helpers
$NavScope1 = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
$NavScope2 = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'

function Add-Anchor-In-Scopes {
  param(
    [string]$Html,
    [string]$Href,     # e.g. ./sauce.html
    [string]$Label     # e.g. Go to Sauce Tasting
  )
  $anchor = "<a href=""$Href"">$Label</a>"
  $changed = $false

  # Helper to inject inside a matched scope
  $inject = {
    param($m, $href, $anchorText)
    $open  = $m.Groups[1].Value
    $inner = $m.Groups[2].Value
    $close = $m.Groups[3].Value
    if ($inner -notmatch "(?is)href\s*=\s*[""']$([regex]::Escape($href))[""']") {
      $inner = ($inner.TrimEnd() + "`r`n  " + $anchorText + "`r`n")
      $script:changed = $true
    }
    return $open + $inner + $close
  }

  if ([regex]::IsMatch($Html, $NavScope1)) {
    $Html = [regex]::Replace($Html, $NavScope1, { param($m) & $inject $m $Href $anchor }, 1)
  } elseif ([regex]::IsMatch($Html, $NavScope2)) {
    $Html = [regex]::Replace($Html, $NavScope2, { param($m) & $inject $m $Href $anchor }, 1)
  } else {
    # No recognizable nav block; leave unchanged
  }

  return @{ Html = $Html; Changed = $changed }
}

function Remove-Anchor-In-Scopes {
  param(
    [string]$Html,
    [string]$Href
  )
  $rmPat = '(?is)\s*<a\b[^>]*\bhref\s*=\s*["' + [regex]::Escape($Href) + ']["''][^>]*>.*?</a>\s*'

  $stripper = {
    param($m, $rmPattern)
    $open  = $m.Groups[1].Value
    $inner = [regex]::Replace($m.Groups[2].Value, $rmPattern, '')
    $close = $m.Groups[3].Value
    return $open + $inner + $close
  }

  if ([regex]::IsMatch($Html, $NavScope1)) {
    $Html = [regex]::Replace($Html, $NavScope1, { param($m) & $stripper $m $rmPat }, 1)
  }
  if ([regex]::IsMatch($Html, $NavScope2)) {
    $Html = [regex]::Replace($Html, $NavScope2, { param($m) & $stripper $m $rmPat }, 1)
  }
  return $Html
}

# -----------------------------------------------------------------------------------
# 1) On-site: ensure "Go to Sauce Tasting" exists
# -----------------------------------------------------------------------------------
Backup $OnsitePath | Out-Null
$onsite = Read-Utf8NoBom $OnsitePath
$res = Add-Anchor-In-Scopes -Html $onsite -Href './sauce.html' -Label 'Go to Sauce Tasting'
$onsite = $res.Html
if ($res.Changed) {
  Write-Utf8NoBom $OnsitePath $onsite
  Write-Host "✅ On-site: added “Go to Sauce Tasting”."
} else {
  Write-Host "ℹ️ On-site: Sauce button already present (no change)."
}

# -----------------------------------------------------------------------------------
# 2) Sauce page: ensure all OTHER buttons exist; do NOT add the Sauce button
#    Required: Landing, On-Site, Blind Taste, Leaderboard
#    Optional: remove Sauce button if present (to avoid duplicates).
# -----------------------------------------------------------------------------------
Backup $SaucePath | Out-Null
$sauce = Read-Utf8NoBom $SaucePath

$targets = @(
  @{ href='./landing.html';     label='Go to Landing'      },
  @{ href='./onsite.html';      label='Go to On-Site'      },
  @{ href='./blind.html';       label='Go to Blind Taste'  },
  @{ href='./leaderboard.html'; label='Go to Leaderboard'  }
)

$changedAny = $false
foreach ($t in $targets) {
  $r = Add-Anchor-In-Scopes -Html $sauce -Href $t.href -Label $t.label
  $sauce = $r.Html
  if ($r.Changed) { $changedAny = $true }
}

# Make sure the Sauce button is NOT present on sauce page
$sauce = Remove-Anchor-In-Scopes -Html $sauce -Href './sauce.html'

if ($changedAny) {
  Write-Utf8NoBom $SaucePath $sauce
  Write-Host "✅ Sauce page: ensured Landing/On-Site/Blind/Leaderboard buttons; removed Sauce button if present."
} else {
  Write-Utf8NoBom $SaucePath $sauce
  Write-Host "ℹ️ Sauce page: buttons already present; removed Sauce button if it existed."
}
