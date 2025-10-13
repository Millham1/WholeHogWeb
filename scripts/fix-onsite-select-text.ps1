# fix-onsite-select-text.ps1  (PowerShell 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}

# Paths
$OnsiteHtml = Join-Path $WebRoot 'onsite.html'
$CleanJs    = Join-Path $WebRoot 'onsite-clean-selects.js'

if(-not (Test-Path $OnsiteHtml)){ throw "onsite.html not found at $OnsiteHtml" }

# Backup onsite.html once
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$bak = Join-Path $WebRoot ("BACKUP_onsite_clean_" + $stamp + ".html")
Copy-Item $OnsiteHtml $bak -Force
Write-Host "Backup saved: $bak" -ForegroundColor Yellow

# JS that sanitizes Team/Judge select option labels
$js = @"
(() => {
  function sanitizeLabel(s){
    if (!s && s !== 0) return s;
    try { s = ("""" + s).normalize('NFC'); } catch(e) { s = """" + s; }
    // Replace en/em dashes with hyphen
    s = s.replace(/[\u2013\u2014]/g, '-');
    // Ellipsis -> ...
    s = s.replace(/\u2026/g, '...');
    // NBSP -> space
    s = s.replace(/\u00A0/g, ' ');
    // Remove zero-widths/bidi controls/BOM/word-joiner
    s = s.replace(/[\u200B-\u200D\uFEFF\u2060\u202A-\u202E\u2066-\u2069]/g, '');
    // Strip stray 'Â' (common mojibake)
    s = s.replace(/Â/g, '');
    // Collapse whitespace and trim
    s = s.replace(/\s+/g, ' ').trim();
    return s;
  }

  function sanitizeSelect(selector){
    var sel = document.querySelector(selector);
    if(!sel || !sel.options) return;
    for (var i=0;i<sel.options.length;i++){
      var opt = sel.options[i];
      if(!opt) continue;
      if (opt.text != null) { opt.text = sanitizeLabel(opt.text); }
    }
  }

  function ensurePlaceholders(){
    var teamPH = document.querySelector('#teamSelect option[value=""]');
    if(teamPH){ teamPH.text = 'Select team...'; }
    var judgePH = document.querySelector('#judgeSelect option[value=""]');
    if(judgePH){ judgePH.text = 'Select judge...'; }
  }

  function run(){
    sanitizeSelect('#teamSelect');
    sanitizeSelect('#judgeSelect');
    ensurePlaceholders();
  }

  // Initial and delayed runs (catch async data fills)
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
  setTimeout(run, 800);
  setTimeout(run, 2000);

  // Observe changes to the selects and sanitize on the fly
  ['#teamSelect','#judgeSelect'].forEach(function(q){
    var el = document.querySelector(q);
    if(!el) return;
    var obs = new MutationObserver(function(){ run(); });
    obs.observe(el, { childList:true, subtree:true, characterData:true });
  });

  // Optional: expose a manual hook other code can call after it updates options
  window.WH_CleanOnsiteSelects = run;
})();
"@

Write-Text $CleanJs $js
Write-Host "Wrote $($CleanJs | Split-Path -Leaf)" -ForegroundColor Cyan

# Ensure the script is referenced exactly once in onsite.html (before </body>)
$html = Read-Text $OnsiteHtml
$tag  = '<script src="onsite-clean-selects.js"></script>'
if ($html -notmatch [regex]::Escape($tag)) {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "  $tag`r`n</body>", 1, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    Write-Text $OnsiteHtml $html
    Write-Host "Injected onsite-clean-selects.js into onsite.html." -ForegroundColor Cyan
  } else {
    Write-Host "WARNING: </body> not found in onsite.html; could not inject script tag." -ForegroundColor Yellow
  }
} else {
  Write-Host "Script tag already present; no change to onsite.html." -ForegroundColor DarkGray
}

Write-Host "`nDone. Open onsite.html and press Ctrl+F5 to hard-refresh." -ForegroundColor Green
