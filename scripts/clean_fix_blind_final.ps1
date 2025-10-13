# clean_fix_blind_final.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root  = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
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

function RX([string]$p){ return [regex]::new($p,[System.Text.RegularExpressions.RegexOptions] 'IgnoreCase, Singleline') }

# 1) Ensure Supabase CDN + config tags exist (CDN before config)
$cdnTag = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
$cfgTag = '<script src="supabase-config.js"></script>'

if ($html -notmatch '@supabase/supabase-js') {
  $html = [regex]::Replace($html,'(?is)</body\s*>', $cdnTag + "`r`n</body>", 1)
}
if ($html -notmatch '(?i)\bsupabase-config\.js') {
  $html = [regex]::Replace($html,'(?is)</body\s*>', $cfgTag + "`r`n</body>", 1)
}

# 2) Remove any previously injected blocks/cards (markers or old top card)
$rxMarkers = RX('<!--\s*BT_(?:INJECT|SYNC)_START\s*-->[\s\S]*?<!--\s*BT_(?:INJECT|SYNC)_END\s*-->')
$html = $rxMarkers.Replace($html, '')
# Remove any card with id="bt-select-card"
$rxOldIdCard = RX('<div\b[^>]*\bid\s*=\s*"bt-select-card"[^>]*>[\s\S]*?</div>')
$html = $rxOldIdCard.Replace($html, '')
# Remove a top card that contains Judge/Chip selects (first occurrence only)
$rxGenericTopCard = RX('<div\b[^>]*class\s*=\s*"[^"]*\bcard\b[^"]*"[^>]*>[\s\S]{0,4000}?(?:<label[^>]*>\s*Judge|<select[^>]*id\s*=\s*"btJudgeSel"|Chip\s*#|<select[^>]*id\s*=\s*"btChipSel")[\s\S]*?</div>')
if ($rxGenericTopCard.IsMatch($html)) { $html = $rxGenericTopCard.Replace($html, '', 1) }

# 3) Remove any old inline block we might have added
$rxOldInline = RX('<div\b[^>]*\bid\s*=\s*"bt-inline-selects"[^>]*>[\s\S]*?</div>')
$html = $rxOldInline.Replace($html, '')

# 4) Build the single inline Judge + Chip row to insert INSIDE scoring area
$inline = @'
<div id="bt-inline-selects" style="display:flex;gap:12px;align-items:flex-end;flex-wrap:wrap;margin:6px 0 8px;">
  <label style="display:flex;flex-direction:column;">Judge
    <select id="btJudgeSel" class="input" style="min-width:180px;">
      <option value="">Loading judges…</option>
    </select>
  </label>
  <label style="display:flex;flex-direction:column;">Chip #
    <select id="btChipSel" class="input" style="min-width:140px;">
      <option value="">Loading chips…</option>
    </select>
  </label>
  <!-- hidden tiny fallback if no visible total element exists -->
  <input id="btScoreFallback" type="number" step="0.5" min="0" max="10" style="display:none;">
</div>
'@

# Insert right after .scoring-top ; else after .scoring-wrap ; else before first Save ; else append
$inserted = $false
$rxTop = RX('(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-top\b[^"]*"[^>]*>[\s\S]*?</div>)')
if ($rxTop.IsMatch($html)) { $html = $rxTop.Replace($html, '$1' + "`r`n" + $inline, 1); $inserted = $true }
if (-not $inserted) {
  $rxWrapOpen = RX('(<div\b[^>]*class\s*=\s*"[^"]*\bscoring-wrap\b[^"]*"[^>]*>)')
  if ($rxWrapOpen.IsMatch($html)) { $html = $rxWrapOpen.Replace($html, '$1' + "`r`n" + $inline, 1); $inserted = $true }
}
if (-not $inserted) {
  $rxBtn = RX('(<button\b[^>]*>(?:(?!</button>).)*?save(?:(?!</button>).)*?</button>)')
  if ($rxBtn.IsMatch($html)) { $html = $rxBtn.Replace($html, $inline + '$1', 1); $inserted = $true }
}
if (-not $inserted) { $html = [regex]::Replace($html,'(?is)</body\s*>', $inline + "`r`n</body>", 1) }

# 5) Inject robust loader that creates a client if needed (no fake fallbacks)
$script = @'
<!-- BT_SYNC_START -->
<script>
(function(){
  document.addEventListener("DOMContentLoaded", async () => {
    const SUPA_URL = "https://wiolulxxfyetvdpnfusq.supabase.co";
    const SUPA_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc";

    // Ensure a Supabase client (handle UMD + config variations)
    let client = null;
    try{
      // If supabase-config.js already created a client, prefer it
      if (window.supabase && typeof window.supabase.from === "function") {
        client = window.supabase;
      } else if (typeof supabase !== "undefined" && typeof supabase.createClient === "function") {
        // Create a client from UMD global
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

    // Helpers to pick best column names regardless of schema differences
    function pick(row, candidates){
      for (const k of candidates){
        if (Object.prototype.hasOwnProperty.call(row,k) && row[k] != null && String(row[k]).trim() !== "") return row[k];
      }
      return null;
    }

    async function loadJudges(){
      try{
        if(!client) throw new Error("Supabase client not ready");
        const { data, error } = await client.from("judges").select("*");
        if (error) throw error;
        const rows = (data||[]).map(r=>{
          const name = pick(r, ["name","judge_name","display_name","full_name"]) || String(pick(r,["id"])||"").trim();
          return name ? ({ value: name, label: name }) : null;
        }).filter(Boolean).sort((a,b)=> (a.label||"").localeCompare(b.label||""));
        setOptions(els.j, rows, "Judge");
      }catch(e){
        console.warn("Judges load failed:", e);
        showEmpty(els.j, "No Judges (DB unreadable)");
      }
    }

    async function loadChips(){
      try{
        if(!client) throw new Error("Supabase client not ready");
        const { data, error } = await client.from("teams").select("*");
        if (error) throw error;
        const rows = (data||[]).map(r=>{
          const chip = String(pick(r, ["chip_number","chip","chipnum","chip_no","chipnumber","chipid","chip_id"])||"").toUpperCase();
          const team = pick(r, ["team_name","team","name","teamname"]) || "";
          return chip ? ({ value: chip, label: (team ? `${chip} — ${team}` : chip) }) : null;
        }).filter(Boolean).sort((a,b)=> (a.label||"").localeCompare(b.label||""));
        setOptions(els.c, rows, "Chip");
      }catch(e){
        console.warn("Chips load failed:", e);
        showEmpty(els.c, "No Chips (DB unreadable)");
      }
    }

    await Promise.all([loadJudges(), loadChips()]);
  });
})();
</script>
<!-- BT_SYNC_END -->
'@

# Place script just before </body>
$html = [regex]::Replace($html,'(?is)</body\s*>', $script + "`r`n</body>", 1)

# --- Write back ---
Set-Content -LiteralPath $blind -Encoding UTF8 -Value $html
Write-Host "✅ Cleaned Blind Taste: removed top card, added inline selects, wired to live Supabase (no fake fallbacks). Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $blind
