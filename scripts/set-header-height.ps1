# PowerShell 5.1 — set-header-height.ps1
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [double]$Inches  = 2.25
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
  $bak = Join-Path $WebRoot ("BACKUP_headerheight_" + $stamp)
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

$heightVal = ("{0:0.###}" -f $Inches) + "in"

function Patch-HeaderHeight([string]$HtmlPath,[string]$HeightIn){
  $html = Read-Text $HtmlPath

  # Find <header ...> opening tag
  $reHeader = New-Object System.Text.RegularExpressions.Regex '(?is)<header\b[^>]*>'
  $m = $reHeader.Match($html)

  # Fallback: <div ... id/class ... header|site-header ...>
  if(-not $m.Success){
    $reDivHeader = New-Object System.Text.RegularExpressions.Regex '(?is)<div\b[^>]*(?:id|class)\s*=\s*["''][^"'']*\b(?:header|site-header)\b[^"'']*["''][^>]*>'
    $m = $reDivHeader.Match($html)
  }

  if(-not $m.Success){
    Write-Host ("No header-like opening tag found in {0} - skipped" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor DarkGray
    return $false
  }

  $openTag = $m.Value

  # Find/replace style="..."
  $reStyle = New-Object System.Text.RegularExpressions.Regex '(?is)\bstyle\s*=\s*(["''])([^"'']*)\1'
  $styleMatch = $reStyle.Match($openTag)

  if($styleMatch.Success){
    $styleBody = $styleMatch.Groups[2].Value

    # Remove any existing height/line-height declarations, then append ours
    $styleBody = [System.Text.RegularExpressions.Regex]::Replace($styleBody, '(?i)\bheight\s*:\s*[^;"]*;?', '')
    $styleBody = [System.Text.RegularExpressions.Regex]::Replace($styleBody, '(?i)\bline-height\s*:\s*[^;"]*;?', '')

    # Ensure trailing semicolon if non-empty
    if($styleBody.Trim().Length -gt 0 -and $styleBody.Trim().Substring($styleBody.Trim().Length-1) -ne ';'){
      $styleBody = $styleBody.Trim() + '; '
    }

    $styleBody = $styleBody + ('height:' + $HeightIn + '; line-height:' + $HeightIn + ';')

    # Replace the style attribute content
    $newOpenTag = [System.Text.RegularExpressions.Regex]::Replace(
      $openTag,
      '(?is)\bstyle\s*=\s*(["''])([^"'']*)\1',
      'style="$2"',
      1
    )
    $newOpenTag = $newOpenTag -replace 'style="([^"]*)"', ('style="' + ($styleBody.Trim()) + '"')

  } else {
    # No style attribute: add one before '>'
    $newOpenTag = $openTag -replace '>$', (' style="height:' + $HeightIn + '; line-height:' + $HeightIn + ';">')
  }

  if($newOpenTag -ne $openTag){
    $newHtml = $html.Substring(0,$m.Index) + $newOpenTag + $html.Substring($m.Index + $openTag.Length)
    Write-Text $HtmlPath $newHtml
    Write-Host ("Set header height to {0} in {1}" -f $HeightIn, (Split-Path $HtmlPath -Leaf)) -ForegroundColor Cyan
    return $true
  } else {
    Write-Host ("Header already had requested height in {0}" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor DarkGray
    return $false
  }
}

$ok1 = Patch-HeaderHeight $LandingHtml $heightVal
$ok2 = Patch-HeaderHeight $OnsiteHtml  $heightVal

Write-Host "`r`nDone. Hard refresh (Ctrl+F5) to see the 2.25in header." -ForegroundColor Green
