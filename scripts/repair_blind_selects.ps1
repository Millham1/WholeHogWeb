# repair_blind_selects.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"

# --- Files ---
$blind = Join-Path $root "blind-taste.html"
if (!(Test-Path $blind)) {
  $alt = Join-Path $root "blindtaste.html"
  if (Test-Path $alt) { $blind = $alt } else { throw "Blind Taste page not found (blind-taste.html or blindtaste.html)" }
}
$config = Join-Path $root "supabase-config.js"
if (!(Test-Path $config)) { throw "supabase-config.js not found at $config" }

# --- Backups ---
function Backup-File($path){
  $bak = "$path.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
  Copy-Item -LiteralPath $path -Destination $bak -Force
  return $bak
}
$blindBak  = Backup-File $blind
$configBak = Backup-File $config

# --- 1) Make supabase-config.js expose a GLOBAL client (window.supabase) ---
# Uses your provided URL/key
$supaUrl = 'https://wiolulxxfyetvdpnfusq.supabase.co'
$supaKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc'

$configJs = @"
;(function(){
  try{
    // Expect the Supabase UMD library to be on window.supabase
    if (!window.supabase || !window.supabase.createClient) {
      console.error('Supabase UMD library missing. Ensure the CDN script loads BEFORE this file.');
      return;
    }
    const { createClient } = window.supabase;
    // Create a global client that other inline scripts can use directly
    window.supabaseClient = createClient('$supaUrl', '$supaKey');
    window.supabase = window.supabaseClient;
    console.log('[supabase-config] client ready');
  }catch(e){
    console.error('[supabase-config] init failed', e);
  }
})();
"@
Set-Content -LiteralPath $config -Encoding UTF8 -Value $configJs

# --- 2) Ensure Blind page loads CDN BEFORE supabase-config.js ---
$blindHtml = Get-Content -LiteralPath $blind -Raw -Encoding UTF8
$hasCdn = ($blindHtml -match '@supabase/supabase-js')
$hasCfg = ($blindHtml -match '(?i)\bsupabase-config\.js')

$cdnTag = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
$cfgTag = '<script src="supabase-config.js"></script>'

if ($hasCdn -and $hasCfg) {
  # Ensure correct order: CDN must appear before config
  if ($blindHtml.IndexOf($cdnTag) -gt $blindHtml.IndexOf($cfgTag)) {
    # Remove both then re-insert in correct order just before </body>
    $blindHtml = $blindHtml -replace [regex]::Escape($cdnTag), ''
    $blindHtml = $blindHtml -replace '(?is)<script[^>]*\bsrc\s*=\s*["'']supabase-config\.js["''][^>]*>\s*</script>', ''
    if ($blindHtml -match '(?is)</body\s*>') {
      $blindHtml = [regex]::Replace($blindHtml,'(?is)</body\s*>', ($cdnTag + "`r`n" + $cfgTag + "`r`n</body>"), 1)
    } else {
      $blindHtml += "`r`n$cdnTag`r`n$cfgTag"
    }
  }
} else {
  # Insert missing tags (in correct order) just before </body> or append
  $insertion = @()
  if (-not $hasCdn) { $insertion += $cdnTag }
  if (-not $hasCfg) { $insertion += $cfgTag }
  $bundle = ($insertion -join "`r`n") + "`r`n"
  if ($blindHtml -match '(?is)</body\s*>') {
    $blindHtml = [regex]::Replace($blindHtml,'(?is)</body\s*>', ($bundle + '</body>'), 1)
  } else {
    $blindHtml += "`r`n$bundle"
  }
}

# --- 3) Remove any prior injected duplicate entry blocks ---
$blindHtml = [regex]::Replace($blindHtml, '(?is)<!--\s*BT_INJECT_START\s*-->[\s\S]*?<!--\s*BT_INJECT_END\s*-->', '')
$blindHtml = [regex]::Replace($blindHtml, '(?is)<div\b[^>]*\bid\s*=\s*"bt-select-card"[^>]*>[\s\S]*?</div>', '')

# --- 4) Inject a single, working Judge/Chip block that populates from Supabase ---
$entryBlock = @'
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
  document.addEventListener('DOMContentLoaded', async () => {
    // We expect a ready client on window.supabase (set by supabase-config.js)
    const client = (window.supabase && typeof window.supabase.from === 'function') ? window.supabase : null;
    const $ = (id) => document.getElementById(id);
    const els = { j: $('btJudgeSel'), c: $('btChipSel'), s: $('btScore'), save: $('btSaveBtn') };
    const msg = (t, ok=false) => { const n=$('btMsg'); if(!n) return; n.textContent=t||''; n.style.color = ok ? '#056d2a' : '#a33'; };

    function fallbackJudges(){
      els.j.innerHTML = '<option value="">Select Judge…</option>' +
        Array.from({length:6},(_,i)=>`<option value="Judge ${i+1}">Judge ${i+1}</option>`).join('');
    }
    function fallbackChips(){
      els.c.innerHTML = '<option value="">Select Chip…</option><option value="A1">A1</option><option value="A2">A2</option><option value="A3">A3</option>';
    }

    async function loadJudges(){
      try{
        if(!client) throw new Error('client not ready');
        const { data, error } = await client.from('judges').select('id,name').order('name', { ascending: true });
        if (error) throw error;
        const rows = data || [];
        if (!rows.length) { fallbackJudges(); return; }
        els.j.innerHTML = '<option value="">Select Judge…</option>' + rows.map(r=>{
          const val = r.name || String(r.id||'').trim();
          const lbl = r.name || ('Judge ' + r.id);
          return `<option value="${val}">${lbl}</option>`;
        }).join('');
      }catch(e){ console.warn('judges load fallback:', e); fallbackJudges(); }
    }

    async function loadChips(){
      try{
        if(!client) throw new Error('client not ready');
        const { data, error } = await client.from('teams').select('chip_number, team_name').order('team_name', { ascending: true });
        if (error) throw error;
        const rows = (data||[]).filter(r => (r.chip_number||'').toString().trim() !== '');
        if (!rows.length) { fallbackChips(); return; }
        els.c.innerHTML = '<option value="">Select Chip…</option>' + rows.map(r=>{
          const ch = String(r.chip_number).toUpperCase();
          const tn = (r.team_name||'').replace(/</g,'&lt;');
          return `<option value="${ch}">${ch} — ${tn}</option>`;
        }).join('');
      }catch(e){ console.warn('chips load fallback:', e); fallbackChips(); }
    }

    async function saveBlind(){
      msg('');
      const chip  = (els.c.value || '').trim().toUpperCase();
      const judge = (els.j.value || '').trim();
      const score = parseFloat(els.s.value);
      if (!chip)  return msg('Pick a Chip #.', false);
      if (!judge) return msg('Pick a Judge.',  false);
      if (isNaN(score)) return msg('Enter a numeric score.', false);
      if (!client) return msg('Supabase client not available on this page.', false);

      const payload = { chip_number: chip, judge: judge, score: score };
      const { error } = await client.from('blind_scores').insert(payload);
      if (error) { console.warn(error); return msg('Save failed. ' + (error.message||''), false); }
      msg('Saved!', true);
      els.s.value = '';
    }

    await loadJudges();
    await loadChips();
    if (els.save) els.save.addEventListener('click', (e)=>{ e.preventDefault(); saveBlind(); });
  });
})();
</script>
<!-- BT_INJECT_END -->
'@

# Place block just before </body> for safest load order
if ($blindHtml -match '(?is)</body\s*>') {
  $blindHtml = [regex]::Replace($blindHtml,'(?is)</body\s*>', ($entryBlock + "`r`n</body>"), 1)
} else {
  $blindHtml += "`r`n" + $entryBlock
}

Set-Content -LiteralPath $blind -Encoding UTF8 -Value $blindHtml

Write-Host "✅ Fixed blind page: global client ensured, single entry card, dropdowns populated. Backups: $([IO.Path]::GetFileName($blindBak)), $([IO.Path]::GetFileName($configBak))" -ForegroundColor Green
Start-Process $blind
