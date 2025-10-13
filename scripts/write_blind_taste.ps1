# write_blind_taste.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = 'C:\Users\millh_y3006x1\Desktop\WholeHogWeb'
if (-not (Test-Path $root)) { throw "Folder not found: $root" }

# Supabase (public anon) — same as earlier
$supaUrl  = 'https://wiolulxxfyetvdpnfusq.supabase.co'
$supaAnon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc'

$dest = Join-Path $root 'blind-taste.html'
if (Test-Path $dest) {
  Copy-Item -LiteralPath $dest -Destination "$dest.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak" -Force
}

# Note: no JS template literals to avoid PowerShell ${} collisions.
$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Whole Hog — Blind Taste</title>
  <link rel="stylesheet" href="styles.css"/>

  <!-- WH HARD HEADER START (match On-Site) -->
  <style id="wh-hard-header">
    :root { --wh-header-h: 2.25in; }
    header, .header, .app-header, .site-header, #header {
      min-height: var(--wh-header-h) !important;
      height: var(--wh-header-h) !important;
      position: relative !important;
      display: flex !important;
      align-items: center !important;
      justify-content: center !important;
    }
    header h1, .header h1, .app-header h1, .site-header h1, #header h1 {
      margin: 0 !important;
      line-height: 1.1 !important;
    }
    header img#logoLeft,
    header .left-img,
    header .brand-left img,
    #header img#logoLeft,
    #header .left-img,
    #header .brand-left img,
    header img:first-of-type {
      position: absolute !important;
      left: 14px !important;
      top: 50% !important;
      transform: translateY(-50%) !important;
      height: calc(100% - 20px) !important;
      width: auto !important;
    }
    header img.right-img,
    header .brand-right img,
    #header img.right-img,
    #header .brand-right img,
    header img:last-of-type {
      position: absolute !important;
      right: 14px !important;
      top: 50% !important;
      transform: translateY(-50%) !important;
      height: calc(100% - 20px) !important;
      width: auto !important;
    }
    /* mini-nav (matches On-Site) */
    #wholehog-nav{
      width:100%; margin:12px auto;
      display:flex; justify-content:center; align-items:center;
      gap:12px; flex-wrap:wrap; text-align:center;
    }
    #wholehog-nav a{ display:inline-block; white-space:nowrap; width:auto; float:none!important; }
    /* page chrome similar to On-Site */
    body { font-family: system-ui,-apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f6f6f6; margin:0; }
    main { max-width: 960px; margin: 0 auto; padding: 24px; }
    .btn { display:inline-flex; align-items:center; padding:8px 14px; border:1px solid #ddd; border-radius:12px; text-decoration:none; color:#111; background:#fff; }
    .btn:hover { box-shadow: 0 1px 6px rgba(0,0,0,.08); }
    .container{ max-width:960px; margin:0 auto; padding:24px; }
    .card{ background:#fff; border:1px solid #eee; border-radius:14px; padding:16px; margin-top:16px; }
    .flex{ display:flex; gap:12px; flex-wrap:wrap; }
    label{ display:flex; flex-direction:column; font-size:12px; color:#555; }
    .input, input, select{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; min-width:180px; }
    .muted{ color:#666; font-size:12px; }
    .badge{ font-size:12px; background:#f0f0f0; padding:6px 8px; border-radius:10px; }
    .pick-row{ display:flex; flex-wrap:wrap; gap:6px; margin-top:6px; }
    .pick-row button{ padding:6px 10px; border:1px solid #ddd; background:#fff; border-radius:10px; cursor:pointer; }
    .pick-row button.sel{ border-color:#111; font-weight:600; }
    .totalbar{ display:flex; justify-content:flex-end; align-items:center; gap:8px; margin-top:10px; font-size:18px; }
    .total{ font-weight:800; }
  </style>
  <!-- WH HARD HEADER END -->
</head>
<body>
  <header class="header" style="height:2.25in; min-height:2.25in; position:relative; display:flex; align-items:center; justify-content:center;">
    <img id="logoLeft" src="Legion whole hog logo.png" alt="Logo"/>
    <h1 style="margin:0; text-align:center;">Whole Hog — Blind Taste</h1>
    <img class="right-img" src="AL Medallion.png" alt="Logo"/>
  </header>

  <!-- two-button nav under header -->
  <div id="wholehog-nav">
    <a class="btn" href="./landing.html">Home</a>
    <a class="btn" href="./leaderboard.html">Go to Leaderboard</a>
  </div>

  <main class="container">
    <div class="card">
      <h2>Judge & Code</h2>
      <div class="flex">
        <label>Judge No.
          <input id="judgeNo" type="text" class="input" placeholder="e.g., 12" />
        </label>
        <label>Chip / Code No.
          <input id="chipNo" type="text" class="input" placeholder="e.g., A12" />
        </label>
      </div>
      <div id="teamHint" class="muted" style="margin-top:6px;"></div>
    </div>

    <div class="card">
      <div class="flex" style="justify-content:space-between; align-items:center;">
        <span class="badge">Pick scores below; buttons are horizontal. Total updates automatically.</span>
      </div>

      <div style="margin-top:10px;">
        <h3 style="margin:8px 0 4px;">Appearance (2–40)</h3>
        <div id="pickAppearance" class="pick-row"></div>

        <h3 style="margin:14px 0 4px;">Tenderness (2–40)</h3>
        <div id="pickTenderness" class="pick-row"></div>

        <h3 style="margin:14px 0 4px;">Taste (4–80)</h3>
        <div id="pickTaste" class="pick-row"></div>

        <div class="totalbar">
          <span>Total:</span>
          <span id="totalVal" class="total">0</span>
        </div>

        <div style="display:flex; justify-content:center; margin-top:10px;">
          <button id="saveBtn" class="btn">Save Blind Taste</button>
        </div>
        <div id="status" class="muted" style="margin-top:8px;"></div>
      </div>
    </div>
  </main>

  <script type="module">
    import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
    const supabase = createClient("$supaUrl", "$supaAnon");

    const judgeEl = document.getElementById("judgeNo");
    const chipEl  = document.getElementById("chipNo");
    const teamHint = document.getElementById("teamHint");
    const statusEl = document.getElementById("status");
    const totalEl  = document.getElementById("totalVal");

    const appRow = document.getElementById("pickAppearance");
    const tenRow = document.getElementById("pickTenderness");
    const tasRow = document.getElementById("pickTaste");

    let app = 0, ten = 0, tas = 0;

    function setStatus(t, good){
      statusEl.textContent = t || "";
      statusEl.style.color = good ? "#0a0" : "#c00";
    }
    function fmt(n){ return Number(n||0).toFixed(0); }
    function updateTotal(){ totalEl.textContent = fmt(app + ten + tas); }

    function buildPicker(rowEl, values, onPick){
      rowEl.innerHTML = "";
      for (var i=0;i<values.length;i++){
        (function(v){
          var b = document.createElement("button");
          b.type = "button";
          b.textContent = v;
          b.addEventListener("click", function(){
            // toggle selected class on this row
            var kids = rowEl.querySelectorAll("button"); 
            for (var j=0;j<kids.length;j++){ kids[j].classList.remove("sel"); }
            b.classList.add("sel");
            onPick(v);
            updateTotal();
          });
          rowEl.appendChild(b);
        })(values[i]);
      }
    }

    // Scales per the official sheet: Appearance 2–40, Tenderness 2–40 (steps of 2), Taste 4–80 (step 4)
    function range(step, max, start){ 
      var out=[], s=(start||step); 
      for (var v=s; v<=max; v+=step) out.push(v); 
      return out;
    }
    buildPicker(appRow, range(2, 40, 2), function(v){ app = v; });
    buildPicker(tenRow, range(2, 40, 2), function(v){ ten = v; });
    buildPicker(tasRow, range(4, 80, 4), function(v){ tas = v; });

    // Lookup team by Chip # as user types
    async function lookupTeam() {
      const chip = (chipEl.value||"").trim().toUpperCase();
      if (!chip) { teamHint.textContent = ""; return; }
      const { data, error } = await supabase.from("teams")
        .select("team_name, site_number")
        .eq("chip_number", chip)
        .maybeSingle();
      if (error){ teamHint.textContent = "Lookup failed: " + error.message; return; }
      teamHint.textContent = data ? ("Team: " + (data.team_name||"") + " (Site " + (data.site_number||"") + ")") : "No team found for that chip.";
    }
    chipEl.addEventListener("input", lookupTeam);

    document.getElementById("saveBtn").addEventListener("click", async function(){
      setStatus("", true);
      const judge = (judgeEl.value||"").trim();
      const chip  = (chipEl.value||"").trim().toUpperCase();

      if (!chip){ setStatus("Enter Chip/Code #.", false); return; }
      if (!judge){ setStatus("Enter Judge No.", false); return; }
      if (!app || !ten || !tas){ setStatus("Pick a value for Appearance, Tenderness, and Taste.", false); return; }

      // ensure chip exists in teams
      const { data: team, error: tErr } = await supabase.from("teams")
        .select("chip_number")
        .eq("chip_number", chip)
        .maybeSingle();
      if (tErr){ setStatus("Team check failed: " + tErr.message, false); return; }
      if (!team){ setStatus("Chip # not found in Teams. Add it on the On-Site page.", false); return; }

      // insert three category rows so leaderboard per category works
      const rows = [
        { chip_number: chip, score: app, category: "Appearance", judge_number: judge },
        { chip_number: chip, score: ten, category: "Tenderness", judge_number: judge },
        { chip_number: chip, score: tas, category: "Taste",      judge_number: judge }
      ];
      const { error: insErr } = await supabase.from("scores").insert(rows);
      if (insErr){ setStatus(insErr.message, false); return; }

      setStatus("Blind Taste saved.", true);
      // reset selections visually
      [appRow,tenRow,tasRow].forEach(function(row){
        var kids = row.querySelectorAll("button"); 
        for (var j=0;j<kids.length;j++){ kids[j].classList.remove("sel"); }
      });
      app = ten = tas = 0;
      updateTotal();
      judgeEl.value = "";
      // keep chip so judges can continue entering for the same code if needed
    });

    // initial
    updateTotal();
  </script>
</body>
</html>
"@

Set-Content -LiteralPath $dest -Encoding UTF8 -Value $html
Write-Host "✅ Wrote blind-taste.html (backup created if file existed). Open it from $root" -ForegroundColor Green
Start-Process $dest
