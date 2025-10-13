param(
  [Parameter(Mandatory=$true)] [string]$BlindPath
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
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
  return $bak
}

# Helper: insert $insertion inside a regex match's inner group
function Insert-In-Match {
  param(
    [string]$Html,
    [System.Text.RegularExpressions.Match]$Match,
    [string]$Insertion
  )
  $open  = $Match.Groups[1].Value
  $inner = $Match.Groups[2].Value
  $close = $Match.Groups[3].Value
  $newInner = $inner.TrimEnd() + "`r`n  " + $Insertion + "`r`n"
  $newBlock = $open + $newInner + $close
  $prefix = $Html.Substring(0, $Match.Index)
  $suffix = $Html.Substring($Match.Index + $Match.Length)
  return $prefix + $newBlock + $suffix
}

if (!(Test-Path $BlindPath)) { throw "File not found: $BlindPath" }

$anchor   = '<a href="./sauce.html">Go to Sauce Tasting</a>'
$navScope = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
$topScope = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'

$html = Read-Utf8NoBom $BlindPath

# If already present, do nothing
if ($html -match '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
  Write-Host "ℹ️ Sauce button already present. No change."
  exit 0
}

$changed = $false
$m = [regex]::Match($html, $navScope)
if ($m.Success) {
  Backup $BlindPath | Out-Null
  $html = Insert-In-Match -Html $html -Match $m -Insertion $anchor
  $changed = $true
} else {
  $m2 = [regex]::Match($html, $topScope)
  if ($m2.Success) {
    Backup $BlindPath | Out-Null
    $html = Insert-In-Match -Html $html -Match $m2 -Insertion $anchor
    $changed = $true
  }
}

if ($changed) {
  Write-Utf8NoBom $BlindPath $html
  Write-Host "✅ Added “Go to Sauce Tasting” to $BlindPath (will align with existing nav styles)."
} else {
  Write-Host "⚠️ Couldn’t find a known nav container (id=""wholehog-nav"" or id=""top-go-buttons""). No changes made."
}
