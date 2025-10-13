<# 
.SYNOPSIS
  Whole Hog Leaderboard one-touch setup (no here-strings).
#>

[CmdletBinding()]
param(
  [Parameter(Position=0)]
  [string]$Root = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Backup {
  param([Parameter(Mandatory)][string]$Path)
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
    Write-Host "Backup created: $Path.bak-$stamp"
  }
}

# single UTF-8 (no BOM) encoder for all writes
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# Normalize root
$Root = (Resolve-Path -LiteralPath $Root).Path
Set-Location -LiteralPath $Root
Write-Host "Working in: $Root"

# Paths
$indexPath       = Join-Path $Root "index.html"
$leaderboardPath = Join-Path $Root "leaderboard.html"
$jsDir           = Join-Path $Root "js"
$leaderboardJs   = Join-Path $jsDir "leaderboard.js"
$dataDir         = Join-Path $Root "data"
$scoresJson      = Join-Path $dataDir "scores.json"
$stylesCss       = Join-Path $Root "styles.css"
$headerLoaderJs  = Join-Path $jsDir "header-loader.js"  # optional existing include

# 1) Verify index.html exists
if (!(Test-Path -LiteralPath $indexPath)) {
  throw "index.html not found at $indexPath. Run this from your web root or pass -Root."
}

# 2) Insert Leaderboard button (idempotent)
$indexHtml = Get-Content -LiteralPath $indexPath -Raw
$leaderLink = '<a href="leaderboard.html" class="btn btn-primary">Leaderboard</a>'
$hasLink = $indexHtml -match "href\s*=\s*[""']leaderboard\.html[""']"

if ($hasLink) {
  Write-Host "Leaderboard link already present in index.html — skipping insertion."
} else {
  New-Backup -Path $indexPath

  $inserted = $false

  if ($indexHtml -match '</main\s*>' ) {
    $indexHtml = [Regex]::Replace(
      $indexHtml,
      '</main\s*>',
      "  <!-- Leaderboard CTA injected -->`n  $leaderLink`n</main>",
      'IgnoreCase'
    )
    $inserted = $true
  } elseif ($indexHtml -match "<div[^>]*class\s*=\s*[""'][^""']*(actions|buttons|cta)[^""']*[""'][^>]*>" ) {
    $indexHtml = [Regex]::Replace(
      $indexHtml,
      "(<div[^>]*class\s*=\s*[""'][^""']*(actions|buttons|cta)[^""']*[""'][^>]*>)",
      "`$1`n  <!-- Leaderboard CTA injected -->`n  $leaderLink",
      'IgnoreCase'
    )
    $inserted = $true
  } elseif ($indexHtml -match '</body\s*>' ) {
    $indexHtml = [Regex]::Replace(
      $indexHtml,
      '</body\s*>',
      "  <!-- Leaderboard CTA injected (body-tail) -->`n  $leaderLink`n</body>",
      'IgnoreCase'
    )
    $inserted = $true
  }

  if (-not $inserted) {
    Write-Warning "Could not find a good mount point; appending link to end of file."
    $indexHtml += "`n<!-- Leaderboard CTA appended -->`n$leaderLink`n"
  }

  [IO.File]::WriteAllText($indexPath, $indexHtml, $Utf8NoBom)
  Write-Host "Inserted Leaderboard button into index.html"
}

# 3) Create leaderboard.html (as array -> joined string)
$leaderboardHtmlLines = @(
'<!doctype html>',
'<html lang="en">',
'<head>',
'  <meta charset="utf-8" />',
'  <title>Leaderboard | Whole Hog</title>',
'  <meta name="viewport" content="width=device-width, initial-scale=1" />',
'  <link href="styles.css" rel="stylesheet" />',
'  <script defer src="js/header-loader.js"></script>',
'  <script defer src="js/leaderboard.js"></script>',
'  <style>',
'    .wrap { max-width: 1100px; margin: 0 auto; padding: 1rem; }',
'    .leaderboards { display: grid; gap: 1rem; }',
'    @media (min-width: 900px){ .leaderboards { grid-template-columns: 1fr 1fr; } }',
'    h1 { margin: .5rem 0 1rem; }',
'    section.category { background: #111; border: 1px solid #333; border-radius: 12px; padding: 1rem; }',
'    section.category h2 { margin: 0 0 .75rem; }',
'    table { width: 100%; border-collapse: collapse; }',
'    th, td { padding: .5rem .6rem; border-bottom: 1px solid #2a2a2a; text-align: left; }',
'    th { font-weight: 600; }',
'    tr.highlight-1 td { background: rgba(255,215,0,.08); }',
'    tr.highlight-2 td { background: rgba(192,192,192,.08); }',
'    tr.highlight-3 td { background: rgba(205,127,50,.08); }',
'    .subtle { color: #aaa; font-size: .9em; }',
'  </style>',
'</head>',
'<body>',
'  <header id="site-header"></header>',
'  <main class="wrap">',
'    <h1>Leaderboard</h1>',
'    <p class="subtle">Summaries for On-Site, Blind Taste, People''s Choice, and Sauce Tasting.</p>',
'    <div id="generated-at" class="subtle" style="margin:.2rem 0 1rem;"></div>',
'    <div class="leaderboards">',
'      <section class="category" id="onsite">',
'        <h2>On-Site Tasting <span class="subtle">(with tie-breakers)</span></h2>',
'        <div class="table-wrap">',
'          <table id="table-onsite">',
'            <thead>',
'              <tr>',
'                <th>Place</th>',
'                <th>Team</th>',
'                <th>Total</th>',
'                <th class="subtle">Taste</th>',
'                <th class="subtle">Tenderness</th>',
'                <th class="subtle">Appearance</th>',
'              </tr>',
'            </thead>',
'            <tbody></tbody>',
'          </table>',
'        </div>',
'      </section>',
'      <section class="category" id="blind">',
'        <h2>Blind Taste</h2>',
'        <table id="table-blind">',
'          <thead>',
'            <tr><th>Place</th><th>Team</th><th>Total</th></tr>',
'          </thead>',
'          <tbody></tbody>',
'        </table>',
'      </section>',
'      <section class="category" id="people">',
'        <h2>People''s Choice</h2>',
'        <table id="table-people">',
'          <thead>',
'            <tr><th>Place</th><th>Team</th><th>Votes</th></tr>',
'          </thead>',
'          <tbody></tbody>',
'        </table>',
'      </section>',
'      <section class="category" id="sauce">',
'        <h2>Sauce Tasting</h2>',
'        <table id="table-sauce">',
'          <thead>',
'            <tr><th>Place</th><th>Team</th><th>Total</th></tr>',
'          </thead>',
'          <tbody></tbody>',
'        </table>',
'      </section>',
'    </div>',
'  </main>',
'</body>',
'</html>'
)
$leaderboardHtml = $leaderboardHtmlLines -join "`r`n"
[IO.File]::WriteAllText($leaderboardPath, $leaderboardHtml, $Utf8NoBom)

# 4) Create js/leaderboard.js (array -> joined string)
if (!(Test-Path -LiteralPath $jsDir)) { New-Item -ItemType Directory -Path $jsDir -Force | Out-Null }

$leaderboardJsLines = @(
'(function(){',
'  const DATA_SOURCE = "/data/scores.json";',
'  const val = (obj, key, def=null) => (obj && obj[key] != null ? obj[key] : def);',
'  function timeNum(x){',
'    if (x == null) return Number.MAX_SAFE_INTEGER;',
'    if (typeof x === "number") return x;',
'    const d = new Date(x);',
'    return isNaN(d) ? Number.MAX_SAFE_INTEGER : d.getTime();',
'  }',
'  function compareOnSite(a, b){',
'    if (val(b,"total",0) !== val(a,"total",0)) return val(b,"total",0) - val(a,"total",0);',
'    if (val(b,"taste",0) !== val(a,"taste",0)) return val(b,"taste",0) - val(a,"taste",0);',
'    if (val(b,"tenderness",0) !== val(a,"tenderness",0)) return val(b,"tenderness",0) - val(a,"tenderness",0);',
'    if (val(b,"appearance",0) !== val(a,"appearance",0)) return val(b,"appearance",0) - val(a,"appearance",0);',
'    const at = timeNum(val(a,"submit_time",null));',
'    const bt = timeNum(val(b,"submit_time",null));',
'    if (bt !== at) return at - bt;',
'    return String(val(a,"team","")).localeCompare(String(val(b,"team","")));',
'  }',
'  const compareDescBy = (key) => (a,b) => {',
'    const diff = (val(b,key,0) - val(a,key,0));',
'    return diff !== 0 ? diff : String(val(a,"team","")).localeCompare(String(val(b,"team","")));',
'  };',
'  function compareKeyFor(r){',
'    return [',
'      val(r,"total",0),',
'      val(r,"taste",0),',
'      val(r,"tenderness",0),',
'      val(r,"appearance",0),',
'      val(r,"submit_time",Number.MAX_SAFE_INTEGER)',
'    ].join("|");',
'  }',
'  function rank(items, compareFn){',
'    const sorted = [...items].sort(compareFn);',
'    let place = 0, lastKey = null;',
'    return sorted.map((row, idx) => {',
'      const key = compareKeyFor(row);',
'      if (key !== lastKey) { place = idx + 1; lastKey = key; }',
'      return { ...row, _place: place };',
'    });',
'  }',
'  function trHighlight(place){',
'    if (place === 1) return "highlight-1";',
'    if (place === 2) return "highlight-2";',
'    if (place === 3) return "highlight-3";',
'    return "";',
'  }',
'  function renderTable(tbody, rows, cols){',
'    tbody.innerHTML = rows.map(r=>{',
'      const cls = trHighlight(r._place);',
'      const tds = cols.map(c=>{',
'        const content = (typeof c.render === "function") ? c.render(r) : val(r, c.key, "");',
'        return `<td>${content ?? ""}</td>`;',
'      }).join("");',
'      return `<tr class="${cls}">${tds}</tr>`;',
'    }).join("");',
'  }',
'  function build(data){',
'    const onsite = (data.onsite || []);',
'    const blind  = (data.blind  || []);',
'    const people = (data.people || []);',
'    const sauce  = (data.sauce  || []);',
'    const onsiteRanked = rank(onsite, compareOnSite);',
'    renderTable(',
'      document.querySelector("#table-onsite tbody"),',
'      onsiteRanked,',
'      [',
'        { key:"_place", render:r=>r._place },',
'        { key:"team" },',
'        { key:"total" },',
'        { key:"taste" },',
'        { key:"tenderness" },',
'        { key:"appearance" }',
'      ]',
'    );',
'    const blindRanked = rank(blind, compareDescBy("total"));',
'    renderTable(',
'      document.querySelector("#table-blind tbody"),',
'      blindRanked,',
'      [',
'        { key:"_place", render:r=>r._place },',
'        { key:"team" },',
'        { key:"total" }',
'      ]',
'    );',
'    const peopleRanked = rank(people, compareDescBy("votes"));',
'    renderTable(',
'      document.querySelector("#table-people tbody"),',
'      peopleRanked,',
'      [',
'        { key:"_place", render:r=>r._place },',
'        { key:"team" },',
'        { key:"votes" }',
'      ]',
'    );',
'    const sauceRanked = rank(sauce, compareDescBy("total"));',
'    renderTable(',
'      document.querySelector("#table-sauce tbody"),',
'      sauceRanked,',
'      [',
'        { key:"_place", render:r=>r._place },',
'        { key:"team" },',
'        { key:"total" }',
'      ]',
'    );',
'    const ts = new Date();',
'    const ga = document.getElementById("generated-at");',
'    if (ga) ga.textContent = `Updated: ${ts.toLocaleString()}`;',
'  }',
'  async function load(){',
'    if (window.WholeHogData && (window.WholeHogData.onsite || window.WholeHogData.blind || window.WholeHogData.people || window.WholeHogData.sauce)) {',
'      build(window.WholeHogData);',
'      return;',
'    }',
'    try {',
'      const res = await fetch(DATA_SOURCE, { cache: "no-store" });',
'      if (!res.ok) throw new Error("fetch failed");',
'      const data = await res.json();',
'      build(data);',
'    } catch (e) {',
'      console.error("Could not load scores:", e);',
'      build({ onsite:[], blind:[], people:[], sauce:[] });',
'    }',
'  }',
'  document.addEventListener("DOMContentLoaded", load);',
'})();'
)
$leaderboardJs = Join-Path $jsDir "leaderboard.js"
if (Test-Path -LiteralPath $leaderboardJs) { New-Backup -Path $leaderboardJs }
[IO.File]::WriteAllText($leaderboardJs, ($leaderboardJsLines -join "`r`n"), $Utf8NoBom)
Write-Host "Created js/leaderboard.js"

# 5) Create sample data/scores.json only if missing (array -> joined string)
if (!(Test-Path -LiteralPath $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }

if (!(Test-Path -LiteralPath $scoresJson)) {
  $sampleJsonLines = @(
    '{',
    '  "onsite": [',
    '    { "team": "Hog Heaven", "total": 271.5, "taste": 92, "tenderness": 90, "appearance": 89.5, "submit_time": "2025-10-04T12:03:15-04:00" },',
    '    { "team": "Smoke Ring Kings", "total": 271.5, "taste": 92, "tenderness": 88, "appearance": 91.5, "submit_time": "2025-10-04T12:05:30-04:00" },',
    '    { "team": "Cracklin Crew", "total": 268.0, "taste": 90, "tenderness": 88, "appearance": 90, "submit_time": 1696430400000 }',
    '  ],',
    '  "blind": [',
    '    { "team": "Hog Heaven", "total": 274.0 },',
    '    { "team": "Smoke Ring Kings", "total": 271.0 }',
    '  ],',
    '  "people": [',
    '    { "team": "Hog Heaven", "votes": 184 },',
    '    { "team": "Cracklin Crew", "votes": 201 }',
    '  ],',
    '  "sauce": [',
    '    { "team": "Smoke Ring Kings", "total": 93.5 },',
    '    { "team": "Hog Heaven", "total": 94.0 }',
    '  ]',
    '}'
  )
  [IO.File]::WriteAllText($scoresJson, ($sampleJsonLines -join "`r`n"), $Utf8NoBom)
  Write-Host "Created data/scores.json (sample). Replace with your live data feed when ready."
} else {
  Write-Host "data/scores.json already exists — leaving as-is."
}

# 6) Gentle reminders
if (!(Test-Path -LiteralPath $headerLoaderJs)) {
  Write-Warning 'js/header-loader.js not found. Ensure your header is injected on pages (server include or script). The leaderboard expects <header id="site-header"></header>.'
}
if (!(Test-Path -LiteralPath $stylesCss)) {
  Write-Warning 'styles.css not found. The embedded <style> in leaderboard.html will render, but your site button styles may differ.'
}

Write-Host ""
Write-Host "✅ Done. Open leaderboard.html in a browser to verify the tables populate."





