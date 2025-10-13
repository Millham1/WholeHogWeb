# fix-onsite-mojibake.ps1  (PowerShell 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  return [IO.File]::ReadAllText($Path, [Text.UTF8Encoding]::new($false))
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

# --- Build safe tokens (no literal mojibake in this script)
$ELLIPSIS_UNI = [string][char]0x2026                    # “…” (real ellipsis)
$ELLIPSIS_MOJ = [string]([char]0x00E2)+([char]0x20AC)+([char]0x00A6)  # “...”
$REPL_CHAR    = [string][char]0xFFFD                    #  

$files = @(
  Join-Path $WebRoot 'onsite.html'),
  (Join-Path $WebRoot 'landing.html'),
  (Join-Path $WebRoot 'onsite-sb.js'),
  (Join-Path $WebRoot 'landing-sb.js')
) | Where-Object { Test-Path $_ }

if(-not $files){ throw "No target files found under $WebRoot" }

foreach($f in $files){
  $orig = Read-Text $f
  $t = $orig

  # 1) Normalize ellipsis + remove replacement chars
  $t = $t -replace [regex]::Escape($ELLIPSIS_UNI), '...'
  $t = $t -replace [regex]::Escape($ELLIPSIS_MOJ), '...'
  $t = $t -replace [regex]::Escape($REPL_CHAR), ''

  # 2) Force clean placeholders (anywhere they appear)
  $patEll = '(' + [regex]::Escape('...') + '|' + [regex]::Escape($ELLIPSIS_UNI) + '|' + [regex]::Escape($ELLIPSIS_MOJ) + ')'
  $t = [regex]::Replace($t, "Select\s*team$patEll", 'Select team...', 'IgnoreCase')
  $t = [regex]::Replace($t, "Select\s*judge$patEll", 'Select judge...', 'IgnoreCase')
  $t = [regex]::Replace($t, "Select$patEll", 'Select...', 'IgnoreCase')

  if($t -ne $orig){
    Write-Text $f $t
    Write-Host ("Patched: {0}" -f (Split-Path $f -Leaf)) -ForegroundColor Green
  } else {
    Write-Host ("No changes: {0}" -f (Split-Path $f -Leaf)) -ForegroundColor DarkGray
  }
}

# 3) Drop/refresh tougher runtime sanitizer (handles late-added selects)
$SanJsPath = Join-Path $WebRoot 'onsite-clean-selects.js'
$sanJs = @'
(() => {
  function cleanAscii(s){
    if (s == null) return s;
    try { s = (""+s).normalize("NFC"); } catch(e) { s = ""+s; }
    const map = {
      "\u2013":"-","\u2014":"--","\u2026":"...","\u2018":"'","\u2019":"'","\u201C":'"',"\u201D":'"',"\u00A0":" "
    };
    s = s.replace(/[\u2013\u2014\u2026\u2018\u2019\u201C\u201D\u00A0]/g, ch => map[ch] || "");
    s = s.replace(/\u00E2\u20AC\u00A6/g, "...");          // mojibake ellipsis
    s = s.replace(/[\u200B-\u200D\uFEFF\u202A-\u202E\u2066-\u2069\uFFFD]/g, ""); // controls + replacement
    s = s.replace(/[^\x20-\x7E]/g, "");                   // drop non-ASCII
    return s.replace(/\s+/g,' ').trim();
  }
  function normalizePlaceholders(sel){
    const id = (sel.id||"").toLowerCase();
    const first = sel.querySelector('option[value=""]') || sel.options[0];
    if(!first) return;
    first.text = cleanAscii(first.text||"");
    if (id.includes("team"))       first.text = "Select team...";
    else if (id.includes("judge")) first.text = "Select judge...";
    else if (/^select\b/i.test(first.text)) first.text = "Select...";
  }
  function applyClean(){
    document.querySelectorAll("select").forEach(sel => {
      sel.querySelectorAll("option").forEach(opt => {
        if (opt && opt.text != null) opt.text = cleanAscii(opt.text);
      });
      normalizePlaceholders(sel);
    });
  }
  // Initial + follow-ups
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", applyClean);
  } else { applyClean(); }
  setTimeout(applyClean, 250);
  setTimeout(applyClean, 1000);

  const obs = new MutationObserver(() => applyClean());
  obs.observe(document.documentElement, {childList:true, subtree:true, characterData:true});

  window.WH_CleanOnsiteSelects = applyClean; // manual trigger if needed
})();
'@
Write-Text $SanJsPath $sanJs
Write-Host "Wrote sanitizer: onsite-clean-selects.js" -ForegroundColor Cyan

# 4) Ensure the sanitizer is referenced from onsite.html & landing.html
$pages = @(
  Join-Path $WebRoot 'onsite.html'),
  (Join-Path $WebRoot 'landing.html')
) | Where-Object { Test-Path $_ }

foreach($p in $pages){
  $h = Read-Text $p
  if($h -notmatch 'onsite-clean-selects\.js'){
    $h = $h -replace '(?is)</body>','  <script src="onsite-clean-selects.js"></script>' + [Environment]::NewLine + '</body>'
    Write-Text $p $h
    Write-Host ("Added script tag in {0}" -f (Split-Path $p -Leaf)) -ForegroundColor Cyan
  } else {
    Write-Host ("Script already present in {0}" -f (Split-Path $p -Leaf)) -ForegroundColor DarkGray
  }
}

Write-Host "`nDone. Hard-refresh (Ctrl+F5). If anything lingers, run in console: WH_CleanOnsiteSelects();" -ForegroundColor Yellow

