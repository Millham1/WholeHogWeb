param(
  [string]$WebRoot     = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  # If you know the exact filenames, you can set them; otherwise the script will search.
  [string]$PreferLeft  = "",   # e.g. "Legion whole hog logo.png"
  [string]$PreferRight = ""    # e.g. "AL Medallion.png"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path -LiteralPath $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup([string]$Path){
  $bak = "$Path.bak_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  Copy-Item -LiteralPath $Path -Destination $bak -Force
  Write-Host "Backup: $bak" -ForegroundColor Yellow
}
function Get-RelUrl([string]$FullPath){
  $rel = $FullPath.Substring($WebRoot.Length).TrimStart('\','/')
  $rel -replace '\\','/'
}
function Find-BestImage([string[]]$Hints){
  $paths = @($WebRoot, (Join-Path $WebRoot 'images'), (Join-Path $WebRoot 'img')) |
           Where-Object { Test-Path -LiteralPath $_ }
  if(-not $paths){ return $null }
  $cands = foreach($p in $paths){
    Get-ChildItem -LiteralPath $p -File -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|gif|webp)$' }
  }
  if(-not $cands){ return $null }
  $best = $null; $scoreBest = -1
  foreach($f in $cands){
    $name = $f.Name.ToLowerInvariant()
    $score = 0
    foreach($h in $Hints){ if($name -like "*$h*"){ $score++ } }
    if($score -gt $scoreBest){ $best = $f; $scoreBest = $score }
  }
  $best
}
function RegexReplaceFirst([string]$Input,[string]$Pattern,[string]$Replacement){
  $rx = [regex]::new($Pattern, 'IgnoreCase, Singleline')
  $rx.Replace($Input, $Replacement, 1)
}
function Replace-ImgSrc-ById([string]$Html, [string]$ImgId, [string]$NewSrc){
  $patImg = "(?is)<img\b[^>]*\bid\s*=\s*[""']" + [regex]::Escape($ImgId) + "[""'][^>]*>"
  $rxImg  = [regex]::new($patImg, 'IgnoreCase, Singleline')
  $m = $rxImg.Match($Html)
  if(-not $m.Success){ return $Html }
  $img = $m.Value
  $patSrc = '(?is)\bsrc\s*=\s*["''][^"''"]*["'']'
  if([regex]::new($patSrc,'IgnoreCase, Singleline').IsMatch($img)){
    $newImg = RegexReplaceFirst $img $patSrc ('src="' + $NewSrc + '"')
  } else {
    $newImg = ($img -replace '(?is)^<img','<img src="' + $NewSrc + '"')
  }
  $Html.Substring(0,$m.Index) + $newImg + $Html.Substring($m.Index + $m.Length)
}
function Replace-ImgSrc-ByClass([string]$Html, [string]$ClassFrag, [string]$NewSrc){
  $patImg = "(?is)<img\b(?=[^>]*\bclass\b[^>]*\b" + [regex]::Escape($ClassFrag) + "\b)[^>]*>"
  $rxImg  = [regex]::new($patImg, 'IgnoreCase, Singleline')
  $m = $rxImg.Match($Html)
  if(-not $m.Success){ return $Html }
  $img = $m.Value
  $patSrc = '(?is)\bsrc\s*=\s*["''][^"''"]*["'']'
  if([regex]::new($patSrc,'IgnoreCase, Singleline').IsMatch($img)){
    $newImg = RegexReplaceFirst $img $patSrc ('src="' + $NewSrc + '"')
  } else {
    $newImg = ($img -replace '(?is)^<img','<img src="' + $NewSrc + '"')
  }
  $Html.Substring(0,$m.Index) + $newImg + $Html.Substring($m.Index + $m.Length)
}

# Resolve image files
$leftPath  = $null
$rightPath = $null
if($PreferLeft){
  $p = Join-Path $WebRoot $PreferLeft
  if(Test-Path -LiteralPath $p){ $leftPath = $p }
}
if(-not $leftPath){
  $g = Find-BestImage @('legion','hog','logo','pig')
  if($g){ $leftPath = $g.FullName }
}
if($PreferRight){
  $p = Join-Path $WebRoot $PreferRight
  if(Test-Path -LiteralPath $p){ $rightPath = $p }
}
if(-not $rightPath){
  $g = Find-BestImage @('medallion','legion','american','al')
  if($g){ $rightPath = $g.FullName }
}

if($leftPath){  Write-Host "Left logo -> $(Get-RelUrl $leftPath)" -ForegroundColor Cyan }  else { Write-Host "Left logo not found." -ForegroundColor Red }
if($rightPath){ Write-Host "Right logo -> $(Get-RelUrl $rightPath)" -ForegroundColor Cyan } else { Write-Host "Right logo not found." -ForegroundColor Red }

$pages = @('landing.html','onsite.html','blind.html') | ForEach-Object { Join-Path $WebRoot $_ } | Where-Object { Test-Path -LiteralPath $_ }
if(-not $pages){ throw "No landing/onsite/blind pages found in $WebRoot" }

foreach($page in $pages){
  $html = Read-Text $page
  $orig = $html
  if($leftPath){  $html = Replace-ImgSrc-ById    $html 'logoLeft'  (Get-RelUrl $leftPath) }
  if($rightPath){ $html = Replace-ImgSrc-ByClass $html 'right-img' (Get-RelUrl $rightPath) }
  if($html -ne $orig){
    Backup $page
    Write-Text $page $html
    Write-Host ("Patched image paths in {0}" -f (Split-Path $page -Leaf)) -ForegroundColor Green
  } else {
    Write-Host ("No image-path changes needed in {0}" -f (Split-Path $page -Leaf)) -ForegroundColor DarkGray
  }
}

Write-Host "`nDone. Press Ctrl+F5 in the browser. If a logo is still missing, open DevTools → Network and tell me the exact 404 path it tries." -ForegroundColor Green

