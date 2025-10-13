# PowerShell 5.1 - set-header-height-225.ps1
param(
  [string]$WebRoot  = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$Landing  = "landing.html",
  [string]$Onsite   = "onsite.html",
  [string]$HeightIn = "2.25in"
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
  $bak = Join-Path $WebRoot ("BACKUP_header_" + $stamp)
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

function Patch-HeaderHeight([string]$HtmlPath,[string]$HeightIn){
  $html = Read-Text $HtmlPath

  # Regexes as literal here-strings (no interpolation)
  $patHeaderOpen = @'
(?is)<header\b[^>]*>
'@
  $patDivHeaderOpen = @'
(?is)<div\b[^>]*(?:id|class)\s*=\s*["\']([^"\']*)["\'][^>]*>
'@
  $patStyleAttr = @'
(?is)\bstyle\s*=\s*("|\')([^"\']*)\1
'@
  $patHeightRemove = @'
(?i)\bheight\s*:\s*[^;"]*;?
'@
  $patLineHeightRemove = @'
(?i)\bline-height\s*:\s*[^;"]*;?
'@

  $reHeaderOpen      = New-Object System.Text.RegularExpressions.Regex ($patHeaderOpen)
  $reDivHeaderOpen   = New-Object System.Text.RegularExpressions.Regex ($patDivHeaderOpen)
  $reStyleAttr       = New-Object System.Text.RegularExpressions.Regex ($patStyleAttr)
  $reHeightRemove    = New-Object System.Text.RegularExpressions.Regex ($patHeightRemove)
  $reLineHeightRemove= New-Object System.Text.RegularExpressions.Regex ($patLineHeightRemove)

  # 1) Try <header ...>
  $m = $reHeaderOpen.Match($html)

  # 2) Fallback: a div whose id/class contains "header" or "site-header"
  if(-not $m.Success){
    $mm = $reDivHeaderOpen.Match($html)
    while($mm.Success -and -not $m.Success){
      $val = $mm.Groups[1].Value
      if($val -match '(?i)\b(header|site-header)\b'){
        $m = $mm
        break
      }
      $mm = $mm.NextMatch()
    }
  }

  if(-not $m.Success){
    Write-Host ("No header-like opening tag found in {0} - skipped" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor DarkGray
    return $false
  }

  $openTag = $m.Value

  # Look for style="..."
  $styleMatch = $reStyleAttr.Match($openTag)

  if($styleMatch.Success){
    $style = $styleMatch.Groups[2].Value

    # Remove any existing height/line-height
    $style = $reHeightRemove.Replace($style, '')
    $style = $reLineHeightRemove.Replace($style, '')
    $style = $style.Trim()
    if($style.Length -gt 0 -and $style.Substring($style.Length-1) -ne ';'){ $style += ';' }

    $style += (' height:' + $HeightIn + '; line-height:' + $HeightIn + ';')

    # Rebuild the opening tag by replacing the style attribute content
    $quote = $styleMatch.Groups[1].Value
    $newOpen =
      $openTag.Substring(0, $styleMatch.Index) +
      ('style=' + $quote + $style.Trim() + $quote) +
      $openTag.Substring($styleMatch.Index + $styleMatch.Length)
  } else {
    # No style attr: inject before '>'
    $newOpen = [System.Text.RegularExpressions.Regex]::Replace(
      $openTag, '>$', (' style="height:' + $HeightIn + '; line-height:' + $HeightIn + ';">'), 1
    )
  }

  if($newOpen -ne $openTag){
    $newHtml = $html.Substring(0,$m.Index) + $newOpen + $html.Substring($m.Index + $openTag.Length)
    Write-Text $HtmlPath $newHtml
    Write-Host ("Set header height to {0} in {1}" -f $HeightIn, (Split-Path $HtmlPath -Leaf)) -ForegroundColor Cyan
    return $true
  } else {
    Write-Host ("Header already had requested height in {0}" -f (Split-Path $HtmlPath -Leaf)) -ForegroundColor DarkGray
    return $false
  }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }
$LandingHtml = Join-Path $WebRoot $Landing
$OnsiteHtml  = Join-Path $WebRoot $Onsite

$missing = @()
foreach($f in @($LandingHtml,$OnsiteHtml)){ if(-not (Test-Path $f)){ $missing += $f } }
if($missing.Count){ throw ("Missing required file(s):`r`n" + ($missing -join "`r`n")) }

Backup-Once @($Landing,$Onsite)

$ok1 = Patch-HeaderHeight $LandingHtml $HeightIn
$ok2 = Patch-HeaderHeight $OnsiteHtml  $HeightIn

Write-Host "`r`nDone. Press Ctrl+F5 to hard-refresh the browser." -ForegroundColor Green

