# blind_capture_categories.ps1
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

# Read HTML
$html = Get-Content -LiteralPath $blind -Raw -Encoding UTF8

# Ensure Supabase UMD + config tags exist and are near the bottom in correct order
$cdnTag = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
$cfgTag = '<script src="supabase-config.js"></script>'
if ($html -notmatch '@supabase/supabase-js') {
  $html = [regex]::Replace($html, '(?is)</body\s*>', $cdnTag + "`r`n</body>", 1)
}
if ($html -notmatch '(?i)\bsupabase-config\.js') {
  $html = [regex]::Replace($html, '(?is)</body\s*>', $cfgTag + "`r`n</body>", 1)
}

# Remove any previously injected blocks to avoid duplicates
$html = [regex]::Replace($html, '(?is)<!--\s*BT_INJECT_START\s*-->[\s\S]*?<!--\s*BT_INJECT_END\s*-->', '')
$html = [regex]::Replace($html, '(?is)<!--\s*BT_SYNC_START\s*-->[\s\S]*?<!--\s*BT_SYNC_END\s*-->', '')
$html = [regex]::Replace($html, '(?is)<div\b[^>]*\bid\s*=\s*"bt-select-card"[^>]*>[\s\S]*?</div>', '')
$html = [regex]::Replace($html, '(?is)<div\b[^>]*\bid\s*=\s*"bt-inline-selects"[^>]*>[\s\S]*?</div>', '')

# Build a small inline row (Judge + Chip) to be inserted inside scoring area
$inline = @'
<div id="bt-inline-selects" style="display:flex;gap:12px;align-items:flex-end;flex-wrap:wrap;margin:6px 0 8px;">
  <label style="display:flex;flex-direction:column;">Judge
    <select id="btJudgeSel" class="input" style="min-width:180px;"></select>
  </label>
  <label style="display:flex;flex-direction:column;">Chip #
    <select id="btChipSel" class="input" style="min-width:140px;"></select>
  </label>
  <!-- hidden tiny fallback if no visible total element exists -->
  <input id="btScoreFallback" type="number" step="0.5" min="0" max="10" style="display:none;">
</div>
'@

# Insert inline selects right after .scoring-top, else as first child of .scoring-wrap, else before first Save button
$inserted = $false
if ([regex]::IsMatch($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-top\b[^"]*"[^>]*>[\s\S]*?</div>)')) {
  $html = [regex]::Replace($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-top\b[^"]*"[^>]*>[\s\S]*?</div>)','$1' + "`r`n" + $inline,1)
  $inserted = $true
} elseif ([regex]::IsMatch($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-wrap\b[^"]*"[^>]*>)')) {
  $html = [regex]::Replace($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-wrap\b[^"]*"[^>]*>)','$1' + "`r`n" + $inline,1)
  $inserted = $true
} elseif ([regex]::IsMatch($html,'(?is)(<button\b[^>]*>(?:(?!</button>).)*?save(?:(?!</button>).)*?</button>)')) {
  $html = [regex]::Replace($html,'(?is)(<button\b[^>]*>(?:(?!</button>).)*?save(?:(?!</button>).)*?</button>)',$inline + '$1',1)
  $inserted = $true
}
if (-not $inserted) {
  $html = [regex]::Replace($html,'(?is)</body\s*>',$inline + "`r`n</body>",1)
}

# Inject the logic that loads dropdowns + saves total and per-category breakdown
$script = @'
<!-- BT_SYNC_START -->
<script>
(function(){
  document.addEventListener('DOMContentLoaded', async () => {
    const SUPA_URL = "https://wiolulxxfyetvdpnfusq.supabase.co";
    const SUPA_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc";

    // Ensure a Supabase client
    let client = null;
    try{
      if (window.supabase && typeof window.supabase.from === "function") {
        client = window.supabase;
      } else if (window.supabase && typeof window.supabase.createClient === "function") {
        client = window.supabase.createClient(SUPA_URL, SUPA_KEY);
        window.supabase = client;
      }
    }catch(e){ console.warn("supabase init error", e); }

    const $ = (id) => document.getElementById(id);
    const els = {
      j: $("btJudgeSel"),
      c: $("btChipSel"),
      fb: $("btScoreFallback"),
      total: document.getElementById("totalVal") || document.getElementById("btTotalVal")
    };

    function ensureOptions(sel, html){ if(sel){ sel.innerHTML = html; sel.removeAttribute("disabled"); } }
    function fallbackJudges(){ ensureOptions(els.j, '<option value="">Select Judge…</option>' + Array.from({length:6},(_,i)=>`<option value="Judge ${i+1}">Judge ${i+1}</option>`).join('')); }
    function fallbackChips(){ ensureOptions(els.c, '<option value="">Select Chip…</option><option value="A1">A1</option><option value="A2">A2</option><option value="A3">A3</option>'); }

    async function loadJudges(){
      try{
        if(!client) throw new Error("no client");
        const { data, error } = await client.from("judges").select("id,name").order("name", { ascending: true });
        if (error) throw error;
        const rows = data||[];
        if(!rows.length) return fallbackJudges();
        ensureOptions(els.j, '<option value="">Select Judge…</option>' + rows.map(r=>{
          const val = r.name || String(r.id||"").trim();
          const lbl = r.name || ('Judge ' + r.id);
          return `<option value="${val}">${lbl}</option>`;
        }).join(''));
      }catch(e){ console.warn("judges fallback", e); fallbackJudges(); }
    }

    async function loadChips(){
      try{
        if(!client) throw new Error("no client");
        const { data, error } = await client.from("teams").select("chip_number, team_name").order("team_name", { ascending: true });
        if (error) throw error;
        const rows = (data||[]).filter(r => (r.chip_number||"").toString().trim() !== "");
        if (!rows.length) return fallbackChips();
        ensureOptions(els.c, '<option value="">Select Chip…</option>' + rows.map(r=>{
          const ch = String(r.chip_number).toUpperCase();
          const tn = (r.team_name||"").replace(/</g,"&lt;");
          return `<option value="${ch}">${ch} — ${tn}</option>`;
        }).join(''));
      }catch(e){ console.warn("chips fallback", e); fallbackChips(); }
    }

    // Collect per-category scores from the scoring area
    function readCategories(){
      const scope = document.querySelector(".scoring-wrap") || document;
      // Grab inputs/selects that look like category scores (robust heuristics)
      const nodes = Array.from(scope.querySelectorAll("input, select"));
      const candidates = nodes.filter(el=>{
        const t = (el.type||"").toLowerCase();
        if (["checkbox","radio","button","submit","hidden","file"].includes(t)) return false;
        const s = (el.getAttribute("data-cat") || el.name || el.id || "").toLowerCase();
        // likely category keys, avoid obvious non-cats like chip/site/judge/total
        return /appearance|taste|flavor|flavour|tender|tenderness|juic|moist|texture|overall|aroma|cat/.test(s)
               && !/chip|site|judge|total|scorefallback/.test(s);
      });
      const cats = [];
      candidates.forEach((el, idx)=>{
        const keyRaw = (el.getAttribute("data-cat") || el.name || el.id || ("cat_"+idx)).trim();
        const key = keyRaw.toLowerCase().replace(/\s+/g,"_").replace(/[^a-z0-9_]/g,"").slice(0,40) || ("cat_"+idx);
        const label = (el.closest("label")?.textContent || keyRaw || key).replace(/\s+/g," ").trim();
        const val = parseFloat(el.value);
        if (!isNaN(val)) cats.push({ key, label, value: val });
      });
      return cats;
    }

    function readTotalOrSum(cats){
      // Prefer visible total element
      const getNum = (el)=> el ? parseFloat(String(el.value||el.textContent||"").replace(/[^0-9.\-]/g,"")) : NaN;
      let v = getNum(els.total);
      if (isNaN(v)) v = cats.reduce((a,b)=> a + (parseFloat(b.value)||0), 0);
      if (isNaN(v)) {
        if (els.fb) { els.fb.style.display="inline-block"; v = parseFloat(els.fb.value); }
      }
      return v;
    }

    async function handleSave(e){
      if (e) e.preventDefault();
      const judge = (els.j && els.j.value || "").trim();
      const chip  = (els.c && els.c.value || "").trim().toUpperCase();
      if (!judge) { alert("Pick a Judge."); return; }
      if (!chip)  { alert("Pick a Chip #."); return; }

      const cats = readCategories();
      const total = readTotalOrSum(cats);
      if (isNaN(total)) { alert("Total score not found. Enter it in the tiny fallback box or ensure the page shows a total."); return; }
      if (!client) { alert("Supabase client not available."); return; }

      // 1) Insert total
      const { error: e1 } = await client.from("blind_scores").insert({ chip_number: chip, judge: judge, score: total });
      if (e1) { console.warn(e1); alert("Save failed (total): " + (e1.message||"")); return; }

      // 2) Insert per-category breakdown (one row per category)
      if (cats.length) {
        const rows = cats.map(c => ({
          chip_number: chip,
          judge: judge,
          category_key: c.key,
          category_label: c.label,
          score: Number(c.value)||0
        }));
        const { error: e2 } = await client.from("blind_scores_breakdown").insert(rows);
        if (e2) { console.warn(e2); alert("Saved total, but categories failed: " + (e2.message||"")); return; }
      }
      alert("Saved blind score (total + categories).");
    }

    // Bind to existing Save button on the scoring card
    function findSaveButton(){
      const byId = document.getElementById("saveBtn") || document.getElementById("btSaveBtn");
      if (byId) return byId;
      const btns = Array.from(document.querySelectorAll("button"));
      return btns.find(b => /save/i.test(b.textContent||"")) || null;
    }

    await loadJudges();
    await loadChips();
    const saveBtn = findSaveButton();
    if (saveBtn) {
      saveBtn.replaceWith(saveBtn.cloneNode(true));
      const newBtn = findSaveButton();
      newBtn.addEventListener("click", handleSave);
    } else {
      console.warn("No Save button found to bind.");
    }
  });
})();
</script>
<!-- BT_SYNC_END -->
'@

# Place the script right before </body>
if ($html -match '(?is)</body\s*>') {
  $html = [regex]::Replace($html,'(?is)</body\s*>', ($script + "`r`n</body>"), 1)
} else {
  $html += "`r`n" + $script
}

# Write back
Set-Content -LiteralPath $blind -Encoding UTF8 -Value $html
Write-Host "✅ Blind Taste page wired: single inline Judge/Chip; total + per-category saved to Supabase. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $blind

# Write helper SQL to create breakdown table + reporting view
$sqlPath = Join-Path $root "db_blind_breakdown.sql"
$sql = @'
-- Table to store per-category blind scores
create table if not exists blind_scores_breakdown (
  id bigserial primary key,
  chip_number text not null,
  judge text not null,
  category_key text not null,
  category_label text,
  score numeric not null,
  created_at timestamp with time zone default now()
);

-- Optional: make chip -> team link enforceable if teams.chip_number is unique
-- alter table blind_scores_breakdown
--   add constraint blind_cat_chip_fk
--   foreign key (chip_number) references teams(chip_number) on delete cascade;

-- View: per-team, per-category totals for reporting
create or replace view blind_team_category_totals as
select
  coalesce(t.team_name, '(Unknown Team)') as team_name,
  b.category_key,
  max(b.category_label) as category_label,
  sum(b.score) as total_score,
  count(*) as entries
from blind_scores_breakdown b
left join teams t
  on upper(t.chip_number::text) = upper(b.chip_number::text)
group by coalesce(t.team_name, '(Unknown Team)'), b.category_key
order by team_name, category_key;

-- View: per-team total across all blind categories (for rank)
create or replace view blind_team_totals as
select
  coalesce(t.team_name, '(Unknown Team)') as team_name,
  sum(b.score) as total_score,
  count(*) as entries
from blind_scores_breakdown b
left join teams t
  on upper(t.chip_number::text) = upper(b.chip_number::text)
group by coalesce(t.team_name, '(Unknown Team)')
order by total_score desc nulls last;
'@
Set-Content -LiteralPath $sqlPath -Encoding UTF8 -Value $sql
Write-Host "📄 Wrote SQL helper: $sqlPath (paste into Supabase SQL editor)." -ForegroundColor Cyan
