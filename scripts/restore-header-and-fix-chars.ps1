# PowerShell 7+
param(
  [string]$WebRoot   = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$LeftLogo  = "Legion whole hog logo.png",
  [string]$RightLogo = "AL Medallion.png"
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
function Ensure-MetaUtf8([string]$Html){
  if([regex]::IsMatch($Html,'(?is)<meta\s+charset\s*=\s*["'']?utf-8["'']?')){
    return $Html
  }
  return [regex]::Replace($Html,'(?is)(<head[^>]*>)','$1'+"`r`n  <meta charset=""utf-8"">",1)
}
function Fix-Mojibake([string]$Text){
  $map = @(
    @{bad="â€¦"; good="..."}   # ellipsis
    @{bad="â€“"; good="-"}     # en dash
    @{bad="â€”"; good="--"}    # em dash
    @{bad="â€˜"; good="'"}     # opening single
    @{bad="â€™"; good="'"}     # closing single
    @{bad="â€œ"; good='"'}     # opening double
    @{bad="â€"; good='"'}     # closing double
    @{bad="Â ";  good=" "}     # stray NBSP marker
    @{bad="Ã—";  good="x"}     # times sign occasionally
  )
  foreach($m in $map){ $Text = $Text.Replace($m.bad,$m.good) }
  return $Text
}
function Replace-Header([string]$Html,[string]$Title,[string]$LeftSrc,[string]$RightSrc){
  $header = @"
<header class="app-header">
  <img id="logoLeft" class="left-img" src="$LeftSrc" alt="Whole Hog">
  <h1>$Title</h1>
  <img class="right-img" src="$RightSrc" alt="American Legion">
</header>
"@
  if([regex]::IsMatch($Html,'(?is)<header\b[^>]*>.*?</header>')){
    return [regex]::Replace($Html,'(?is)<header\b[^>]*>.*?</header>',$header,1)
  }
  # no header found: inject after <body>
  return [regex]::Replace($Html,'(?is)(<body[^>]*>)','$1'+"`r`n$header",1)
}
function Ensure-HeaderCss([string]$Css){
  $marker = '/* WH header baseline */'
  if($Css -match [regex]::Escape($marker)){ return $Css }
$block = @"
$marker
.app-header{position:relative;display:flex;align-items:center;justify-content:center;min-height:2.25in;padding:8px 64px;background:transparent;}
.app-header h1{margin:0;text-align:center;font-weight:800;}
.app-header .left-img{position:absolute;left:12px;top:50%;transform:translateY(-50%);height:calc(100% - 16px);width:auto;display:block;}
.app-header .right-img{position:absolute;right:12px;top:50%;transform:translateY(-50%);height:calc(100% - 16px);width:auto;display:block;}
"@
  return $Css + "`r`n" + $block + "`r`n"
}

if(-not (Test-Path -LiteralPath $WebRoot)){ throw "Web root not found: $WebRoot" }

# Resolve image paths (relative from each page). If not found, keep file name (user may add later).
function Resolve-Img([string]$root,[string]$name){
  $p = Join-Path $root $name
  if(Test-Path -LiteralPath $p){ return $name }
  # search case-insensitive at root
  $f = Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $name }
  if($f){ return $f[0].Name }
  # as fallback, allow subfolders (we’ll write relative from page later)
  $f = Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $name }
  if($f){
    # return a path relative to the root; pages live at root so this is fine
    return [IO.Path]::GetRelativePath($root, $f[0].FullName)
  }
  return $name # best effort; user ensures file exists
}

$leftRel  = Resolve-Img $WebRoot $LeftLogo
$rightRel = Resolve-Img $WebRoot $RightLogo

# Pages we’ll patch (only if they exist)
$targets = @(
  @{file='landing.html'; title='Whole Hog Competition 2025'},
  @{file='onsite.html';  title='Whole Hog On-Site Scoring'},
  @{file='blind.html';   title='Blind Taste Scoring'}
) | ForEach-Object {
  $p = Join-Path $WebRoot $_.file
  if(Test-Path -LiteralPath $p){ @{path=$p; title=$_.title} }
}

if(-not $targets){ throw "No landing.html / onsite.html / blind.html found to patch." }

# Patch CSS once
$cssPath = Join-Path $WebRoot 'styles.css'
if(Test-Path -LiteralPath $cssPath){
  $css0 = Read-Text $cssPath
  $css1 = Ensure-HeaderCss $css0
  if($css1 -ne $css0){
    Backup $cssPath
    Write-Text $cssPath $css1
    Write-Host "Updated styles.css with header baseline." -ForegroundColor Green
  } else {
    Write-Host "styles.css already has header baseline." -ForegroundColor DarkGray
  }
} else {
  Write-Host "styles.css not found; skipping CSS add." -ForegroundColor Yellow
}

# Patch each page
foreach($t in $targets){
  $file = $t.path; $title = $t.title
  $html0 = Read-Text $file
  $html1 = Ensure-MetaUtf8 $html0
  $html1 = Fix-Mojibake $html1
  $html1 = Replace-Header $html1 $title $leftRel $rightRel
  if($html1 -ne $html0){
    Backup $file
    Write-Text $file $html1
    Write-Host ("Patched header + encoding in {0}" -f (Split-Path $file -Leaf)) -ForegroundColor Green
  } else {
    Write-Host ("No change needed for {0}" -f (Split-Path $file -Leaf)) -ForegroundColor DarkGray
  }
}

Write-Host "`nDone. Hard-refresh your browser (Ctrl+F5)." -ForegroundColor Cyan
