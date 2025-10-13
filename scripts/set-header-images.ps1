param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$Left    = "Legion whole hog logo.png",
  [string]$Right   = "AL Medallion.png"
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

function ReplaceImgSrcById([string]$Html,[string]$Id,[string]$NewSrc){
  $patImg = "(?is)<img\b[^>]*\bid\s*=\s*[""']" + [regex]::Escape($Id) + "[""'][^>]*>"
  $m = [regex]::Match($Html, $patImg)
  if(-not $m.Success){ return $Html }
  $img = $m.Value
  $patSrc = '(?is)\bsrc\s*=\s*["''][^"''>]*["'']'
  $newImg = if([regex]::IsMatch($img,$patSrc)){ [regex]::Replace($img,$patSrc,'src="' + $NewSrc + '"',1) } else { $img -replace '(?is)^<img','<img src="' + $NewSrc + '"' }
  $Html.Substring(0,$m.Index) + $newImg + $Html.Substring($m.Index + $m.Length)
}

function ReplaceImgSrcByClass([string]$Html,[string]$ClassFrag,[string]$NewSrc){
  $patImg = "(?is)<img\b(?=[^>]*\bclass\b[^>]*\b" + [regex]::Escape($ClassFrag) + "\b)[^>]*>"
  $m = [regex]::Match($Html, $patImg)
  if(-not $m.Success){ return $Html }
  $img = $m.Value
  $patSrc = '(?is)\bsrc\s*=\s*["''][^"''>]*["'']'
  $newImg = if([regex]::IsMatch($img,$patSrc)){ [regex]::Replace($img,$patSrc,'src="' + $NewSrc + '"',1) } else { $img -replace '(?is)^<img','<img src="' + $NewSrc + '"' }
  $Html.Substring(0,$m.Index) + $newImg + $Html.Substring($m.Index + $m.Length)
}

function EnsureHeaderImgById([string]$Html,[string]$Id,[string]$NewSrc){
  $patHeader = '(?is)<header\b[^>]*>.*?</header>'
  $mh = [regex]::Match($Html,$patHeader)
  if(-not $mh.Success){ return $Html } # no header; do nothing
  $block = $mh.Value
  if([regex]::IsMatch($block, "(?is)<img\b[^>]*\bid\s*=\s*[""']" + [regex]::Escape($Id) + "[""']")){
    return $Html # already present (will be handled by Replace step)
  }
  # inject right after opening <header...>
  $newBlock = [regex]::Replace($block,'(?is)(<header\b[^>]*>)', '$1' + "<img id=""$Id"" src=""$NewSrc"" alt=""Logo"" />", 1)
  $Html.Substring(0,$mh.Index) + $newBlock + $Html.Substring($mh.Index + $mh.Length)
}

function EnsureHeaderImgByClass([string]$Html,[string]$ClassFrag,[string]$NewSrc){
  $patHeader = '(?is)<header\b[^>]*>.*?</header>'
  $mh = [regex]::Match($Html,$patHeader)
  if(-not $mh.Success){ return $Html }
  $block = $mh.Value
  if([regex]::IsMatch($block, "(?is)<img\b(?=[^>]*\bclass\b[^>]*\b" + [regex]::Escape($ClassFrag) + "\b)[^>]*>")){
    return $Html # already present
  }
  # inject before </header>
  $newBlock = [regex]::Replace($block,'(?is)</header>','<img class="' + $ClassFrag + '" src="' + $NewSrc + '" alt="Logo" /></header>',1)
  $Html.Substring(0,$mh.Index) + $newBlock + $Html.Substring($mh.Index + $mh.Length)
}

# Files to touch
$pages = @('landing.html','onsite.html','blind.html') | ForEach-Object { Join-Path $WebRoot $_ } | Where-Object { Test-Path -LiteralPath $_ }
if(-not $pages){ throw "No landing/onsite/blind pages found in $WebRoot" }

foreach($page in $pages){
  $html = Read-Text $page
  $orig = $html

  # ensure the images exist in the header (by id/class), then set srcs
  $html = EnsureHeaderImgById   $html 'logoLeft'  $Left
  $html = EnsureHeaderImgByClass $html 'right-img' $Right
  $html = ReplaceImgSrcById     $html 'logoLeft'  $Left
  $html = ReplaceImgSrcByClass  $html 'right-img' $Right

  if($html -ne $orig){
    Backup $page
    Write-Text $page $html
    Write-Host ("Patched images in {0}" -f (Split-Path $page -Leaf)) -ForegroundColor Green
  } else {
    Write-Host ("No change needed in {0}" -f (Split-Path $page -Leaf)) -ForegroundColor DarkGray
  }
}

Write-Host "`nDone. Hard-refresh the browser (Ctrl+F5). If an image still doesn't show, open DevTools → Network, check the 404 path, and tell me exactly what it is." -ForegroundColor Cyan
