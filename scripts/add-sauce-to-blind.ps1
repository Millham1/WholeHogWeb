param(
  [Parameter(Mandatory=$true)] [string]$BlindPath
)

function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p, [string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $s, $enc)
}
function Backup([string]$p){
  if (!(Test-Path $p)) { throw "File not found: $p" }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $bak = "$p.$stamp.bak"
  Copy-Item $p $bak -Force | Out-Null
  return $bak
}

# Anchor to insert
$anchor = '<a href="./sauce.html">Go to Sauce Tasting</a>'

# Patterns for common nav containers
$navScope = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
$topScope = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'

# Read + backup
$bak = Backup $BlindPath
Write-Host "🔒 Backup created: $bak"
$html = Read-Utf8NoBom $BlindPath

# If the Sauce button already exists, do nothing
if ($html -match '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
  Write-Host "ℹ️ Sauce button already present. No change."
  exit 0
}

$changed = $false

# Prefer inserting inside <nav id="wholehog-nav">
if ([regex]::IsMatch($html, $navScope)) {
  $html = [regex]::Replace($html, $nav
