# fix_blind_page.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"

# Locate blind page
$blind = Join-Path $root "blind-taste.html"
if (!(Test-Path $blind)) {
  $alt = Join-Path $root "blindtaste.html"
  if (Test-Path $alt) { $blind = $alt } else { throw "Blind Taste page not found (blind-taste.html or blindtaste.html)" }
}

# Backup
$bak = "$blind.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $blind -Destination $bak -Force

# Read
$html = Get-Content -LiteralPath $blind -Raw -Encoding UTF8

# 1) Ensure Supabase JS CDN + supabase-config.js are present (before </body>)
$needSbJs   = ($html -notmatch '@supabase/supabase-js')
$needConfig = ($html -notmatch '(?i)\bsupabase-config\.js')

$sbJsTag    = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
$configTag  = '<script src="supabase-config.js"></script>'

if ($needSbJs -or $needConfig) {
  $injectLibs = ($needSbJs ? ($sbJsTag + "`r`n") : '') + ($needConfig ? ($configTag + "`r`n") : '')
  if ($html -match '(?is)</body\s*>') {
    $html = [regex]::Replace($html,'(?is)</body\s*>', $injectLibs + '</body>', 1)
  } else {
    $html += "`r`n" + $injectLibs
  }
}

# 2) Remove any prior duplicate blocks we injected
$html = [regex]::Replace($html, '(?is)<!--\s*BT_INJECT_START\s*-->[\s\S]*?<!--\s*BT_INJECT_END\s*-->', '')
$html = [regex]::Replace($html, '(?is)<div\b[^>]*\bid\s*=\s*"bt-select-card"[^>]*>[\s\S]*?</div>', '')  # orphaned card, if any

# 3) Inject the minimal, working entry card + script (Judge, Chip, Score)
$block = @'
<!-- BT_INJECT_START -->
<div class="card" id="bt-select-card" style="margin-top:8px;">
  <h2 style="margin:0 0 6px 0;">Blind Taste Entry</h2>
  <div id="bt-selects" style="display:flex;gap:12px;align-items:flex-end;flex-wrap:wrap;">
    <label style="display:flex;flex-direction:column;">Judge
      <select id="btJudgeSel" class="input" style="min-width:180px;"></select>
    </label>
    <label style="display:flex;flex-direction:column;">Chip #
      <select id="btChipSel" class="input" style="min-width:140px;"></select>
    </label>
    <label style="display:flex;flex-direction:column;">Score
      <input id="btScore" type="number" step="0.5" min="0" max="10" class="input" placeholder="0–10" style="min-width:110px;">
    </label>
    <button id="btSaveBtn" class="btn">Save Blind Score</button>
  </div>
  <div id="btMsg" class="muted" style="margin-top:6px;"></div>
</div>

<script>
(function(){
  document.addEventListener('DOMContentLoaded', () => {
    const supa = window.supabase;
    const $ = (id) => document.getElementById(id);
    const els = { j: $('btJudgeSel'), c: $('btChipSel'), s: $('btScore'), save: $('btSaveBtn') };
    const msg = (t, ok=false) => { const n=$('btMsg'); if(!n) return; n.textContent=t||''; n.style.color = ok ? '#056d2a' : '#a33'; };

    async function loadJudges(){
      if (!supa) { fallbackJudges(); return; }
      try {
        const { data, error } = await supa.from('judges').select('id,name').order('name', { ascending: true });
        if (error) throw error;
        const rows = data || [];
        if (!rows.length) { fallbackJudges(); return; }
        els.j.innerHTML = '<option value="">Select Judge…</option>' + rows.map(r => {
          const val = r.name || String(r.id || '').trim();
          const lbl = r.name || ('Judge ' + r.id);
          return `<option value="${val}">${lbl}</option>`;
        }).join('');
      } catch(e) {
        console.warn('judges load failed, using fallback.', e);
        fallbackJudges();
      }
    }
    function fallbackJudges(){
      els.j.innerHTML = '<option value="">Select Judge…</option>' + Array.from({length:6},(_,i)=>`<option value="Judge ${i+1}">Judge ${i+1}</option>`).join('');
    }

    async function loadChips(){
      if (!supa) { fallbackChips(); return; }
      try {
        const { data, error } = await supa.from('teams').select('chip_number, team_name').order('team_name', { ascending: true });
        if (error) throw error;
        const rows = (data||[]).filter(r => (r.chip_number||'').toString().trim() !== '');
        if (!rows.length) { fallbackChips(); return; }
        els.c.innerHTML = '<option value="">Select Chip…</option>' + rows.map(r => {
          const ch = String(r.chip_number).toUpperCase();
          const tn = (r.team_name||'').replace(/</g,'&lt;');
          return `<option value="${ch}">${ch} — ${tn}</option>`;
        }).join('');
      } catch(e) {
        console.warn('chips load failed, using fallback.', e);
        fallbackChips();
      }
    }
    function fallbackChips(){
      els.c.innerHTML = '<option value="">Select Chip…</option><option value="A1">A1</option><option value="A2">A2</option><option value="A3">A3</option>';
    }

    async function doSave(){
      msg('');
      const chip  = (els.c.value || '').trim().toUpperCase();
      const judge = (els.j.value || '').trim();
      const score = parseFloat(els.s.value);
      if (!chip)  return msg('Pick a Chip #.', false);
      if (!judge) return msg('Pick a Judge.',  false);
      if (isNaN(score)) return msg('Enter a numeric score.', false);

      if (!supa) { return msg('Supabase not available on this page.', false); }

      const payload = { chip_number: chip, judge: judge, score: score };
      const { error } = await supa.from('blind_scores').insert(payload);
      if (error) { console.warn(error); return msg('Save failed. ' + (error.message||''), false); }
      msg('Saved!', true);
      els.s.value = '';
    }

    // Initialize
    loadJudges();
    loadChips();
    if (els.save) els.save.addEventListener('click', (e)=>{ e.preventDefault(); doSave(); });
  });
})();
</script>
<!-- BT_INJECT_END -->
'@

# Insert block after first .container or before </body>
if ($html -match '(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bcontainer\b[^"]*"[^>]*>)') {
  $html = [regex]::Replace($html, '(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bcontainer\b[^"]*"[^>]*>)', '$1' + "`r`n" + $block, 1)
} elseif ($html -match '(?is)</body\s*>') {
  $html = [regex]::Replace($html, '(?is)</body\s*>', $block + "`r`n</body>", 1)
} else {
  $html += "`r`n" + $block
}

# Write back
Set-Content -LiteralPath $blind -Encoding UTF8 -Value $html
Write-Host "✅ Blind Taste page cleaned and fixed. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $blind
