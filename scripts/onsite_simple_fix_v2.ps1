param(
  [string]$Root = ".",
  [string]$File = "onsite.html"
)

# ---- Helpers (UTF-8 no BOM) ----
function Read-FileUtf8NoBom([string]$path) {
  return [System.IO.File]::ReadAllText((Resolve-Path $path), (New-Object System.Text.UTF8Encoding($false)))
}
function Write-FileUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

# ---- Paths & backup ----
$path = Join-Path $Root $File
if (!(Test-Path $path)) { throw "File not found: $path" }

$backupDir = Join-Path $Root "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path $backupDir ("{0}_{1}" -f $File,$stamp)
Copy-Item $path $backupPath -ErrorAction SilentlyContinue

# ---- Read ----
$html = Read-FileUtf8NoBom $path

# ---- Snippets ----
$newNav = @'
<nav id="top-go-buttons" aria-label="Primary">
  <a class="go-btn" id="go-landing"     href="./landing.html">Go to Landing</a>
  <a class="go-btn" id="go-leaderboard" href="./leaderboard.html">Go to Leaderboard</a>
  <a class="go-btn" id="go-blind"       href="./blind.html">Go to Blind Taste</a>
</nav>
'@

$overrideCss = @'
<style id="onsite-overrides">
  /* Red buttons with bold black text on On-site page only */
  #top-go-buttons a {
    background: #e53935 !important;  /* red */
    color: #000 !important;           /* black text */
    font-weight: 800 !important;      /* bold */
    border: 2px solid #000 !important;
    border-radius: 10px !important;
    padding: 10px 14px !important;
    display: inline-flex; align-items: center; gap: 8px;
    text-decoration: none;
  }
  #top-go-buttons a:hover { filter: brightness(0.9); }
</style>
'@

$scoringCard = @'
<section class="card" id="scoring-card" aria-labelledby="scoring-card-title">
  <h2 id="scoring-card-title">On-Site Scoring Card</h2>

  <div class="row">
    <div class="field">
      <label for="team">Team</label>
      <select id="team" name="team">
        <option value="" selected disabled>Select team…</option>
      </select>
    </div>
    <div class="field">
      <label for="chip">Chip #</label>
      <input id="chip" name="chip" type="text" inputmode="numeric" placeholder="e.g., 104">
    </div>
  </div>

  <div class="row">
    <div class="field">
      <label for="judge">Judge</label>
      <select id="judge" name="judge">
        <option value="" selected disabled>Select judge…</option>
      </select>
    </div>
    <div class="field">
      <label for="table">Table</label>
      <input id="table" name="table" type="text" placeholder="e.g., A">
    </div>
  </div>

  <div class="field">
    <label for="notes">Notes</label>
    <textarea id="notes" name="notes" rows="4" placeholder="Optional notes…"></textarea>
  </div>

  <button id="submit-score" type="button">Submit Score</button>
</section>
'@

# ---- 1) Remove ALL existing #top-go-buttons blocks ----
$patNavAll = '(?is)<nav[^>]*id="top-go-buttons"[^>]*>.*?</nav>'
$html = [regex]::Replace($html, $patNavAll, "")

# ---- 2) Insert a fresh nav after </header>, or after <body>, or at top ----
$patHeaderClose = '(?is)</header>'
$patBodyOpen    = '(?is)<body\b[^>]*>'

if ([regex]::IsMatch($html, $patHeaderClose)) {
  $m = [regex]::Match($html, $patHeaderClose)
  $insertAt = $m.Index + $m.Length
  $html = $html.Substring(0,$insertAt) + "`r`n" + $newNav + $html.Substring($insertAt)
} elseif ([regex]::IsMatch($html, $patBodyOpen)) {
  $m = [regex]::Match($html, $patBodyOpen)
  $insertAt = $m.Index + $m.Length
  $html = $html.Substring(0,$insertAt) + "`r`n" + $newNav + $html.Substring($insertAt)
} else {
  $html = $newNav + "`r`n" + $html
}

# ---- 3) Add red/bold override inside <head> (if not already) ----
$patHeadClose = '(?is)</head>'
$patOverrideExists = '(?is)<style\b[^>]*id="onsite-overrides"[^>]*>'

if (-not [regex]::IsMatch($html, $patOverrideExists)) {
  if ([regex]::IsMatch($html, $patHeadClose)) {
    $html = [regex]::Replace($html, $patHeadClose, ($overrideCss + "`r`n</head>"), 1)
  } else {
    $html = $overrideCss + "`r`n" + $html
  }
}

# ---- 4) Ensure scoring card exists; if missing, insert right after nav ----
$patHasScoring = '(?is)\bid="scoring-card"'
if (-not [regex]::IsMatch($html, $patHasScoring)) {
  $patNavOnce = '(?is)<nav[^>]*id="top-go-buttons"[^>]*>.*?</nav>'
  $navMatch = [regex]::Match($html, $patNavOnce)
  if ($navMatch.Success) {
    $insertAt = $navMatch.Index + $navMatch.Length
    $html = $html.Substring(0,$insertAt) + "`r`n" + $scoringCard + $html.Substring($insertAt)
  } else {
    $html = [regex]::Replace($html, '(?is)</body>', ($scoringCard + "`r`n</body>"), 1)
  }
}

# ---- Save (FIXED: space between args, no comma) ----
Write-FileUtf8NoBom $path $html

Write-Host "✅ Updated $File. Backup at: $backupPath"
