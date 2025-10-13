param(
  [Parameter(Mandatory=$true)] [string]$BlindPath
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p,[string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p,$s,$enc)
}
function Backup([string]$p){
  if (!(Test-Path $p)) { throw "File not found: $p" }
  $bak = "$p.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
  Copy-Item $p $bak -Force | Out-Null
  Write-Host "🔒 Backup: $bak"
}

if (!(Test-Path $BlindPath)) { throw "File not found: $BlindPath" }

$anchor = '<a href="./sauce.html">Go to Sauce Tasting</a>'
$navScope = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
$topScope = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'

$html = Read-Utf8NoBom $BlindPath

# If already present, nothing to do
if ($html -match '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
  Write-Host "ℹ️ Sauce button already present. No change."
  exit 0
}

function Insert-In-Match($html, $match, $insertion){
  $open  = $match.Groups[1].Value
  $inner = $match.Groups[2].Value
  $close = $match.Groups[3].Value
  $newInner = $inner.TrimEnd() + "`r`n  " + $insertion + "`r`n"
  $newBlock = $open + $newInne
