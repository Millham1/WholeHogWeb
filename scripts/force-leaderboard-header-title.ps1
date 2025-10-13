[CmdletBinding()]
param([string]$Root = ".")

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
$target = Join-Path $Root "leaderboard.html"
if (!(Test-Path -LiteralPath $target)) { throw "leaderboard.html not found at: $target" }

$html = Get-Content -LiteralPath $target -Raw

# ---- Inject CSS (once) ----
$cssId = 'wh-leaderboard-title-style'
if ($html -notmatch [Regex]::Escape($cssId)) {
  $css = @(
    '<style id="wh-leaderboard-title-style">',
    '.wh-leaderboard-title{margin-left:.5rem;font-weight:700;font-size:1.1rem;letter-spacing:.3px;}',
    '@media (min-width:700px){.wh-leaderboard-title{font-size:1.25rem;}}',
    '</style>'
  ) -join "`r`n"

  if ($html -match '</head\s*>') {
    $html = [Regex]::Replace($html, '</head\s*>', "  $css`r`n</head>", 'IgnoreCase')
  } else {
    # no <head>, just prepend
    $html = "$css`r`n$html"
  }
}

# ---- Inject JS (once) ----
$marker = '/* wh:set-header-title:leaderboard:v2 */'
if ($html -notmatch [Regex]::Escape($marker)) {
  $jsLines = @(
    '(function(){',
    '  ' + $marker,
    '  function ensureTitle(){',
    '    var hdr = document.getElementById("site-header");',
    '    if(!hdr) return;',
    '    var wrap = hdr.querySelector(".site-header-wrap") || hdr;',
    '    // Hide any existing title-ish elements so we don''t get duplicates',
    '    var killSel = ".page-title,.site-title,.header-title,[data-role=title],[role=heading]";',
    '    wrap.querySelectorAll(killSel).forEach(function(el){ el.style.display="none"; });',
    '    // Create/refresh our page-only title',
    '    var title = wrap.querySelector(".wh-leaderboard-title");',
    '    if(!title){',
    '      title = document.createElement("div");',
    '      title.className = "wh-leaderboard-title";',
    '      // Insert before <nav> if present so it sits between logos and nav',
    '      var nav = wrap.querySelector("nav");',
    '      if(nav){ wrap.insertBefore(title, nav); } else { wrap.appendChild(title); }',
    '    }',
    '    title.textContent = "Leaderboard";',
    '    try{ document.title = "Leaderboard | Whole Hog"; }catch(e){}',
    '  }',
    '  function prime(){ ensureTitle(); }',
    '  document.addEventListener("DOMContentLoaded", prime);',
    '  window.addEventListener("load", prime);',
    '  // Watch for async header injection for ~30s',
    '  try{',
    '    var mo = new MutationObserver(prime);',
    '    mo.observe(document.documentElement, {subtree:true, childList:true});',
    '    setTimeout(function(){ try{ mo.disconnect(); }catch(e){} }, 30000);',
    '  }catch(e){}',
    '})();'
  )
  $scriptTag = '<script>' + ($jsLines -join "`n") + '</script>'

  if ($html -match '</body\s*>') {
    $html = [Regex]::Replace($html, '</body\s*>', "  $scriptTag`r`n</body>", 'IgnoreCase')
  } elseif ($html -match '</html\s*>') {
    $html = [Regex]::Replace($html, '</html\s*>', "  $scriptTag`r`n</html>", 'IgnoreCase')
  } else {
    $html += "`r`n$scriptTag"
  }
}

# ---- Save ----
New-Backup -Path $target
[IO.File]::WriteAllText($target, $html, $Utf8NoBom)
Write-Host "✅ Forced header title on leaderboard.html to 'Leaderboard' (with async-safe hook)"
