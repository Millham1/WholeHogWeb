param(
  [Parameter(Mandatory=$true)] [string]$LandingPath,
  [Parameter(Mandatory=$true)] [string]$OnsitePath,
  [Parameter(Mandatory=$true)] [string]$BlindPath,
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
  if (!(Test-Path $p)) { return $null }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $bak = "$p.$stamp.bak"
  Copy-Item $p $bak -Force
  Write-Host "🔒 Backup: $bak"
  return $bak
}

$SauceAnchor = '<a href="./sauce.html">Go to Sauce Tasting</a>'

function Ensure-NavStyle-Landing([string]$html){
  if ($html -notmatch '(?is)id\s*=\s*["'']wh-nav-landing-override["'']') {
    $style = @'
<style id="wh-nav-landing-override">
  #wholehog-nav{
    max-width: 820px;
    margin: 12px auto;
    display:flex; justify-content:center; align-items:center;
    gap:12px; flex-wrap:wrap; text-align:center;
  }
  #wholehog-nav a, #top-go-buttons a{
    display:inline-flex; align-items:center; justify-content:center; white-space:nowrap;
    padding:10px 14px; border-radius:10px;
    background:#e53935 !important; color:#000 !important;
    font-weight:800 !important; border:2px solid #000 !important;
    text-decoration:none; min-width:180px;
  }
  #wholehog-nav a:hover, #top-go-buttons a:hover{ filter:brightness(0.92); }
</style>
'@
    if ($html -match '(?is)</head\s*>') {
      $html = [regex]::Replace($html, '(?is)</head\s*>', ($style + "`r`n</head>"), 1)
    } else {
      $html = $style + $html
    }
  }
  return $html
}

function Add-Sauce-Button([string]$html){
  $changed = $false
  $anchor = $SauceAnchor   # capture for callback

  $navPat = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
  if ([regex]::IsMatch($html, $navPat)) {
    $html = [regex]::Replace($html, $navPat, {
      param($m)
      $open = $m.Groups[1].Value
      $inner = $m.Groups[2].Value
      $close = $m.Groups[3].Value
      if ($inner -notmatch '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
        $inner = $inner.Trim() + "`r`n  $anchor`r`n"
        $script:changed = $true
      }
      return $open + $inner + $close
    }, 1)
  } else {
    $topPat = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'
    if ([regex]::IsMatch($html, $topPat)) {
      $html = [regex]::Replace($html, $topPat, {
        param($m)
        $open = $m.Groups[1].Value
        $inner = $m.Groups[2].Value
        $close = $m.Groups[3].Value
        if ($inner -match '(?is)<a\b' -and $inner -notmatch '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
          $inner = $inner.Trim() + "`r`n  $anchor`r`n"
          $script:changed = $true
        }
        return $open + $inner + $close
      }, 1)
    }
  }

  # Add style override once if we touched nav (we can't reliably read $changed outside the callback in all PS versions)
  if ($html -notmatch '(?is)id\s*=\s*["'']sauce-nav-override["'']') {
    # Only add if sauce link is present now (means we changed or it already existed)
    if ($html -match '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
      $style = @'
<style id="sauce-nav-override">
  #wholehog-nav{
    max-width: 820px;
    margin: 12px auto;
    display:flex; justify-content:center; align-items:center; gap:12px; flex-wrap:wrap; text-align:center;
  }
  #wholehog-nav a, #top-go-buttons a{
    display:inline-flex; align-items:center; justify-content:center; white-space:nowrap;
    padding:10px 14px; border-radius:10px; background:#e53935 !important; color:#000 !important;
    font-weight:800 !important; border:2px solid #000 !important; text-decoration:none; min-width:180px;
  }
  #wholehog-nav a:hover, #top-go-buttons a:hover{ filter:brightness(0.92); }
</style>
'@
      if ($html -match '(?is)</head\s*>') {
        $html = [regex]::Replace($html, '(?is)</head\s*>', ($style + "`r`n</head>"), 1)
      } else {
        $html = $style + $html
      }
    }
  }
  return $html
}

function Remove-Sauce-Button([string]$html){
  $rmPat = '(?is)\s*<a\b[^>]*\bhref\s*=\s*["'']\./sauce\.html["''][^>]*>.*?</a>\s*'

  $navScope = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
  if ([regex]::IsMatch($html, $navScope)) {
    $pattern = $rmPat
    $html = [regex]::Replace($html, $navScope, {
      param($m)
      $open = $m.Groups[1].Value
      $inner = [regex]::Replace($m.Groups[2].Value, $pattern, '')
      $close = $m.Groups[3].Value
      return $open + $inner + $close
    }, 1)
  }

  $topScope = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'
  if ([regex]::IsMatch($html, $topScope)) {
    $pattern = $rmPat
    $html = [regex]::Replace($html, $topScope, {
      param($m)
      $open = $m.Groups[1].Value
      $inner = [regex]::Replace($m.Groups[2].Value, $pattern, '')
      $close = $m.Groups[3].Value
      return $open + $inner + $close
    }, 1)
  }
  return $html
}

# ----- Apply the exact requested nav tweaks -----

# Landing: center + red buttons; ensure Sauce present
Backup $LandingPath | Out-Null
$landing = Read-Utf8NoBom $LandingPath
$landing = Ensure-NavStyle-Landing $landing
if ($landing -notmatch '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
  $landing = Add-Sauce-Button $landing
}
Write-Utf8NoBom $LandingPath $landing
Write-Host "✅ Landing updated (centered red buttons; Sauce button ensured)."

# On-site: add Sauce button if missing
Backup $OnsitePath | Out-Null
$onsite = Read-Utf8NoBom $OnsitePath
if ($onsite -notmatch '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
  $onsite = Add-Sauce-Button $onsite
  Write-Utf8NoBom $OnsitePath $onsite
  Write-Host "✅ On-site updated (Sauce button added)."
} else {
  Write-Host "ℹ️ On-site already had Sauce button."
}

# Blind: add Sauce button if missing
Backup $BlindPath | Out-Null
$blind = Read-Utf8NoBom $BlindPath
if ($blind -notmatch '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
  $blind = Add-Sauce-Button $blind
  Write-Utf8NoBom $BlindPath $blind
  Write-Host "✅ Blind updated (Sauce button added)."
} else {
  Write-Host "ℹ️ Blind already had Sauce button."
}

# Sauce page: remove Sauce button
Backup $SaucePath | Out-Null
$sauce = Read-Utf8NoBom $SaucePath
if ($sauce -match '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
  $sauce = Remove-Sauce-Button $sauce
  Write-Utf8NoBom $SaucePath $sauce
  Write-Host "✅ Sauce page updated (Sauce button removed)."
} else {
  Write-Host "ℹ️ Sauce page had no Sauce button (nothing to remove)."
}
