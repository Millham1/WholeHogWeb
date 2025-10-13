# wire_blind_minimal.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"

function Backup-File($path){
  if (!(Test-Path $path)) { throw "File not found: $path" }
  $bak = "$path.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
  Copy-Item -LiteralPath $path -Destination $bak -Force
  return $bak
}

# ---------- Locate pages ----------
$blind = Join-Path $root "blind-taste.html"
if (!(Test-Path $blind)) {
  $blindAlt = Join-Path $root "blindtaste.html"
  if (Test-Path $blindAlt) { $blind = $blindAlt } else { throw "Blind Taste page not found (blind-taste.html or blindtaste.html)" }
}
$leader = Join-Path $root "leaderboard.html"
if (!(Test-Path $leader)) { throw "leaderboard.html not found at $leader" }

# ---------- Inject Judge + Chip (no Team) into Blind Taste ----------
$blindBak = Backup-File $blind
$blindHtml = Get-Content -LiteralPath $blind -Raw -Encoding UTF8

# Remove any older injection from previous attempts
$blindHtml = [regex]::Replace($blindHtml, '(?is)<!--\s*BT_INJECT_START\s*-->[\s\S]*?<!--\s*BT_INJECT_END\s*-->', '')

$blindInject = @'
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
    const $  = (id) => document.getElementById(id);
    const msg = (t, ok=false) => { const n=$('btMsg'); if(!n) return; n.textContent=t||''; n.style.color = ok ? '#056d2a' : '#a33'; };

    const els = {
      j: $('btJudgeSel'),
      c: $('btChipSel'),
      s: $('btScore'),
      save: $('btSaveBtn')
    };
    if (!supa) { console.warn('Supabase not found. Load supabase-config.js before this block.'); return; }

    async function loadJudges(){
      try{
        const { data, error } = await supa.from('judges').select('id,name').order('name', { ascending: true });
        if (error) throw error;
        els.j.innerHTML = '<option value="">Select Judge…</option>' + (data||[]).map(r=>`<option value="${r.name || r.id}">${r.name || ('Judge ' + r.id)}</option>`).join('');
      }catch(e){
        console.warn('judges table not found or not readable; using placeholder.', e);
        els.j.innerHTML = '<option value="">Select Judge…</option><option value="Judge">Judge</option>';
      }
    }

    async function loadChips(){
      const { data, error } = await supa.from('teams').select('chip_number').order('chip_number', { ascending: true });
      if (error) { console.warn('teams load error:', error); els.c.innerHTML=''; return; }
      const chips = (data||[]).map(r => (r.chip_number||'').toString().toUpperCase()).filter(Boolean);
      els.c.innerHTML = '<option value="">Select Chip…</option>' + chips.map(ch => `<option value="${ch}">${ch}</option>`).join('');
    }

    async function saveBlind(){
      msg('');
      const chip  = (els.c.value || '').trim().toUpperCase();
      const judge = (els.j.value || '').trim();
      const score = parseFloat(els.s.value);
      if (!chip)  return msg('Pick a Chip #.', false);
      if (!judge) return msg('Pick a Judge.',  false);
      if (isNaN(score)) return msg('Enter a numeric score.', false);

      const payload = { chip_number: chip, judge: judge, score: score };
      const { error } = await supa.from('blind_scores').insert(payload);
      if (error) { console.warn(error); return msg('Save failed. ' + (error.message||''), false); }
      msg('Saved!', true);
      els.s.value = '';
    }

    (async () => {
      await loadJudges();
      await loadChips();
      if (els.save) els.save.addEventListener('click', (e)=>{ e.preventDefault(); saveBlind(); });
    })();
  });
})();
</script>
<!-- BT_INJECT_END -->
'@

# Insert right after a .container if present, else before </body>, else append
if ($blindHtml -match '(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bcontainer\b[^"]*"[^>]*>)') {
  $blindHtml = [regex]::Replace($blindHtml, '(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bcontainer\b[^"]*"[^>]*>)', '$1' + "`r`n" + $blindInject, 1)
} elseif ($blindHtml -match '(?is)</body\s*>') {
  $blindHtml = [regex]::Replace($blindHtml, '(?is)</body\s*>', $blindInject + "`r`n</body>", 1)
} else {
  $blindHtml += "`r`n" + $blindInject
}

Set-Content -LiteralPath $blind -Encoding UTF8 -Value $blindHtml
Write-Host "✅ Blind Taste page updated (Judge + Chip only). Backup: $([IO.Path]::GetFileName($blindBak))" -ForegroundColor Green

# ---------- Inject Blind Taste leaderboard into leaderboard.html ----------
$leaderBak = Backup-File $leader
$leaderHtml = Get-Content -LiteralPath $leader -Raw -Encoding UTF8

# Remove any older blind leaderboard injection
$leaderHtml = [regex]::Replace($leaderHtml, '(?is)<!--\s*BT_LEADER_START\s*-->[\s\S]*?<!--\s*BT_LEADER_END\s*-->', '')

$leaderInject = @'
<!-- BT_LEADER_START -->
<div class="card" id="bt-leader-card" style="margin-top:8px;">
  <h2 style="margin:0 0 6px 0;">Blind Taste Leaderboard</h2>
  <div id="btLeaderWrap" class="table-wrap"></div>
</div>

<script>
(function(){
  document.addEventListener('DOMContentLoaded', async () => {
    const supa = window.supabase;
    const wrap = document.getElementById('btLeaderWrap');
    if (!supa || !wrap) return;

    function renderTable(rows){
      if (!rows || !rows.length) { wrap.innerHTML = '<div class="muted">No blind taste scores yet.</div>'; return; }
      const t = document.createElement('table');
      t.className = 'table';
      t.innerHTML = `
        <thead><tr><th style="text-align:left;">Rank</th><th style="text-align:left;">Team</th><th>Total</th><th>Entries</th></tr></thead>
        <tbody>
          ${rows.map((r,i)=>`<tr><td>${i+1}</td><td style="text-align:left;">${r.team}</td><td>${r.total.toFixed(2)}</td><td>${r.count}</td></tr>`).join('')}
        </tbody>`;
      wrap.innerHTML = ''; wrap.appendChild(t);
    }

    try{
      // Map chip -> team
      const { data: teams, error: tErr } = await supa.from('teams').select('chip_number, team_name');
      if (tErr) throw tErr;
      const teamByChip = new Map((teams||[]).map(r => [String(r.chip_number||'').toUpperCase(), r.team_name || '']));

      // Fetch blind scores
      const { data: scores, error: sErr } = await supa.from('blind_scores').select('chip_number, score');
      if (sErr) throw sErr;

      // Aggregate totals BY TEAM NAME (via chip -> team mapping)
      const agg = new Map(); // team -> { total, count }
      (scores||[]).forEach(r => {
        const chip = String(r.chip_number||'').toUpperCase();
        const team = teamByChip.get(chip) || '(Unknown Team)';
        const val = Number(r.score||0);
        const cur = agg.get(team) || { total:0, count:0 };
        cur.total += val; cur.count += 1;
        agg.set(team, cur);
      });

      const rows = Array.from(agg.entries()).map(([team, o]) => ({
        team, total: o.total, count: o.count
      })).sort((a,b)=> b.total - a.total);

      renderTable(rows);
    }catch(e){
      console.warn('Blind leaderboard error:', e);
      wrap.innerHTML = '<div class="muted">Unable to load blind leaderboard.</div>';
    }
  });
})();
</script>
<!-- BT_LEADER_END -->
'@

# Insert leaderboard block
if ($leaderHtml -match '(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bcontainer\b[^"]*"[^>]*>)') {
  $leaderHtml = [regex]::Replace($leaderHtml, '(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bcontainer\b[^"]*"[^>]*>)', '$1' + "`r`n" + $leaderInject, 1)
} elseif ($leaderHtml -match '(?is)</body\s*>') {
  $leaderHtml = [regex]::Replace($leaderHtml, '(?is)</body\s*>', $leaderInject + "`r`n</body>", 1)
} else {
  $leaderHtml += "`r`n" + $leaderInject
}

Set-Content -LiteralPath $leader -Encoding UTF8 -Value $leaderHtml
Write-Host "✅ Leaderboard updated for Blind Taste (team totals). Backup: $([IO.Path]::GetFileName($leaderBak))" -ForegroundColor Green

# ---------- Write SQL helper (optional) ----------
$sqlPath = Join-Path $root "db_blind_schema.sql"
$sql = @'
-- Create table for blind taste scores (idempotent)
create table if not exists blind_scores (
  id bigserial primary key,
  chip_number text not null,
  judge text not null,
  score numeric not null,
  created_at timestamp with time zone default now()
);

-- Optional FK if teams.chip_number is unique:
-- alter table blind_scores
--   add constraint blind_scores_chip_fk
--   foreign key (chip_number) references teams(chip_number) on delete cascade;
'@
Set-Content -LiteralPath $sqlPath -Encoding UTF8 -Value $sql
Write-Host "📄 Wrote SQL helper: $sqlPath (paste into Supabase SQL editor if needed)." -ForegroundColor Cyan

Write-Host "`nDone. Refresh Blind Taste and Leaderboard (Ctrl+F5)." -ForegroundColor Green
