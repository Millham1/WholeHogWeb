# PowerShell 5.1 — force-header-padding-fix.ps1
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup-Once([string[]]$Files){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $WebRoot ("BACKUP_header_inline_" + $stamp)
  $did = $false
  foreach($f in $Files){
    $p = Join-Path $WebRoot $f
    if(Test-Path $p){
      if(-not $did){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $did = $true }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($did){ Write-Host ("Backup saved to {0}" -f $bak) -ForegroundColor Yellow }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'

$missing = @()
foreach($f in @($LandingHtml,$OnsiteHtml)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`r`n" + ($missing -join "`r`n")) }

Backup-Once @('landing.html','onsite.html')

function Patch-HeaderInline([string]$HtmlPath){
  $html = Read-Text $HtmlPath

  # 1) Find a real <header ...>
  $reHeader = New-Object System.Text.RegularExpressions.Regex '(?is)<header\b[^>]*>'
  $m = $reHeader.Match($html)

  # 2) Fallback: a <div ...> with id/class containing "header" or "site-header"
  if(-not $m.Success){
    $reDivHeader = New-Object System.Text.RegularExpressions.Regex '(?is)<div\b[^>]*(?:id|class)\s*=\s*["''][^>"'']*\b(?:header|site-header)\b[^>]*>'
    $m = $reDivHeader.Match($html)
  }

  if(-not $m.Success){
    Write-Host ("No header-like tag found in {0} - skipped" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor DarkGray
    return $false
  }

  $openTag = $m.Value  # the opening tag (<header ...> or <div ...>)

  # Look for style="..."
  $reStyle = New-Object System.Text.RegularExpressions.Regex '(?is)\bstyle\s*=\s*(["''])([^"'']*)\1'
  $styleMatch = $reStyle.Match($openTag)

  $appendCss = 'padding-top:0.375in; padding-bottom:0.375in; box-sizing:border-box;'

  if($styleMatch.Success){
    $styleBody = $styleMatch.Groups[2].Value
    $needsTop    = ($styleBody -notmatch '(?i)\bpadding-top\s*:\s*0\.375in\b')
    $needsBottom = ($styleBody -notmatch '(?i)\bpadding-bottom\s*:\s*0\.375in\b')
    $needsBox    = ($styleBody -notmatch '(?i)\bbox-sizing\s*:\s*border-box\b')

    if($needsTop -or $needsBottom -or $needsBox){
      if($needsTop){    $styleBody += ' padding-top:0.375in;' }
      if($needsBottom){ $styleBody += ' padding-bottom:0.375in;' }
      if($needsBox){    $styleBody += ' box-sizing:border-box;' }
      # Replace the whole style attribute using the captured current content ($2)
      $newOpenTag = [System.Text.RegularExpressions.Regex]::Replace(
        $openTag,
        '(?is)\bstyle\s*=\s*(["''])([^"'']*)\1',
        'style="$2"',
        1
      )
      # Now put the merged styleBody back (ensuring one space then our styles)
      $newOpenTag = $newOpenTag -replace 'style="([^"]*)"', ('style="' + ($styleBody.Trim()) + '"')
    } else {
      $newOpenTag = $openTag
    }
  } else {
    # No style attribute: insert one before '>'
    $newOpenTag = $openTag -replace '>$', (' style="' + $appendCss + '">')
  }

  if($newOpenTag -ne $openTag){
    $newHtml = $html.Substring(0,$m.Index) + $newOpenTag + $html.Substring($m.Index + $openTag.Length)
    Write-Text $HtmlPath $newHtml
    Write-Host ("Updated header inline styles in {0}" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor Cyan
    return $true
  } else {
    Write-Host ("Header styles already present in {0}" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor DarkGray
    return $false
  }
}

$ok1 = Patch-HeaderInline $LandingHtml
$ok2 = Patch-HeaderInline $OnsiteHtml

Write-Host "`r`nDone. Hard refresh (Ctrl+F5) to see the taller header." -ForegroundColor Green

