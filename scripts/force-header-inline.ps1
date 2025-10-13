param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$HeaderHeight = "2.25in",
  [string]$LeftImg  = "Legion whole hog logo.png",
  [string]$RightImg = "AL Medallion.png"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path)){ throw "File not found: $Path" }
  return [System.IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  [System.IO.File]::WriteAllText($Path,$Content,[Text.Encoding]::UTF8)
}
function Backup-Once([string]$Path){
  $bak = "$Path.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  Copy-Item -LiteralPath $Path -Destination $bak -Force
  Write-Host "Backup: $bak" -ForegroundColor Yellow
}

function Build-HeaderHtml([string]$Title){
  $left  = $LeftImg
  $right = $RightImg
  $h = @"
<header class="app-header" style="height:$HeaderHeight; min-height:$HeaderHeight; line-height:$HeaderHeight; display:flex; align-items:center; justify-content:center; position:relative;">
  <img id="logoLeft" src="$left" alt="Whole Hog" style="position:absolute; left:14px; top:50%; transform:translateY(-50%); height:calc(100% - 18px); width:auto;" />
  <h1 style="margin:0; font-weight:800; text-align:center; line-height:normal;">$Title</h1>
  <img class="right-img" src="$right" alt="American Legion" style="position:absolute; right:14px; top:50%; transform:translateY(-50%); height:calc(100% - 18px); width:auto;" />
</header>
"@
  return $h
}

function Force-Header([string]$FilePath,[string]$Title){
  $html = Read-Text $FilePath
  $orig = $html

  $headerNew = Build-HeaderHtml $Title

  # Find existing <header ...>...</header>
  $start = $html.IndexOf("<header",[System.StringComparison]::OrdinalIgnoreCase)
  if($start -ge 0){
    $end = $html.IndexOf("</header>", $start, [System.StringComparison]::OrdinalIgnoreCase)
    if($end -ge 0){ $end += 9 } else { $end = $start }  # if no closing tag, replace from start
    $html = $html.Substring(0,$start) + $headerNew + $html.Substring($end)
  } else {
    # Insert right after opening <body ...>
    $bStart = $html.IndexOf("<body",[System.StringComparison]::OrdinalIgnoreCase)
    if($bStart -ge 0){
      $gt = $html.IndexOf(">", $bStart)
      if($gt -ge 0){
        $insPos = $gt+1
        $html = $html.Substring(0,$insPos) + "`r`n" + $headerNew + "`r`n" + $html.Substring($insPos)
      } else {
        # No '>' after <body — prepend as a last resort
        $html = $headerNew + "`r`n" + $html
      }
    } else {
      # No <body> tag — prepend as a last resort
      $html = $headerNew + "`r`n" + $html
    }
  }

  if($html -ne $orig){
    Backup-Once $FilePath
    Write-Text $FilePath $html
    Write-Host ("Updated header in {0}" -f (Split-Path $FilePath -Leaf)) -ForegroundColor Cyan
  } else {
    Write-Host ("No header change in {0}" -f (Split-Path $FilePath -Leaf)) -ForegroundColor DarkGray
  }
}

# ---- run on pages that exist
$landing = Join-Path $WebRoot 'landing.html'
$onsite  = Join-Path $WebRoot 'onsite.html'
$blind   = Join-Path $WebRoot 'blind.html'

if(Test-Path $landing){ Force-Header $landing "Whole Hog Competition 2025" }
if(Test-Path $onsite ){ Force-Header $onsite  "Whole Hog On-Site Scoring" }
if(Test-Path $blind  ){ Force-Header $blind   "Blind Taste Scoring" }

Write-Host "`nDone. Press Ctrl+F5 in the browser to hard-refresh." -ForegroundColor Green
