param(
  [Parameter(Mandatory=$true)] [string]$Root,
  [Parameter(Mandatory=$true)] [string]$Landing,
  [Parameter(Mandatory=$true)] [string]$Onsite,
  [Parameter(Mandatory=$true)] [string]$Blind,
  [Parameter(Mandatory=$true)] [string]$Leaderboard
)

function Read-Utf8([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8([string]$p,[string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p,$s,$enc)
}
function Backup([string]$file){
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $bak = "$file.$stamp.bak"
  Copy-Item $file $bak -Force
  Write-Host "🔒 Backup: $bak"
}

# 1) Create sauce.html
$saucePath = Join-Path $Root "sauce.html"
$sauceHtml = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Whole Hog Competition 2025 — Sauce Tasting</title>
  <link rel="stylesheet" href="styles.css"/>

  <style>
    :root { --wh-header-h: 2.25in; --line:#dcdcdc; }
    body { font-family: system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif; margin:0; background:#fafafa; }
    header { height:var(--wh-header-h); min-height:var(--wh-header-h); position:relative; display:flex; align-items:center; justify-content:center; background:white; }
    header h1 { margin:0; line-height:1.1; text-align:center; }
    header img:first-of-type { position:absolute; left:14px; top:50%; transform:translateY(-50%); height:calc(100% - 20px); width:auto; }
    header img:last-of-type  { position:absolute; right:14px; top:50%; transform:translateY(-50%); height:calc(100% - 20px); width:auto; }

    /* Red, bold black Go To buttons — centered, evenly spaced */
    #wholehog-nav {
      max-width: 900px;
      margin: 12px auto;
      display:flex; justify-content:center; align-items:center; gap:12px; flex-wrap:wrap; text-align:center;
    }
    #wholehog-nav a {
      display:inline-flex; align-items:center; justify-content:center; white-space:nowrap;
      padding:10px 14px; border-radius:10px; min-width:180px;
      background:#e53935 !important; color:#000 !important; font-weight:800 !important; border:2px solid #000 !important;
      text-decoration:none;
    }
    #wholehog-nav a:hover { filter:brightness(0.92); }

    .container { max-width:1100px; margin:18px auto; padding:0 14px; }
    .card { border:1px solid var(--line); border-radius:12px; padding:14px; background:#fff; }
    .card h2 { margin:0 0 10px 0; }
    .row { display:flex; gap:14px; flex-wrap:wrap; align-items:flex-end; }
    .field { display:flex; flex-direction:column; gap:6px; }
    label { font-weight:600; }
    .input, select { padding:8px 10px; border:1px solid #bbb; border-radius:8px; background:#fff; }
    .btn { padding:10px 16px; border-radius:10px; border:1px solid #111; background:#f5f5f5; cursor:pointer; }
    .btn-primary { background:#111; color:#fff; }
    .muted { color:#666; font-size:12px; }
    .list { display:flex; flex-direction:column; gap:8px; margin-top:8px; }
  </style>
</head>
<body>
  <header class="header">
    <img src="Legion whole hog logo.png" alt="Logo" onerror="this.style.display='none'"/>
    <h1>Sauce Tasting</h1>
    <img src="AL Medallion.png" alt="Logo" onerror="this.style.display='none'"/>
  </header>

  <nav id="wholehog-nav">
    <a href="./landing.html">Go to Landing</a>
    <a href="./onsite.html">Go to On-Site</a>
    <a href="./blind.html">Go to Blind Taste</a>
    <a href="./leaderboard.html">Go to Leaderboard</a>
  </nav>

  <main class="container">
    <section class="card">
      <h2>Enter Sauce Score</h2>
      <div class="row">
        <div class="field" style="flex:1 1 280px; min-width:240px;">
          <label for="team">Team</label>
          <select id="team" class="input"><option value="">Select team…</option></select>
        </div>
        <div class="field" style="flex:1 1 280px; min-width:240px;">
          <label for="judge">Judge</label>
          <select id="judge" class="input"><option value="">Select judge…</option></select>
        </div>
        <div class="field" style="flex:0 0 160px;">
          <label for="score">Score</label>
          <input id="score" type="number" step="0.1" min="0" class="input" placeholder="e.g., 9.2"/>
        </div>
        <div style="flex:0 0 auto;">
          <button id="submit" class="btn btn-primary" type="button">Enter</button>
        </div>
      </div>
      <div class="muted" id="status" style="margin-top:8px;"></div>
    </section>

    <section class="card" style="margin-top:18px;">
      <h2>Recent Sauce Entries</h2>
      <div id="recent" class="list"><div class="muted">No entries yet.</div></div>
    </section>
  </main>

  <script>
  (function(){
    const K = {
      teams: 'wh_Teams', judges:'wh_Judges',
      selTeam:'selectedTeamName', selJudge:'selectedJudgeName',
      sauce:'sauceScores', chip:'wh_chipByTeam'
    };
    const $ = (s,r)=> (r||document).querySelector(s);
    function getList(k){ try { return JSON.parse(localStorage.getItem(k)||'[]'); } catch { return []; } }
    function setList(k,v){ localStorage.setItem(k, JSON.stringify(v)); }
    function getStr(k){ const v = localStorage.getItem(k); return (typeof v === 'string') ? v : ''; }
    function uniqNames(arr, prop){ if(!Array.isArray(arr)) return []; return Array.from(new Set(arr.map(x=>x&&x[prop]?String(x[prop]):'').filter(Boolean))); }

    function fill(){
      const t = $('#team'), j = $('#judge');
      const teams = uniqNames(getList(K.teams),'name');
      const judges = uniqNames(getList(K.judges),'name');
      const selT = getStr(K.selTeam), selJ = getStr(K.selJudge);

      t.innerHTML = ['<option value="">Select team…</option>'].concat(teams.map(n=>`<option value="${n}">${n}</option>`)).join('');
      j.innerHTML = ['<option value="">Select judge…</option>'].concat(judges.map(n=>`<option value="${n}">${n}</option>`)).join('');
      if (selT && teams.includes(selT)) t.value = selT;
      if (selJ && judges.includes(selJ)) j.value = selJ;
    }

    function recent(){
      const host = $('#recent');
      const arr = getList(K.sauce);
      if(!Array.isArray(arr) || !arr.length){ host.innerHTML = '<div class="muted">No entries yet.</div>'; return; }
      host.innerHTML = arr.slice(0,10).map(r=>{
        const when = new Date(r.ts||Date.now()).toLocaleTimeString();
        return `<div>${r.team} — ${r.judge} — <strong>${r.score}</strong> <span class="muted">(${when})</span></div>`;
      }).join('');
    }

    function submit(){
      const t = $('#team').value || '';
      const j = $('#judge').value || '';
      const s = Number($('#score').value);
      if(!t){ alert('Select a team.'); return; }
      if(!j){ alert('Select a judge.'); return; }
      if(!Number.isFinite(s)){ alert('Enter a numeric score.'); return; }

      const arr = getList(K.sauce);
      arr.unshift({ team:t, judge:j, score:s, ts:new Date().toISOString() });
      setList(K.sauce, arr);
      localStorage.setItem(K.selTeam, t);
      localStorage.setItem(K.selJudge, j);

      $('#status').textContent = 'Saved locally at ' + new Date().toLocaleTimeString();
      setTimeout(()=> $('#status').textContent = '', 2500);
      $('#score').value = '';
      recent();
      alert('Sauce score saved for ' + t);
    }

    document.addEventListener('DOMContentLoaded', ()=>{
      fill(); recent();
      $('#submit').addEventListener('click', submit);
    });
    window.addEventListener('storage', (e)=> {
      if (!e || !e.key) return;
      if (['wh_Teams','wh_Judges','selectedTeamName','selectedJudgeName','sauceScores'].includes(e.key)) {
        fill(); recent();
      }
    });
    document.addEventListener('visibilitychange', ()=> { if (!document.hidden){ fill(); recent(); }});
  })();
  </script>
</body>
</html>
'@

Write-Utf8 $saucePath $sauceHtml
Write-Host "🆕 Created: $saucePath"

# 2) Insert "Go to Sauce Tasting" navigation on each
