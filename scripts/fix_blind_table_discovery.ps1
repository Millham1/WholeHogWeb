# fix_blind_table_discovery.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root  = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
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

# Ensure Supabase UMD + config tags (CDN before config)
$cdnTag = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
$cfgTag = '<script src="supabase-config.js"></script>'
if ($html -notmatch '@supabase/supabase-js') { $html = [regex]::Replace($html,'(?is)</body\s*>', $cdnTag + "`r`n</body>", 1) }
if ($html -notmatch '(?i)\bsupabase-config\.js') { $html = [regex]::Replace($html,'(?is)</body\s*>', $cfgTag + "`r`n</body>", 1) }

# Remove any previous injected blocks/cards so we don’t duplicate
$html = [regex]::Replace($html, '(?is)<!--\s*BT_(?:INJECT|SYNC)_START\s*-->[\s\S]*?<!--\s*BT_(?:INJECT|SYNC)_END\s*-->', '')
$html = [regex]::Replace($html, '(?is)<div\b[^>]*\bid\s*=\s*"bt-select-card"[^>]*>[\s\S]*?</div>', '')
# Keep the inline row you already have; do not re-inject it

# Inject the new robust loader (table + column auto-detect)
$script = @'
<!-- BT_SYNC_START -->
<script>
(function(){
  document.addEventListener("DOMContentLoaded", async () => {
    const SUPA_URL = "https://wiolulxxfyetvdpnfusq.supabase.co";
    const SUPA_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc";

    // Ensure a Supabase client
    let client = null;
    try{
      if (window.supabase && typeof window.supabase.from === "function") {
        client = window.supabase;
      } else if (typeof supabase !== "undefined" && typeof supabase.createClient === "function") {
        client = supabase.createClient(SUPA_URL, SUPA_KEY);
        window.supabase = client;
      }
    }catch(e){ console.warn("supabase init error", e); }

    const $ = (id) => document.getElementById(id);
    const els = { j: $("btJudgeSel"), c: $("btChipSel") };

    function showEmpty(selectEl, text){
      if (!selectEl) return;
      selectEl.innerHTML = `<option value="">${text}</option>`;
      selectEl.setAttribute("disabled","disabled");
    }
    function setOptions(selectEl, rows, placeholder){
      if (!selectEl) return;
      if (!rows || !rows.length) return showEmpty(selectEl, `No ${placeholder} found`);
      selectEl.removeAttribute("disabled");
      selectEl.innerHTML = `<option value="">Select ${placeholder}…</option>` + rows.map(r=>`<option value="${r.value}">${r.label}</option>`).join("");
    }

    // Try a list of table names until one works (exists + readable)
    async function resolveTable(candidates){
      if (!client) throw new Error("Supabase client not ready");
      for (const name of candidates){
        try{
          const { data, error } = await client.from(name).select("*").limit(1);
          if (!error) return name;               // success: table exists and is readable
          if (error && (String(error.code).includes("42P01"))) continue; // table not found, try next
          // Other errors (401/RLS) mean table exists but no read policy:
          if (error) { console.warn(`Table ${name} exists but is not readable (RLS).`, error); return name; }
        }catch(e){ console.warn("resolveTable error for", name, e); }
      }
      return null;
    }

    // Pick the first present, non-empty column from each candidate list
    function pick(row, candidates){
      for (const k of candidates){
        if (row && Object.prototype.hasOwnProperty.call(row,k) && row[k] != null && String(row[k]).trim() !== "") return row[k];
      }
      return null;
    }

    async function loadJudges(){
      try{
        const judgeTables = ["judges","Judges","judge","Judge","judge_list","JudgeList"];
        const jTable = await resolveTable(judgeTables);
        if (!jTable) { showEmpty(els.j, "No Judges table"); return; }

        const { data, error } = await client.from(jTable).select("*").order("id",{ascending:true}).limit(1000);
        if (error) { console.warn("judges read error:", error); showEmpty(els.j, "No Judges (enable SELECT policy)"); return; }

        const rows = (data||[]).map(r=>{
          const name = pick(r, ["name","judge_name","display_name","full_name","Name","JudgeName"]) || String(pick(r,["id","ID"])||"").trim();
          return name ? ({ value: name, label: name }) : null;
        }).filter(Boolean).sort((a,b)=> (a.label||"").localeCompare(b.label||""));
        setOptions(els.j, rows, "Judge");
      }catch(e){
        console.warn("loadJudges fatal:", e);
        showEmpty(els.j, "No Judges (client/init)");
      }
    }

    async function loadChips(){
      try{
        const teamTables = ["teams","Teams","team","Team","team_list","TeamList"];
        const tTable = await resolveTable(teamTables);
        if (!tTable) { showEmpty(els.c, "No Chips table"); return; }

        const { data, error } = await client.from(tTable).select("*").limit(2000);
        if (error) { console.warn("teams read error:", error); showEmpty(els.c, "No Chips (enable SELECT policy)"); return; }

        const rows = (data||[]).map(r=>{
          // Try many likely chip fields
          const chip = String(pick(r, [
            "chip_number","chip","Chip","chipnum","chip_num","chipno","chip_no","chipnumber","chipid","chip_id","Chip#","ChipNo"
          ]) || "").toUpperCase();
          const team = pick(r, ["team_name","team","Team","name","Name","teamname","TeamName"]) || "";
          return chip ? ({ value: chip, label: (team ? `${chip} — ${team}` : chip) }) : null;
        }).filter(Boolean).sort((a,b)=> (a.label||"").localeCompare(b.label||""));
        setOptions(els.c, rows, "Chip");
      }catch(e){
        console.warn("loadChips fatal:", e);
        showEmpty(els.c, "No Chips (client/init)");
      }
    }

    await Promise.all([loadJudges(), loadChips()]);
  });
})();
</script>
<!-- BT_SYNC_END -->
'@

# Put the script right before </body>
if ($html -match '(?is)</body\s*>') {
  $html = [regex]::Replace($html,'(?is)</body\s*>', ($script + "`r`n</body>"), 1)
} else {
  $html += "`r`n" + $script
}

# Write back
Set-Content -LiteralPath $blind -Encoding UTF8 -Value $html
Write-Host "✅ Updated Blind Taste: auto-detects table names & columns for Judges/Chips. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $blind
