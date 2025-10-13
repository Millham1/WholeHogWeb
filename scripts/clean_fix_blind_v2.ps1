# clean_fix_blind_v2.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$blind = Join-Path $root "blind-taste.html"
if (!(Test-Path $blind)) {
  $alt = Join-Path $root "blindtaste.html"
  if (Test-Path $alt) { $blind = $alt } else { throw "Blind Taste page not found (blind-taste.html or blindtaste.html)" }
}

# --- Backup ---
$bak = "$blind.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $blind -Destination $bak -Force

# --- Read ---
$html = Get-Content -LiteralPath $blind -Raw -Encoding UTF8

# --- Ensure Supabase UMD + config tags exist near bottom (order: CDN then config) ---
$cdnTag = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
$cfgTag = '<script src="supabase-config.js"></script>'
if ($html -notmatch '@supabase/supabase-js') { $html = [regex]::Replace($html,'(?is)</body\s*>', $cdnTag + "`r`n</body>",1) }
if ($html -notmatch '(?i)\bsupabase-config\.js') { $html = [regex]::Replace($html,'(?is)</body\s*>', $cfgTag + "`r`n</body>",1) }

# --- Remove ANY previous injected blocks/cards (old top card & duplicates) ---
$html = [regex]::Replace($html, '(?is)<!--\s*BT_INJECT_START\s*-->[\s\S]*?<!--\s*BT_INJECT_END\s*-->', '')
$html = [regex]::Replace($html, '(?is)<!--\s*BT_SYNC_START\s*-->[\s\S]*?<!--\s*BT_SYNC_END\s*-->', '')
# Generic remove of the old top card:
$html = [regex]::Replace($html, '(?is)<div\b[^>]*\bid\s*=\s*"bt-select-card"[^>]*>[\s\S]*?</div>', '')
$html = [regex]::Replace($html, '(?is)<div\b[^>]*class\s*=\s*"[^"]*\bcard\b[^"]*"[^>]*>\s*<h2[^>]*>\s*Blind\s*Taste\s*Entry\s*</h2>[\s\S]*?</div>', '')
# Remove any leftover old inline row
$html = [regex]::Replace($html, '(?is)<div\b[^>]*\bid\s*=\s*"bt-inline-selects"[^>]*>[\s\S]*?</div>', '')

# --- Build the inline Judge + Chip row (inside scoring area) ---
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

# Insert right after .scoring-top ; fallback: after .scoring-wrap ; else before first "Save" button ; else append near bottom
$inserted = $false
if ([regex]::IsMatch($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-top\b[^"]*"[^>]*>[\s\S]*?</div>)')) {
  $html = [regex]::Replace($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-top\b[^"]*"[^>]*>[\s\S]*?</div>)','$1' + "`r`n" + $inline,1); $inserted = $true
} elseif ([regex]::IsMatch($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-wrap\b[^"]*"[^>]*>)')) {
  $html = [regex]::Replace($html,'(?is)(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-wrap\b[^"]*"[^>]*>)','$1' + "`r`n" + $inline,1); $inserted = $true
} elseif ([regex]::IsMatch($html,'(?is)(<button\b[^>]*>(?:(?!</button>).)*?save(?:(?!</button>).)*?</button>)')) {
  $html = [regex]::Replace($html,'(?is)(<button\b[^>]*>(?:(?!</button>).)*?save(?:(?!</button>).)*?</button>)',$inline + '$1',1); $inserted = $true
} else {
  $html = [regex]::Replace($html,'(?is)</body\s*>',$inline + "`r`n</body>",1)
}

# --- Inject robust loader + save binding (handles varied DB column names) ---
$script = @'
<!-- BT_SYNC_START -->
<script>
(function(){
  document.addEventListener("DOMContentLoaded", async () => {
    const SUPA_URL = "https://wiolulxxfyetvdpnfusq.supabase.co";
    const SUPA_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc";

    // 1) Ensure a Supabase client regardless of how supabase-config.js is written
    let client = null;
    try{
      if (window.supabase && typeof window.supabase.from === "function") {
        client = window.supabase;
      } else if (window.supabase && typeof window.supabase.createClient === "function") {
        client = window.supabase.createClient(SUPA_URL, SUPA_KEY);
        window.supabase = client;
      } else if (typeof supabase !== "undefined" && typeof supabase.createClient === "function") {
        client = supabase.createClient(SUPA_URL, SUPA_KEY);
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

    // Helper to pick field by candidate names on row
    function pick(row, candidates){
      for (const k of candidates){
        if (row && Object.prototype.hasOwnProperty.call(row,k) && row[k] != null && String(row[k]).trim() !== "") return row[k];
      }
      return null;
    }

    function fallbackJudges(){
      ensureOptions(els.j, '<option value="">Select Judge…</option>' +
        Array.from({length:6},(_,i)=>`<option value="Judge ${i+1}">Judge ${i+1}</option>`).join(''));
    }
    function fallbackChips(){
      ensureOptions(els.c, '<option value="">Select Chip…</option><option value="A1">A1</option><option value="A2">A2</option><option value="A3">A3</option>');
    }

    async function loadJudges(){
      try{
        if(!client) throw new Error("no client");
        // Use '*' to avoid "column not found" errors on varied schemas
        const { data, error } = await client.from("judges").select("*");
        if (error) throw error;
        const rows = (data||[]).map(r=>{
          const name = pick(r, ["name","judge_name","display_name","full_name"]) || String(pick(r,["id"]) || "").trim();
          return { value: name, label: name || ("Judge " + (r.id||"")) };
        }).filter(r => (r.value||"") !== "");
        rows.sort((a,b)=> (a.label||"").localeCompare(b.label||""));
        if (!rows.length) return fallbackJudges();
        ensureOptions(els.j, '<option value="">Select Judge…</option>' + rows.map(r=>`<option value="${r.value}">${r.label}</option>`).join(''));
      }catch(e){ console.warn("judges load fallback", e); fallbackJudges(); }
    }

    async function loadChips(){
      try{
        if(!client) throw new Error("no client");
        const { data, error } = await client.from("teams").select("*");
        if (error) throw error;
        const rows = (data||[]).map(r=>{
          const chip = String(pick(r, ["chip_number","chip","chipnum","chip_no","chipnumber","chipid","chip_id"]) || "").toUpperCase();
          const team = pick(r, ["team_name","team","name","teamname"]) || "";
          return { chip, team };
        }).filter(r => r.chip);
        rows.sort((a,b)=> (a.team||"").localeCompare(b.team||""));
        if (!rows.length) return fallbackChips();
        ensureOptions(els.c, '<option value="">Select Chip…</option>' +
          rows.map(r => `<option value="${r.chip}">${r.chip} — ${r.team.replace(/</g,"&lt;")}</option>`).join(''));
      }catch(e){ console.warn("chips load fallback", e); fallbackChips(); }
    }

    function readCategories(){
      const scope = document.querySelector(".scoring-wrap") || document;
      const nodes = Array.from(scope.querySelectorAll("input, select"));
      const candidates = nodes.filter(el=>{
        const t = (el.type||"").toLowerCase();
        if (["checkbox","radio","button","submit","hidden","file"].includes(t)) return false;
        const s = (el.getAttribute("data-cat") || el.name || el.id || "").toLowerCase();
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
      const getNum = (el)=> el ? parseFloat(String(el.value||el.textContent||"").replace(/[^0-9.\-]/g,"")) : NaN;
      const totalEl = document.getElementById("totalVal") || document.getElementById("btTotalVal");
      let v = getNum(totalEl);
      if (isNaN(v)) v = cats.reduce((a,b)=> a + (parseFloat(b.value)||0), 0);
      if (isNaN(v)) {
        const fb = document.getElementById("btScoreFallback");
        if (fb) { fb.style.display="inline-block"; v = parseFloat(fb.value); }
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
      if (isNaN(total)) { alert("Total score not found. Enter in fallback or ensure page shows a total."); return; }
      if (!client) { alert("Supabase client not available."); return; }

      // Insert total
      const { error: e1 } = await client.from("blind_scores").insert({ chip_number: chip, judge: judge, score: total });
      if (e1) { console.warn(e1); alert("Save failed (total): " + (e1.message||"")); return; }

      // Insert per-category breakdown
      if (cats.length) {
        const rows = cats.map(c => ({ chip_number: chip, judge: judge, category_key: c.key, category_label: c.label, score: Number(c.value)||0 }));
        const { error: e2 } = await client.from("blind_scores_breakdown").insert(rows);
        if (e2) { console.warn(e2); alert("Saved total, but categories failed: " + (e2.message||"")); return; }
      }
      alert("Saved blind score (total + categories).");
    }

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

# --- Write back ---
Set-Content -LiteralPath $blind -Encoding UTF8 -Value $html
Write-Host "✅ Cleaned Blind Taste page: removed top card, inserted single inline selects, hooked to Save, and made DB field mapping robust. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $blind
