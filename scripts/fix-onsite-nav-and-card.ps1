param(
  [string]$Root = ".",
  [string]$File = "onsite.html"
)

function Read-FileUtf8NoBom([string]$path) {
  return [System.IO.File]::ReadAllText((Resolve-Path $path), (New-Object System.Text.UTF8Encoding($false)))
}
function Write-FileUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

$path = Join-Path $Root $File
if (!(Test-Path $path)) { throw "File not found: $path" }

# Backup
$backupDir = Join-Path $Root "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Copy-Item $path (Join-Path $backupDir ("{0}_{1}" -f $File,$stamp))

$html = Read-FileUtf8NoBom $path

# ---------- Helpers (patterns that won't break quoting) ----------
$patNavBlock = "(?is)<nav\b[^>]*id\s*=\s*[`"']top-go-buttons[`"'][^>]*>.*?</nav>"
$patHeadClose = "(?is)</head>"
$patHasScoringCard = "(?is)\bid\s*=\s*[`"']scoring-card[`"']"
$patTopGoButtonsWrapper = "(?is)(<nav\b[^>]*id\s*=\s*[`"']top-go-buttons[`"'][^>]*>)(.*?)(</nav>)"
$patHomeAnchor = "(?is)<a\b[^>]*id\s*=\s*[`"']go-home[`"'][^>]*>.*?</a>\s*"

function Ensure-Anchor([string]$htmlIn, [string]$id, [string]$href, [string]$text) {
  $patHasId = "(?is)<a\b[^>]*id\s*=\s*[`"']" + [regex]::Escape($id) + "[`"']"
  if ([regex]::IsMatch($htmlIn, $patHasId)) { return $htmlIn }
  $anchor = '<a class="go-btn" id="' + $id + '" href="' + $href + '">' + $text + '</a>'
  return [regex]::Replace(
    $htmlIn,
    $patTopGoButtonsWrapper,
    {
      param($m)
      $m.Groups[1].Value + $m.Groups[2].Value + "`r`n  " + $anchor + $m.Groups[3].Value
    },
    1
  )
}

# ---------- 1) Keep the first #top-go-buttons, remove any extras ----------
$allNav = [regex]::Matches($html, $patNavBlock)
if ($allNav.Count -gt 1) {
  $keep = $allNav[0].Value
  # Remove ALL
  $html = [regex]::Replace($html, $patNavBlock, "")
  # Re-insert the kept one right after the header (or at top of <body> as fallback)
  $html = [regex]::Replace($html, "(?is)(</header>)", ('$1' + "`r`n" + $keep), 1)
  if (-not [regex]::IsMatch($h

