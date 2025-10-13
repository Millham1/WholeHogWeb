param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$HeaderHeight = "2.25in"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  [IO.File]::WriteAllText($Path,$Content,[Text.Encoding]::UTF8)
}
function Backup([string]$Path){
  $bak = "$Path.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  Copy-Item -LiteralPath $Path -Destination $bak -Force
  Write-Host "Backup: $bak" -ForegroundColor Yellow
}

if(-not (Test-Path -LiteralPath $WebRoot)){ throw "Web root not found: $WebRoot" }

# Remove my known CSS marker blocks from an HTML string
function Remove-InjectedHtmlCss([string]$html){
  $blocks = @(
    @('<\!-- WH HARD HEADER START -->','<\!-- WH HARD HEADER END -->')
  )
  foreach($b in $blocks){
    $start = $b[0]; $end = $b[1]
    $si = $html.IndexOf($start,[StringComparison]::OrdinalIgnoreCase)
    $ei = $html.IndexOf($end,[StringComparison]::OrdinalIgnoreCase)
    if($si -ge 0 -and $ei -gt $si){
      $ei += $end.Length
      $html = $html.Substring(0,$si) + $html.Substring($ei)
    }
  }
  return $html
}

# Remove my known CSS marker sections from styles.css
function Clean-StylesCss([string]$css){
  $markers = @(
    '/* WH: header & primary buttons overrides */',
    '/* === WHOLEHOG header logo centering === */',
    '/* WH: blind scoring add-ons */'
  )
  foreach($m in $markers){
    $si = $css.IndexOf($m,[StringComparison]::OrdinalIgnoreCase)
    if($si -ge 0){
      # remove from marker to the end of that comment block (next */) or line break cluster
      $tail = $css.Substring($si)
      $endIdx = $tail.IndexOf('*/')
      if($endIdx -ge 0){
        $endIdx += 2
        $css = $css.Substring(0,$si) + $tail.Substring($endIdx)
      } else {
        # marker without closing: remove marker line
        $nl = $css.IndexOf("`n",$si)
        if($nl -ge 0){ $css = $css.Substring(0,$si) + $css.Substring($nl+1) }
        else { $css = $css.Substring(0,$si) }
      }
    }
  }
  return $css
}

# Replace the first <header>…</header> with a clean, consistent header
function Rebuild-Header([string]$html,[string]$defaultTitle){
  # Use the <title> if present
  $title = $defaultTitle
  $mTitle = [regex]::Match($html,'(?is)<title[^>]*>\s*(.*?)\s*</title>')
  if($mTitle.Success -and $mTitle.Groups[1].Value.Trim()){
    $title = $mTitle.Groups[1].Value.Trim()
  }

  $newHeader = @"
<header class="header" style="height:$HeaderHeight; min-height:$HeaderHeight; position:relative; display:flex; align-items:center; justify-content:center;">
  <img id="logoLeft" src="Legion whole hog logo.png" alt="Whole Hog"
       style="position:absolute; left:14px; top:50%; transform:translateY(-50%); height:calc(100% - 20px); width:auto;">
  <h1 style="margin:0; text-align:center;">$title</h1>
  <img class="right-img" src="AL Medallion.png" alt="American Legion"
       style="position:absolute; right:14px; top:50%; transform:translateY(-50%); height:calc(100% - 20px); width:auto;">
</header>
"@

  $mHeader = [regex]::Match($html,'(?is)<header\b[^>]*>.*?</header>')
  if($mHeader.Success){
    $start = $mHeader.Index
    $len   = $mHeader.Length
    return $html.Substring(0,$start) + $newHeader + $html.Substring($start+$len)
  } else {
    # No header found — inject right after <body>
    $mBody = [regex]::Match($html,'(?is)<body\b[^>]*>')
    if($mBody.Success){
      $insAt = $mBody.Index + $mBody.Length
      return $html.Substring(0,$insAt) + "`r`n" + $newHeader + "`r`n" + $html.Substring($insAt)
    }
    # fallback: prepend
    return $newHeader + "`r`n" + $html
  }
}

# Process pages
$pages = @()
foreach($name in @('landing.html','onsite.html','blind.html')){
  $p = Join-Path $WebRoot $name
  if(Test-Path -LiteralPath $p){ $pages += $p }
}

if(-not $pages.Count){ throw "No pages (landing/onsite/blind) found in $WebRoot" }

foreach($page in $pages){
  $html = Read-Text $page
  $orig = $html

  # 1) strip my injected header CSS blocks from this HTML, if any
  $html = Remove-InjectedHtmlCss $html

  # 2) rebuild header with consistent structure & 2.25in height
  $defaultTitle = if($page -like "*landing.html"){ "Whole Hog Competition 2025" }
                  elseif($page -like "*onsite.html"){ "Whole Hog On-Site Scoring" }
                  else { "Blind Taste Scoring" }

  $html = Rebuild-Header $html $defaultTitle

  if($html -ne $orig){
    Backup $page
    Write-Text $page $html
    Write-Host ("Patched header in {0}" -f (Split-Path $page -Leaf)) -ForegroundColor Cyan
  } else {
    Write-Host ("No header change in {0}" -f (Split-Path $page -Leaf)) -ForegroundColor DarkGray
  }
}

# 3) clean styles.css markers (if present)
$cssPath = Join-Path $WebRoot "styles.css"
if(Test-Path -LiteralPath $cssPath){
  $css = Read-Text $cssPath
  $clean = Clean-StylesCss $css
  if($clean -ne $css){
    Backup $cssPath
    Write-Text $cssPath $clean
    Write-Host "Cleaned styles.css markers" -ForegroundColor Cyan
  } else {
    Write-Host "styles.css unchanged" -ForegroundColor DarkGray
  }
} else {
  Write-Host "styles.css not found (skipped)" -ForegroundColor DarkGray
}

Write-Host "`nDone. Press Ctrl+F5 on each page to bypass cache." -ForegroundColor Green
