# restore_onsite_static.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = 'C:\Users\millh_y3006x1\Desktop\WholeHogWeb'
if (-not (Test-Path $root)) { throw "Folder not found: $root" }

# Your Supabase (public anon) credentials
$supaUrl  = 'https://wiolulxxfyetvdpnfusq.supabase.co'
$supaAnon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc'

$path = Join-Path $root 'onsite.html'
if (Test-Path $path) {
  $bak = "$path.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
  Copy-Item -LiteralPath $path -Destination $bak -Force
}

# IMPORTANT: No JS template-literals (${...}) below to avoid PowerShell $ expansion issues.
$onsite = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Whole Hog — On-Site</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; background:#f6f6f6; margin:0; }
    header { position: sticky; top:0; background:#fff; border-bottom:1px solid #eee; padding:12px 16px; font-weight:700; }
    main { max-width: 960px; margin: 0 auto; padding: 24px; }
    .btn { display:inline-flex; align-items:center; padding:8px 14px; border:1px solid #ddd; border-radius:12px; text-decoration:none; color:#111; background:#fff; }
    .btn:hover { box-shadow: 0 1px 6px rgba(0,0,0,.08); }
    /* centered nav row under header */
    #wholehog-nav { width:100%; margin:12px auto; display:flex; justify-content:center; align-items:center; gap:12px; flex-wrap:wrap; text-align:center; }
    /* card/form */
    form { background:#fff; border:1px solid #eee; border-radius:14px; padding:16px; margin-top:16px; }
    label { display:block; font-size:12px; color:#555; margin:8px 0 4px; }
    input { width:100%; padding:8px 10px; border:1px solid #ddd; border-radius:10px; }
    .row { display:grid; grid-template-columns:1fr 2fr 1fr; gap:12px; }
    .status { margin-top:10px; font-size:13px; }
    table { width:100%; border-collapse:collapse; margin-top:16px; background:#fff; }
    th, td { border-bottom:1px solid #eee; text-align:left; padding:8px 10px; }
  </style>
</head>
<body>
  <header>Whole Hog</header>

  <!-- centered two-button nav, matching landing page style -->
  <div id="wholehog-nav">
    <a class="btn" href="./landing.html">Home</a>
    <a class="btn" href="./leaderboard.html">Go to Leaderboard</a>
  </div>

  <main>
    <h1 style="font-size:22px; margin:0 0 8px;">On-Site Team Entry</h1>

    <form id="teamForm">
      <div class="row">
        <div>
          <label>Site #</label>
          <input id="site" type="number" min="1" placeholder="e.g., 7" required />
        </div>
        <div>
          <label>Team Name</label>
          <input id="team" type="text" placeholder="Team name" required />
        </div>
        <div>
          <label>Chip # (unique)</label>
          <input id="chip" type="text" placeholder="A12" required />
        </div>
      </div>
      <div style="margin-top:12px; display:flex; gap:8px; align-items:center;">
        <button class="btn" type="submit">Save Team</button>
        <span id="status" class="status"></span>
      </div>
    </form>

    <table id="teamsTable" aria-label="Registered teams" style="display:none;">
      <thead><tr><th>Site</th><th>Team</th><th>Chip</th></tr></thead>
      <tbody></tbody>
    </table>
  </main>

  <script type="module">
    import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
    const supabase = createClient("$supaUrl", "$supaAnon");

    const form = document.getElementById('teamForm');
    const statusEl = document.getElementById('status');
    const siteEl = document.getElementById('site');
    const teamEl = document.getElementById('team');
    const chipEl = document.getElementById('chip');
    const table = document.getElementById('teamsTable');
    const tbody = table.querySelector('tbody');

    function setMsg(text, color) {
      statusEl.textContent = text || "";
      statusEl.style.color = color || "#0a0";
    }
    function setErr(text) { setMsg(text, "#c00"); }

    async function loadTeams() {
      const res = await supabase
        .from('teams')
        .select('site_number, team_name, chip_number')
        .order('site_number', { ascending: true });
      if (res.error) { setErr("Load failed: " + res.error.message); return; }
      const data = res.data || [];
      tbody.innerHTML = "";
      for (var i = 0; i < data.length; i++) {
        var r = data[i];
        var tr = document.createElement('tr');
        tr.innerHTML =
          '<td>' + (r.site_number ?? '') + '</td>' +
          '<td>' + (r.team_name ?? '') + '</td>' +
          '<td>' + (r.chip_number ?? '') + '</td>';
        tbody.appendChild(tr);
      }
      table.style.display = data.length ? "table" : "none";
    }

    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      var site = Number(siteEl.value);
      var team = (teamEl.value || '').trim();
      var chip = (chipEl.value || '').trim().toUpperCase();

      if (!Number.isFinite(site)) return setErr("Site # must be a number.");
      if (!team) return setErr("Team name is required.");
      if (!chip) return setErr("Chip # is required.");

      // upsert on unique chip_number
      const ins = await supabase
        .from('teams')
        .upsert([{ site_number: site, team_name: team, chip_number: chip }], { onConflict: 'chip_number' });

      if (ins.error) return setErr(ins.error.message);

      setMsg("Team saved.");
      form.reset();
      await loadTeams();
    });

    // initial load
    loadTeams();
  </script>
</body>
</html>
"@

Set-Content -LiteralPath $path -Encoding UTF8 -Value $onsite
Write-Host "Wrote onsite.html to $root" -ForegroundColor Green
Start-Process $path
