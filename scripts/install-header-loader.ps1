[CmdletBinding()]
param(
  [string]$Root = ".",
  [switch]$AllPages # if set, ensure header + loader script on ALL .html files, not just index.html + leaderboard.html
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

function New-Backup([Parameter(Mandatory)][string]$Path){
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
    Write-Host "Backup created: $Path.bak-$stamp"
  }
}

$Root = (Resolve-Path -LiteralPath $Root).Path
Set-Location -LiteralPath $Root
Write-Host "Working in: $Root"

# Paths
$jsDir          = Join-Path $Root "js"
$loaderPath     = Join-Path $jsDir "header-loader.js"
$headerPartial  = Join-Path $Root "header.html"
$indexPath      = Join-Path $Root "index.html"
$leaderboard    = Join-Path $Root "leaderboard.html"

# detect logos so we can embed a default header that works offline
$logoA = (Test-Path -LiteralPath (Join-Path $Root "Legion whole hog logo.png")) ? "Legion whole hog logo.png" : $null
$logoB = (Test-Path -LiteralPath (Join-Path $Root "AL Medallion.png"))        ? "AL Medallion.png"         : $null

# Build default header HTML (simple, dark-friendly)
$defaultHeaderLines = @(
  '<div class="site-header-wrap" style="display:flex;align-items:center;gap:.75rem;padding:.5rem 1rem;border-bottom:1px solid #333;background:#0b0b0b;">'
)
if ($logoA) { $defaultHeaderLines += "  <img src=""$logoA"" alt=""Legion Whole Hog"" style=""height:48px;object-fit:contain;border-radius:6px;"">" }
if ($logoB) { $defaultHeaderLines += "  <img src=""$logoB"" alt=""AL Medallion"" style=""height:48px;object-fit:contain;border-radius:6px;"">" }
$defaultHeaderLines += @(
  '  <div style="font-weight:700;font-size:1.1rem;letter-spacing:.3px;">Whole Hog Competition</div>',
  '  <nav style="margin-left:auto;display:flex;gap:.75rem;flex-wrap:wrap;">',
  '    <a href="index.html" style="text-decoration:none;border:1px solid #444;padding:.35rem .6rem;border-radius:8px;">Home</a>',
  '    <a href="leaderboard.html" style="text-decoration:none;border:1px solid #444;padding:.35rem .6rem;border-radius:8px;">Leaderboard</a>',
  '  </nav>',
  '</div>'
)
$defaultHeaderHtml = $defaultHeaderLines -join ""

# Ensure js directory
if (!(Test-Path -LiteralPath $jsDir)) { New-Item -ItemType Directory -Path $jsDir -Force | Out-Null }

# Create header-loader.js with 3 strategies:
# 1) Use window.WHOLEHOG_HEADER_HTML if defined (fastest, no fetch)
# 2) Try fetch('header.html') when served via http(s)
# 3) Fallback to DEFAULT_HEADER_HTML (works on file:// too)
$loaderLines = @(
'(function(){',
'  function inject(html){',
'    var slot = document.getElementById("site-header");',
'    if (!slot) return;',
'    slot.innerHTML = html;',
'  }',
'  var DEFAULT_HEADER_HTML = ' + "'" + ($defaultHeaderHtml -replace "'", "&#39;") + "'" + ';',
'  function tryFetch(){',
'    try {',
'      if (location.protocol === "http:" || location.protocol === "https:") {',
'        return fetch("header.html", {cache:"no-store"})',
'          .then(function(r){ return r.ok ? r.text() : ""; })',
'          .then(function(html){ if (html) inject(html); else inject(DEFAULT_HEADER_HTML); })',
'          .catch(function(){ inject(DEFAULT_HEADER_HTML); });',
'      }',
'    } catch(e) {}',
'    inject(DEFAULT_HEADER_HTML);',
'  }',
'  document.addEventListener("DOMContentLoaded", function(){',
'    if (window.WHOLEHOG_HEADER_HTML) {',
'      inject(window.WHOLEHOG_HEADER_HTML);',
'    } else {',
'      tryFetch();',
'    }',
'  });',
'})();'
)
if (Test-Path -LiteralPath $loaderPath) { New-Backup -Path $loaderPath }
[IO.File]::WriteAllText($loaderPath, ($loaderLines -join "`r`n"), $Utf8NoBom)
Write-Host "Created js/header-loader.js"

# Create header.html only if missing (so you can edit a shared header later)
if (!(Test-Path -LiteralPath $headerPartial)) {
  [IO.File]::WriteAllText($headerPartial, ($defaultHeaderLines -join "`r`n"), $Utf8NoBom)
  Write-Host "Created header.html (you can customize this)."
} else {
  Write-Host "header.html already exists — leaving as-is."
}

# Helper: ensure header slot + loader script present in a page
function Ensure-Header-OnPage([string]$pagePath){
  if (!(Test-Path -LiteralPath $pagePath)) { return }
  $html = Get-Content -LiteralPath $pagePath -Raw
  $changed = $false

  # Ensure <header id="site-header"></header> right after <body ...>
  if ($html -notmatch '<header[^>]*\bid\s*=\s*["'']site-header["'']') {
    if ($html -match '(<body[^>]*>)') {
      New-Backup -Path $pagePath
      $html = [Regex]::Replace($html, '(<body[^>]*>)', '$1' + "`r`n  <header id=""site-header""></header>", 'IgnoreCase')
      $changed = $true
    }
  }

  # Ensure <script defer src="js/header-loader.js"></script> in <head> (or before </body> if no head)
  if ($html -notmatch 'src\s*=\s*["'']js/header-loader\.js["'']') {
    if ($html -match '</head\s*>') {
      if (-not $changed) { New-Backup -Path $pagePath; $changed = $true }
      $html = [Regex]::Replace($html, '</head\s*>', '  <script defer src="js/header-loader.js"></script>' + "`r`n</head>", 'IgnoreCase')
    } elseif ($html -match '</body\s*>') {
      if (-not $changed) { New-Backup -Path $pagePath; $changed = $true }
      $html = [Regex]::Replace($html, '</body\s*>', '  <script defer src="js/header-loader.js"></script>' + "`r`n</body>", 'IgnoreCase')
    }
  }

  if ($changed) {
    [IO.File]::WriteAllText($pagePath, $html, $Utf8NoBom)
    Write-Host "Patched: $pagePath"
  } else {
    Write-Host "OK: $pagePath"
  }
}

# Decide which pages to patch
$targets = @()
if ($AllPages) {
  $targets = Get-ChildItem -LiteralPath $Root -Recurse -Include *.html -File | Select-Object -ExpandProperty FullName
} else {
  if (Test-Path -LiteralPath $indexPath)      { $targets += $indexPath }
  if (Test-Path -LiteralPath $leaderboard)    { $targets += $leaderboard }
}

foreach ($p in $targets) { Ensure-Header-OnPage $p }

Write-Host "`n✅ Header loader installed. Open index.html and leaderboard.html — the header should render even over file://"
