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

# Idempotency marker
$marker = "/* wh:set-header-title:leaderboard */"
if ($html -match [Regex]::Escape($marker)) {
  Write-Host "Header title script already present — nothing to do."
  exit 0
}

# JS snippet that renames the header title on this page only
$jsLines = @(
'(function(){',
'  ' + $marker,
'  function setHeaderTitle(){',
'    var root = document.getElementById("site-header");',
'    if(!root) return;',
'    // Try common title targets in the header',
'    var el = root.querySelector(".page-title, .site-title, h1, h2, [data-role=""title""], [role=""heading""]");',
'    if (el){ el.textContent = "Leaderboard"; return; }',
'    // Fallback: append a title node',
'    var bar = root.querySelector(".site-header-wrap") || root;',
'    var div = document.createElement("div");',
'    div.className = "page-title";',
'    div.textContent = "Leaderboard";',
'    div.style.marginLeft = ".5rem";',
'    div.style.fontWeight = "700";',
'    div.style.fontSize = "1.1rem";',
'    bar.appendChild(div);',
'  }',
'  function prime(){ setHeaderTitle(); }',
'  document.addEventListener("DOMContentLoaded", prime);',
'  // Also observe async header injection (e.g., loader fetch)',
'  var hdr = document.getElementById("site-header");',
'  if (hdr){',
'    var obs = new MutationObserver(function(){ setHeaderTitle(); });',
'    obs.observe(hdr, {childList:true, subtree:true});',
'    setTimeout(function(){ try{ obs.disconnect(); }catch(e){} }, 4000);',
'  }',
'  // Optional: set the <title> tag to match',
'  try { if (document && document.title) document.title = "Leaderboard | Whole Hog"; } catch(e) {}',
'})();'
)

$scriptTag = '<script>' + ($jsLines -join "`n") + '</script>'

New-Backup -Path $target

if ($html -match '</body\s*>') {
  $html = [Regex]::Replace($html, '</body\s*>', "  $scriptTag`r`n</body>", 'IgnoreCase')
} elseif ($html -match '</html\s*>') {
  $html = [Regex]::Replace($html, '</html\s*>', "  $scriptTag`r`n</html>", 'IgnoreCase')
} else {
  $html += "`r`n$scriptTag"
}

[IO.File]::WriteAllText($target, $html, $Utf8NoBom)
Write-Host "✅ Leaderboard header title set to 'Leaderboard' in leaderboard.html"
