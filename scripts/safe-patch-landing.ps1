param(
  [string]$Root = ".",
  [string]$LandingFile = "landing.html"
)

$ErrorActionPreference = "Stop"

# Paths
$rootPath   = Resolve-Path $Root
$landingPath = Join-Path $rootPath $LandingFile
if (!(Test-Path $landingPath)) { Write-Error "Landing file not found: $landingPath"; exit 1 }

# Read full file
$text = Get-Content -Path $landingPath -Raw

# ---------------------------
# 1) Strip Supabase <script> tags using simple scanning (no regex)
# ---------------------------
function Remove-SupabaseScripts([string]$html) {
  $sb = New-Object System.Text.StringBuilder
  $i = 0
  while ($i -lt $html.Length) {
    $idx = $html.IndexOf("<script", $i, [System.StringComparison]::OrdinalIgnoreCase)
    if ($idx -lt 0) { [void]$sb.Append($html.Substring($i)); break }
    # Append text up to the <script
    [void]$sb.Append($html.Substring($i, $idx - $i))
    # Find end of open tag
    $gt = $html.IndexOf(">", $idx)
    if ($gt -lt 0) { [void]$sb.Append($html.Substring($idx)); break }
    $openTag = $html.Substring($idx, $gt - $idx + 1)
    if ($openTag -match '(?i)supabase') {
      # Remove until </script>
      $endTag = $html.IndexOf("</script>", $gt+1, [System.StringComparison]::OrdinalIgnoreCase)
      if ($endTag -ge 0) {
        $i = $endTag + 9 # length of </script>
        continue
      } else {
        # No closing tag; drop the rest
        break
      }
    } else {
      # Keep this script tag + proceed
      [void]$sb.Append($openTag)
      $i = $gt + 1
    }
  }
  return $sb.ToString()
}
$text = Remove-SupabaseScripts $text

# ---------------------------
# 2) Fix any blind-taste links → blind.html (simple string replace)
# ---------------------------
$text = $text -replace '(?i)href\s*=\s*"\s*blind[\s-]*taste\.html\s*"', 'href="blind.html"'

# ---------------------------
# 3) Ensure nav has Blind Taste link to blind.html (insert before first </nav>)
# ---------------------------
if ($text -match '(?is)<nav\b') {
  # Find first nav start and its closing </nav>
  $navStart = [regex]::Match($text, '(?is)<nav\b[^>]*>').Index
  $navClose = $text.IndexOf('</nav>', $navStart, [System.StringComparison]::OrdinalIgnoreCase)
  if ($navClose -gt 0) {
    $navBlock = $text.Substring($navStart, $navClose - $navStart + 6)
    if ($navBlock -notmatch '(?i)href\s*=\s*"\s*blind\.html\s*"') {
      $insertion = '  <a href="blind.html">Blind Taste</a>' + [Environment]::NewLine
      $newNav = $navBlock.Insert($navBlock.Length - 6, $insertion)
      $text = $text.Remove($navStart, $navBlock.Length).Insert($navStart, $newNav)
    }
  }
}

# ---------------------------
# 4) Append Setup panel (judges/chips) and Entries viewer blocks if not already present
# ---------------------------
$hasSetup   = $text -match '<!--\s*BEGIN\s*JudgesChipsSetup\s*-->'
$hasEntries = $text -match '<!--\s*BEGIN\s*EntriesViewer\s*-->' 

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
  try{
    const j=JSON.parse(localStorage.getItem(KJ)||'[]'), c=JSON.parse(localStorage.getItem(KC)||'[]');
    if(j.length) txtJ.value=j.join('\\n'); if(c.length) txtC.value=c.join('\\n');
  }catch(e){}
})();
</script>
<!-- END JudgesChipsSetup -->
'@

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

# Simple insertion helper
function Add-BeforeClosingTag([string]$html, [string]$block) {
  $idx = $html.LastIndexOf('</body>', [System.StringComparison]::OrdinalIgnoreCase)
  if ($idx -ge 0) { return $html.Insert($idx, "`r`n$block`r`n") }
  $idx = $html.LastIndexOf('</html>', [System.StringComparison]::OrdinalIgnoreCase)
  if ($idx -ge 0) { return $html.Insert($idx, "`r`n$block`r`n") }
  return $html + "`r`n$block`r`n"
}

if (-not $hasSetup)   { $text = Add-BeforeClosingTag $text $setupBlock }
if (-not $hasEntries) { $text = Add-BeforeClosingTag $text $entriesBlock }

# Backup and write
$backup = Join-Path $rootPath ("landing.backup-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".html")
Copy-Item $landingPath $backup -Force
$text | Set-Content -Path $landingPath -Encoding UTF8

Write-Host "✅ Patched ${LandingFile}:"
Write-Host "   - Removed Supabase scripts"
Write-Host "   - Ensured Blind Taste link points to blind.html"
Write-Host "   - Added/kept Judges & Chips Setup panel"
Write-Host "   - Added/kept Current Entries viewer"
Write-Host ("Backup: " + $backup)
Write-Host ("Open: file:///" + ((Resolve-Path $landingPath).Path -replace '\\','/'))
