param(
  [string]$Root = ".",
  [string]$File = "onsite.html"
)

# ---------------- IO helpers ----------------
function Read-FileUtf8NoBom([string]$path) {
  return [System.IO.File]::ReadAllText((Resolve-Path $path), (New-Object System.Text.UTF8Encoding($false)))
}
function Write-FileUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

# ---------------- Paths & backup -------------
$path = Join-Path $Root $File
if (!(Test-Path $path)) { throw "File not found: $path" }

$backupDir = Join-Path $Root "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Copy-Item $path (Join-Path $backupDir ("{0}_{1}" -f $File,$stamp))

# ---------------- Read file ------------------
$html = Read-FileUtf8NoBom $path

# ---------------- Patterns (double-quoted; escape " as `") ----------------
$patNavBlock        = "(?is)<nav\b[^>]*id\s*=\s*[`"']top-go-buttons[`"'][^>]*>.*?</nav>"
$patHeaderClose     = "(?is)</header>"
$patBodyOpen        = "(?is)<body\b[^>]*>"
$patHeadClose       = "(?is)</head>"
$patHomeAnchor      = "(?is)<a\b[^>]*id\s*=\s*[`"']go-home[`"'][^>]*>.*?</a>\s*"
$patHasScoring      = "(?is)\bid\s*=\s*[`"']scoring-card[`"']"
$patOverrideStyleId = "(?is)<style\b[^>]*id\s*=\s*[`"']onsite-overrides[`"']"

# ---------------- Ensure one nav -------------
$navMatches = [regex]::Matches($html, $patNavBlock)
if ($navMatches.Count -gt 1) {
  $firstNav = $navMatches[0].Value
  # Remove all navs
  $html = [regex]::Replace($html, $patNavBlock, "")
  # Reinsert after </header> or <body ...> or prepend
  $mHeader = [regex]::Match($html, $patHeaderClose)
  if ($mHeader.Success) {
    $insertAt = $mHeader.Index + $mHeader.Length
    $html = $html.Substring(0,$insertAt) + "`r`n" + $firstNav + $html.Substring($insertAt)
  } else {
    $mBody = [regex]::Match($html, $patBodyOpen)
    if ($mBody.Success) {
      $insertAt = $mBody.Index + $mBody.Length
