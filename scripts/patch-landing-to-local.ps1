param(
  [string]$Root = ".",
  [string]$LandingFile = "landing.html"
)

$ErrorActionPreference = "Stop"

$rootPath = Resolve-Path $Root
$landingPath = Join-Path $rootPath $LandingFile
if (!(Test-Path $landingPath)) { Write-Error "Landing file not found: $landingPath"; exit 1 }

# Read landing file
$html = Get-Content -Path $landingPath -Raw

# 1) Remove any Supabase <script> tags (common CDNs)
#    This does NOT touch other scripts. It only strips tags whose src contains "supabase".
$html = [regex]::Replace($html, '(?is)<script[^>]+src=["''][^"'']*supabase[^"'']*["''][^>]*>\s*</script>', '')

# 2) Fix any wrong link to Blind page (blind-taste.html / blindtaste.html -> blind.html)
$html = $html -replace '(?i)href\s*=\s*["'']\s*blind(?:-|\s*)?taste\.html\s*["'']', 'href="blind.html"'

# 3) Ensure the header nav has a Blind Taste link; if no <nav> exists, skip gracefully
$navMatch = [regex]::Match($html, '(?is)<nav\b[^>]*>(.*?)</nav>')
if ($navMatch.Success) {
  $navBlock = $navMatch.Value
  if ($navBlock -notmatch '(?is)href\s*=\s*["'']\s*blind\.html["'']') {
    # Insert a Blind link before </nav>
    $navUpdated = [regex]::Replace($navBlock, '(?is)</nav\s*>', '  <a href="blind.html">Blind Taste</a>' + [Environment]::NewLine + '</nav>', 1)
    $html = $html.Remove($navMatch.Index, $navMatch.Length).Insert($navMatch.Index, $navUpdated)
  }
}

# 4) Add/refresh the Judges & Chips Setup panel (writes judgesList/chipsList to localStorage)
#    Remove any previous injected block by these markers
$html = [regex]::Replace($html, '<!--\s*BEGIN\s*JudgesChipsSetup\s*-->.*?<!--\s*END\s*JudgesChipsSetup\s*-->', '', 'Singleline, IgnoreCase')

$setupBlock = @'
<!-- BEGIN JudgesChipsSetup -->
<style>
  .setup-card{max-width:1100px;margin:16px auto;padding:16px;border-radius:14px;background:#fff;box-shadow:0 6px 24px rgba(0,0,0,.06);font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}
  .setup-card h2{margin:0 0 8px 0}
  .setup-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}
  .setup-grid label{font-weight:700;display:block;margin-bottom:6px}
  .setup-grid textarea{width:100%;height:160px;padding:10px12px;border:1px solid #d1d5db;border-radius:10px;resize:vertical}
  .setup-actions{display:flex;flex-wrap:wrap;gap:10px;margin-top:12px}
  .setup-btn{border:0;border-radius:10px;padding:10px14px;cursor:pointer;font-weight:700}
  .primary{background:#0d6efd;color:#fff}
  .ghost{background:transparent;border:1px solid #d1d5db;color:#111}
  .ok{background:#198754;color:#fff}
  .muted{color:#6b7280;font-size:12px;margin-top:6px}
</style>
<section class="setup-card" id="judges-chips-setup" aria-labelledby="setup-title">
  <h2 id="setup-title">Setup: Judges & Chips (local)</h2>
  <div class="muted">Enter one per line. Click <b>Save Lists</b> to publish to this browser. <code>blind.html</code> will use these as its dropdowns.</div>
  <div class="setup-grid" style="margin-top:12px">
    <div>
      <label for="setup-judges">Judges (one per line)</label>
      <textarea id="setup-judges" placeholder="Judge A&#10;Judge B&#10;Judge C"></textarea>
    </div>
    <div>
      <label for="setup-chips">Chip #s (one per line)</label>
      <textarea id="setup-chips" placeholder="1&#10;2&#10;3&#10;4&#10;5"></textarea>
    </div>
  </div>
  <div class="setup-actions">
    <button type="button" class="setup-btn primary" id="setup-save">Save Lists</button>
    <button type="button" class="setup-btn ghost"   id="setup-load">Load Current</button>
    <button type="button" class="setup-btn ghost"   id="setup-clear">Clear Lists</button>
    <button type="button" class="setup-btn ok"      id="setup-open-blind">Open Blind Taste</button>
  </div>
  <div class="muted">Keys: <code>localStorage.judgesList</code>, <code>localStorage.chipsList</code>.</div>
</section>
<script>
(function(){
  const KJ='judgesList', KC='chipsList';
  const $ = s=>document.querySelector(s);
  const txtJ = $('#setup-judges'), txtC = $('#setup-chips');
  function parseLines(t){ return Array.from(new Set(String(t||'').split(/\r?\n/).map(s=>s.trim()).filter(Boolean))); }
  function save(){
    const judges=parseLines(txtJ.value);
    let chips=parseLines(txtC.value).filter(x=>/^\d+$/.test(x)).sort((a,b)=>Number(a)-Number(b));
    try{ localStorage.setItem(KJ,JSON.stringify(judges)); localStorage.setItem(KC,JSON.stringify(chips));
      alert('Saved '+judges.length+' judges and '+chips.length+' chips to localStorage.');
    }catch(e){ alert('Unable to save: '+e); }
  }
  function load(){
    try{ const j=JSON.parse(localStorage.getItem(KJ)||'[]'); const c=JSON.parse(localStorage.getItem(KC)||'[]');
      txtJ.value=j.join('\\n'); txtC.value=c.join('\\n'); alert('Loaded current lists.');
    }catch(e){ alert('Unable to load: '+e); }
  }
  function clearAll(){
    try{ localStorage.removeItem(KJ); localStorage.removeItem(KC); alert('Cleared judgesList and chipsList.'); }
    catch(e){ alert('Unable to clear: '+e); }
  }
  function openBlind(){
    const here=location.href; const blind=here.replace(/[^\/]+$/, '') + 'blind.html'; window.open(blind,'_blank');
  }
  document.getElementById('setup-save').addEventListener('click',save);
  document.getElementById('setup-load').addEventListener('click',load);
  document.getElementById('setup-clear').addEventListener('click',clearAll);
  document.getElementById('setup-open-blind').addEventListener('click',openBlind);
  // Auto-prefill from current storage
  try{
    const j=JSON.parse(localStorage.getItem(KJ)||'[]'), c=JSON.parse(localStorage.getItem(KC)||'[]');
    if(j.length) txtJ.value=j.join('\\n'); if(c.length) txtC.value=c.join('\\n');
  }catch(e){}
})();
</script>
<!-- END JudgesChipsSetup -->
'@

# Insert Setup block before </body> or </html>
if ($html -match '</body\s*>') {
  $html = [regex]::Replace($html, '</body\s*>', "`r`n$setupBlock`r`n</body>", 1, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
} elseif ($html -match '</html\s*>') {
  $html = [regex]::Replace($html, '</html\s*>', "`r`n$setupBlock`r`n</html>", 1, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
} else {
  $html += "`r`n$setupBlock`r`n"
}

# 5) Add a "Current Entries" viewer (reads localStorage.blindTasteEntries)
#    Remove any previous block with our markers first
$html = [regex]::Replace($html, '<!--\s*BEGIN\s*EntriesViewer\s*-->.*?<!--\s*END\s*EntriesViewer\s*-->', '', 'Singleline, IgnoreCase')

$entriesBlock = @'
<!-- BEGIN EntriesViewer -->
<style>
  .entries-card{max-width:1100px;margin:16px auto;padding:16px;border-radius:14px;background:#fff;box-shadow:0 6px 24px rgba(0,0,0,.06);font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif}
  .entries-card h2{margin:0 0 8px 0}
  .entries-actions{display:flex;gap:10px;flex-wrap:wrap;margin:8px 0}
  .entries-btn{border:0;border-radius:10px;padding:8px 12px;cursor:pointer;font-weight:700}
  .ghost{background:transparent;border:1px solid #d1d5db;color:#111}
  .ok{background:#198754;color:#fff}
  .muted{color:#6b7280;font-size:12px;margin-top:6px}
  table.entries{width:100%;border-collapse:collapse;margin-top:8px}
  table.entries th, table.entries td{border:1px solid #e5e7eb;padding:8px;text-align:left}
  table.entries th{background:#f3f4f6}
</style>
<section class="entries-card" id="entries-viewer" aria-labelledby="entries-title">
  <h2 id="entries-title">Current Entries (from this browser)</h2>
  <div class="entries-actions">
    <button type="button" class="entries-btn ghost" id="ev-refresh">Refresh</button>
    <button type="button" class="entries-btn ok"    id="ev-export">Export CSV</button>
  </div>
  <div class="muted">Source key: <code>localStorage.blindTasteEntries</code>. Saved by <code>blind.html</code>.</div>
  <div id="ev-summary" class="muted" style="margin-top:6px"></div>
  <div id="ev-table-wrap" style="overflow:auto; max-height:420px; margin-top:8px"></div>
</section>
<script>
(function(){
  const KEY='blindTasteEntries';
  const $ = s=>document.querySelector(s);
  const wrap = $('#ev-table-wrap'), sum = $('#ev-summary');
  function read(){ try{ return JSON.parse(localStorage.getItem(KEY)||'[]'); }catch{ return []; } }
  function toCSV(rows){
    const headers=["timestamp","judge_id","chip_number","score_appearance","score_tenderness","score_flavor","score_total"];
    const out=[headers.join(",")];
    rows.forEach(r=>{
      const line=headers.map(h=>{const v=(r[h]==null)?'':String(r[h]).replace(/"/g,'""'); return `"${v}"`;}).join(",");
      out.push(line);
    });
    return out.join("\\n");
  }
  function render(){
    const rows=read();
    const byChip=new Map(); const byJudge=new Map();
    rows.forEach(r=>{
      const c=String(r.chip_number), j=String(r.judge_id);
      byChip.set(c,(byChip.get(c)||0)+1);
      byJudge.set(j,(byJudge.get(j)||0)+1);
    });
    sum.textContent = `Entries: ${rows.length} | Unique chips: ${byChip.size} | Unique judges: ${byJudge.size}`;
    if(!rows.length){ wrap.innerHTML='<div class="muted">No entries yet.</div>'; return; }
    const thead=`<thead><tr>
      <th>Timestamp</th><th>Judge</th><th>Chip #</th>
      <th>Appearance</th><th>Tenderness</th><th>Taste</th><th>Total</th>
    </tr></thead>`;
    const tbody = rows.map(r=>`<tr>
      <td>${r.timestamp||''}</td>
      <td>${r.judge_id||''}</td>
      <td>${r.chip_number||''}</td>
      <td>${r.score_appearance||''}</td>
      <td>${r.score_tenderness||''}</td>
      <td>${r.score_flavor||''}</td>
      <td>${r.score_total||''}</td>
    </tr>`).join("");
    wrap.innerHTML = `<table class="entries">${thead}<tbody>${tbody}</tbody></table>`;
  }
  function exportCSV(){
    const csv=toCSV(read());
    if(!csv){ alert('No data'); return; }
    const blob=new Blob([csv],{type:'text/csv'}); const url=URL.createObjectURL(blob);
    const a=document.createElement('a'); a.href=url; a.download='blind_entries.csv'; document.body.appendChild(a); a.click(); a.remove(); URL.revokeObjectURL(url);
  }
  document.getElementById('ev-refresh').addEventListener('click',render);
  document.getElementById('ev-export').addEventListener('click',exportCSV);
  render();
})();
</script>
<!-- END EntriesViewer -->
'@

# Insert Entries viewer block before </body> or </html>
if ($html -match '</body\s*>') {
  $html = [regex]::Replace($html, '</body\s*>', "`r`n$entriesBlock`r`n</body>", 1, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
} elseif ($html -match '</html\s*>') {
  $html = [regex]::Replace($html, '</html\s*>', "`r`n$entriesBlock`r`n</html>", 1, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
} else {
  $html += "`r`n$entriesBlock`r`n"
}

# Backup and write
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $landingPath (Join-Path $rootPath ("landing.backup-" + $stamp + ".html")) -Force
$html | Set-Content -Path $landingPath -Encoding UTF8

Write-Host "✅ Patched ${LandingFile}:"
Write-Host "   - Removed Supabase script tags"
Write-Host "   - Ensured Blind Taste link points to blind.html (created if missing)"
Write-Host "   - Added Judges & Chips Setup panel (localStorage)"
Write-Host "   - Added Current Entries viewer (reads blindTasteEntries)"
Write-Host ("Open: file:///" + ((Resolve-Path $landingPath).Path -replace '\\','/'))

