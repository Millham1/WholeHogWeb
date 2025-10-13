param(
  [string]$Root = ".",
  [string]$File = "onsite.html"
)

# ------- IO helpers ---------------------------------------------------------
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

# ------- Regex patterns (quote-safe) ----------------------------------------
$patNavBlock = '(?is)<nav\b[^>]*id\s*=\s*["'']top-go-buttons["''][^>]*>.*?</nav>'
$patHeadClose = '(?is)</head>'
$patGoHome = '(?is)<a\b[^>]*id\s*=\s*["'']go-home["''][^>]*>.*?</a>\s*'
$patHasScoring = '(?is)\bid\s*=\s*["'']scoring-card["'']'
$patHtmlBodyOpen = '(?is)<body\b[^>]*>'
$patHeaderClose = '(?is)</header>'

# ------- Step 1: Ensure exactly one #top-go-buttons -------------------------
$navMatches = [regex]::Matches($html, $patNavBlock)
if ($navMatches.Count -gt 1) {
  $firstNav = $navMatches[0].Value
  # Remove all navs
  $html = [regex]::Replace($html, $patNavBlock, "")
  # Reinsert the first one just after </header> if found, else after <body ...>
  if ([regex]::IsMatch($html, $patHeaderClose)) {
    $html = [regex]::Replace($html, $patHeaderClose, { param($m) ($m.Value + "`r`n" + $firstNav) }, 1)
  } elseif ([regex]::IsMatch($html, $patHtmlBodyOpen)) {
    $html = [regex]::Replace($html, $patHtmlBodyOpen, { param($m) ($m.Value + "`r`n" + $firstNav) }, 1)
  } else {
    $html = $firstNav + "`r`n" + $html
  }
} elseif ($navMatches.Count -eq 0) {
  # Create a fresh nav
  $newNav = @'
<nav id="top-go-buttons" aria-label="Primary">
  <a class="go-btn" id="go-landing"     href="./landing.html">Go to Landing</a>
  <a class="go-btn" id="go-leaderboard" href="./leaderboard.html">Go to Leaderboard</a>
  <a class="go-btn" id="go-blind"       href="./blind.html">Go to Blind Taste</a>
</nav>
'@
  if ([regex]::IsMatch($html, $patHeaderClose)) {
    $html = [regex]::Replace($html, $patHeaderClose, { param($m) ($m.Value + "`r`n" + $newNav) }, 1)
  } elseif ([regex]::IsMatch($html, $patHtmlBodyOpen)) {
    $html = [regex]::Replace($html, $patHtmlBodyOpen, { param($m) ($m.Value + "`r`n" + $newNav) }, 1)
  } else {
    $html = $newNav + "`r`n" + $html
  }
}

# At this point there is exactly one nav; fetch it again
$navMatch = [regex]::Match($html, $patNavBlock)
$nav = $navMatch.Value

# ------- Step 2: Remove Home anchor ----------------------------------------
$nav2 = [regex]::Replace($nav, $patGoHome, "")

# ------- Step 3: Ensure the 3 required anchors exist ------------------------
function EnsureAnchor([string]$navHtml, [string]$id, [string]$href, [string]$text) {
  $patId = '(?is)<a\b[^>]*id\s*=\s*["'']' + [regex]::Escape($id) + '["'']'
  if ([regex]::IsMatch($navHtml, $patId)) { return $navHtml }
  $anchor = '<a class="go-btn" id="' + $id + '" href="' + $href + '">' + $text + '</a>'
  return $navHtml -replace '(?is)</nav>', ("  " + $anchor + "`r`n</nav>")
