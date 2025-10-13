param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

$ErrorActionPreference = 'Stop'

$landingJs = Join-Path $WebRoot "landing-sb.js"
if (-not (Test-Path $landingJs)) {
  throw "landing-sb.js not found at $landingJs"
}

# Backup once
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$bak = Join-Path $WebRoot ("BACKUP_judges_move_" + $stamp)
New-Item -ItemType Directory -Force -Path $bak | Out-Null
Copy-Item $landingJs (Join-Path $bak (Split-Path $landingJs -Leaf)) -Force
Write-Host "Backup saved: $bak" -ForegroundColor Yellow

# JS patch that moves the judge input + button to the top of the Judges card
$marker = "/* WH tweak: move judge entry to top */"
$patch = @"
$marker
(function(){
  try {
    var list = document.getElementById('judgesList');
    if(!list) return;
    var card = (list.closest && list.closest('.card')) || list.parentElement;
    if(!card) return;

    // Find header inside card
    var h2 = card.querySelector('h2');
    if(!h2) return;

    // Existing controls
    var input = document.getElementById('judgeName');
    var btn   = document.getElementById('btnAddJudge');

    if(!input && !btn) return;

    // Build a top row for input
    var rowInput = document.createElement('div');
    rowInput.className = 'row judge-entry-top';
    if(input){
      var lbl = document.createElement('label');
      lbl.setAttribute('for','judgeName');
      lbl.textContent = 'Judge Name';
      rowInput.appendChild(lbl);
      rowInput.appendChild(input); // move node
    }

    // Build a row for the Add button (right column)
    var rowBtn = document.createElement('div');
    rowBtn.className = 'row judge-entry-actions';
    var spacer = document.createElement('div');
    spacer.style.width = '160px';
    rowBtn.appendChild(spacer);
    if(btn){ rowBtn.appendChild(btn); } // move node

    // Insert directly after the H2
    if(h2.nextSibling){
      card.insertBefore(rowInput, h2.nextSibling);
      card.insertBefore(rowBtn, rowInput.nextSibling);
    } else {
      card.appendChild(rowInput);
      card.appendChild(rowBtn);
    }
  } catch(e) {
    console.warn('WH judge-entry move failed', e);
  }
})();
"@

# Append once
$js = Get-Content -LiteralPath $landingJs -Raw -Encoding utf8
if ($js -notmatch [regex]::Escape($marker)) {
  $js += "`r`n" + $patch + "`r`n"
  Set-Content -LiteralPath $landingJs -Value $js -Encoding utf8
  Write-Host "Patched landing-sb.js (judge entry moved to top)." -ForegroundColor Cyan
} else {
  Write-Host "Patch already present; no changes made." -ForegroundColor DarkGray
}

Write-Host "Done. Reload landing.html with Ctrl+F5." -ForegroundColor Green
