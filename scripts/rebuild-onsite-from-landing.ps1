param(
  [string]$Root = ".",
  [string]$Landing = "landing.html",
  [string]$Out = "onsite.html"
)

# --- Helpers ---------------------------------------------------------------
function Read-FileUtf8NoBom([string]$path) {
  return [System.IO.File]::ReadAllText((Resolve-Path $path), (New-Object System.Text.UTF8Encoding($false)))
}
function Write-FileUtf8NoBom([string]$path, [string]$content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $enc)
}

# --- Paths ----------------------------------------------------------------
$landingPath = Join-Path $Root $Landing
$outPath     = Join-Path $Root $Out

if (!(Test-Path $landingPath)) {
  throw "Landing file not found at: $landingPath"
}

# Backup current onsite if exists
if (Test-Path $outPath) {
  $backupDir = Join-Path $Root "backup"
  New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  Copy-Item $outPath (Join-Path $backupDir "onsite_$stamp.html")
}

# --- Read landing ---------------------------------------------------------
$landingHtml = Read-FileUtf8NoBom $landingPath

# Extract <head>...</head> exactly as-is (preserves CSS/JS links and theme)
$head = [regex]::Match($landingHtml, '(?is)<head\b[^>]*>.*?</head>').Value
if ([string]::IsNullOrWhiteSpace($head)) { throw "Could not extract <head> from landing." }

# Extract the first <header>...</header> block (site header)
$header = [regex]::Match($landingHtml, '(?is)<header\b[^>]*>.*?</header>').Value
if ([string]::IsNullOrWhiteSpace($header)) {
  # Fallback: some pages use a wrapper like <div class="site-header">...</div>
  $header = [regex]::Match($landingHtml, '(?is)<(div|section)\b[^>]*class="[^"]*?site-header[^"]*?".*?>.*?</\1>').Value
}
if ([string]::IsNullOrWhiteSpace($header)) { throw "Could not extract header from landing." }

# Try to replace the header title with "On-site Judging"
# Handles common patterns: <h1>, .page-title, [data-title], etc.
$desiredTitle = 'On-site Judging'
$headerUpdated = $header

# 1) Replace <h1>...</h1>
$headerUpdated = [regex]::Replace($headerUpdated, '(?is)(<h1\b[^>]*>)(.*?)(</h1>)', ('$1' + $desiredTitle + '$3'), 1)
if ($headerUpdated -ne $header) { $header = $headerUpdated }

# 2) If no <h1>, try element with class "page-title"
if ($header -eq $headerUpdated) {
  $headerUpdated = [regex]::Replace($headerUpdated, '(?is)(<[^>]+\bclass="[^"]*?\bpage-title\b[^"]*?"[^>]*>)(.*?)(</[^>]+>)', ('$1' + $desiredTitle + '$3'), 1)
  if ($headerUpdated -ne $header) { $header = $headerUpdated }
}

# 3) If still unchanged, append a visible title block inside header (non-destructive)
if ($header -eq $headerUpdated) {
  $header = [regex]::Replace($header, '(?is)(</header>)', "<div class=""page-title"" style=""font-weight:700;font-size:1.4rem;margin-left:8px"">$desiredTitle</div>`n`$1", 1)
}

# Figure out the nav button class used on Landing (to match colors/shape)
# We’ll grab the first <a ...> inside a <nav> from landing and reuse its class attribute.
$navMatch = [regex]::Match($landingHtml, '(?is)<nav\b[^>]*>.*?</nav>')
$btnClass = "go-btn"  # default if we can’t detect
if ($navMatch.Success) {
  $firstAnchor = [regex]::Match($navMatch.Value, '(?is)<a\b[^>]*?>')
  if ($firstAnchor.Success) {
    $classAttr = [regex]::Match($firstAnchor.Value, '(?i)\bclass\s*=\s*"(.*?)"')
    if ($classAttr.Success -and $classAttr.Groups[1].Value.Trim().Length -gt 0) {
      $btnClass = $classAttr.Groups[1].Value.Trim()
    }
  }
}

# Build a single canonical nav (same classes as Landing)
$nav = @"
<nav id="top-go-buttons" aria-label="Primary">
  <a class="$btnClass" id="go-home"        data-label="Home"               href="./index.html">Home</a>
  <a class="$btnClass" id="go-landing"     data-label="Go to Landing"      href="./landing.html">Go to Landing</a>
  <a class="$btnClass" id="go-leaderboard" data-label="Go to Leaderboard"  href="./leaderboard.html">Go to Leaderboard</a>
  <a class="$btnClass" id="go-blind"       data-label="Go to Blind Taste"  href="./blind.html">Go to Blind Taste</a>
</nav>
"@

# Minimal, neutral content styled by existing site CSS
$mainContent = @"
<main>
  $nav
  <section id="scoring-card" class="card">
    <h2>On-Site Scoring Card</h2>

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

  <section id="recent" class="card">
    <h2>Recent Submissions</h2>
    <div id="recent-submissions">No submissions yet.</div>
  </section>
</main>
"@

# Ensure we preserve the landing DOCTYPE and <html ...> tag if present
$doctype = [regex]::Match($landingHtml, '^(?is)\s*<!DOCTYPE[^>]*>').Value
if (-not $doctype) { $doctype = '<!DOCTYPE html>' }

$htmlOpen = [regex]::Match($landingHtml, '(?is)<html\b[^>]*>').Value
if (-not $htmlOpen) { $htmlOpen = '<html lang="en">' }

$htmlClose = '</html>'

# Compose final page: DOCTYPE + <html> + landing <head> + updated header + our main content + OPTIONAL landing footer if present
$footer = [regex]::Match($landingHtml, '(?is)</main>\s*(.*)</body>').Groups[1].Value
# Try to extract a site footer element if it exists
$siteFooter = [regex]::Match($landingHtml, '(?is)<footer\b[^>]*>.*?</footer>').Value
if (-not [string]::IsNullOrWhiteSpace($siteFooter)) { $footer = $siteFooter }

$body = @"
<body>
$header
$mainContent
$footer
<script>
  // Guard against duplicate top-go-buttons injected by older scripts
  (function(){
    const nodes = Array.from(document.querySelectorAll('#top-go-buttons'));
    if (nodes.length > 1) nodes.slice(1).forEach(n => n.remove());
    const ids = new Set();
    document.querySelectorAll('#top-go-buttons a').forEach(a=>{
      if (ids.has(a.id)) a.remove(); else ids.add(a.id);
    });
  })();
</script>
</body>
"@

$final = "$doctype`n$htmlOpen`n$head`n$body`n$htmlClose`n"

Write-FileUtf8NoBom $outPath $final
Write-Host "✅ Rebuilt $Out using Landing's exact formatting, with header text set to '$desiredTitle'."
