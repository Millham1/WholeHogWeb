param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

# Read + backup
$orig = Get-Content -LiteralPath $Path -Raw
$bak  = "$Path.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $Path -Destination $bak -Force
Write-Host "Backup created: $bak" -ForegroundColor Yellow

$updated = $orig
$changed = $false

# Inject the button + logic once, right before </body>
if ($updated -notmatch 'id=["'']wh-build-report-btn["'']') {
  $snippet = @'
<!-- Build Report (CSV) -->
<div id="wh-build-report-container" style="width:100%;display:flex;justify-content:center;margin:20px 0 32px;">
  <button id="wh-build-report-btn" class="go-btn" type="button"
          style="min-width:220px;padding:10px 14px;border-radius:10px;cursor:pointer;">
    Build Report (CSV)
  </button>
</div>
<script id="wh-build-report-logic">
(function(){
  "use strict";

  function getArr(k){ try{ const v=localStorage.getItem(k); return v?JSON.parse(v):[]; }catch{ return []; } }
  function getMap(k){ try{ const v=localStorage.getItem(k); return v?JSON.parse(v):{}; }catch{ return {}; } }
  function norm(s){ return (s==null? "": String(s)).trim(); }
  function toInt(v){ const n=Number(v); return Number.isFinite(n)? Math.trunc(n): 0; }

  // CSV escaper
  function csvField(x){
    const s = (x==null? "": String(x));
    if (/[",\n]/.test(s)) return '"' + s.replace(/"/g,'""') + '"';
    return s;
  }

  // Sum all five on-site categories per judge
  const CAT_ALIAS = {
    meatSauce:  ['meatSauce','meat_sauce','meat and sauce','meat&sauce','taste','flavor'],
    skin:       ['skin','crackling'],
    moisture:   ['moisture','juiciness'],
    appearance: ['appearance','visual','presentation'],
    tenderness: ['tenderness','texture']
  };
  const CAT_KEYS = Object.keys(CAT_ALIAS);

  function pickInt(scores, names){
    if (!scores || typeof scores!=='object') return 0;
    for (let i=0;i<names.length;i++){
      const want = names[i], target = want.toLowerCase().replace(/[ _&]/g,'');
      if (scores[want] != null) return toInt(scores[want]);
      for (const k in scores){
        if (!Object.prototype.hasOwnProperty.call(scores,k)) continue;
        const kk = k.toLowerCase().replace(/[ _&]/g,'');
        if (kk === target) return toInt(scores[k]);
      }
    }
    return 0;
  }

  function onsiteJudgeTotal(scores){
    let sum = 0;
    sum += pickInt(scores, CAT_ALIAS.meatSauce);
    sum += pickInt(scores, CAT_ALIAS.skin);
    sum += pickInt(scores, CAT_ALIAS.moisture);
    sum += pickInt(scores, CAT_ALIAS.appearance);
    sum += pickInt(scores, CAT_ALIAS.tenderness);
    return sum;
  }

  function buildReport(){
    // Load data snapshots
    const onsite = getArr('onsiteScores');   // [{team, judge, scores:{...}}]
    const blind  = getArr('blindScores');    // [{team, judge, score}]
    const sauce  = getArr('sauceScores');    // [{team, judge, score}]
    const judgesArr = getArr('judges');      // [{name}]
    const teamsArr  = getArr('teams');       // [{team}]
    const divMap    = getMap('landingTeamDivisions'); // {"Team":"Legion"/"Sons"}
    const emailMap  = getMap('teamEmails');  // {"Team":"email@host"}

    // Judge list (fallback to seen in data if judges array missing)
    let judges = judgesArr.map(j => norm(j.name)).filter(Boolean);
    if (!judges.length){
      const seen = new Set();
      onsite.forEach(r => { if (r && r.judge) seen.add(norm(r.judge)); });
      blind.forEach(r => { if (r && r.judge) seen.add(norm(r.judge)); });
      sauce.forEach(r => { if (r && r.judge) seen.add(norm(r.judge)); });
      judges = Array.from(seen);
    }
    judges.sort((a,b)=>a.localeCompare(b));

    // Team list (sorted by name)
    let teams = teamsArr.map(t => norm(t.team)).filter(Boolean);
    if (!teams.length){
      const seen = new Set();
      onsite.forEach(r => { if (r && r.team) seen.add(norm(r.team)); });
      blind.forEach(r => { if (r && r.team) seen.add(norm(r.team)); });
      sauce.forEach(r => { if (r && r.team) seen.add(norm(r.team)); });
      teams = Array.from(seen);
    }
    teams.sort((a,b)=>a.localeCompare(b));

    // Build lookup tables: per-team per-judge
    const onsiteByTeamJudge = {}; // team -> judge -> int
    const blindByTeamJudge  = {};
    const sauceByTeamJudge  = {};

    function ensure(obj, a, b){
      if (!obj[a]) obj[a] = {};
      if (b != null && !obj[a][b]) obj[a][b] = 0;
    }

    onsite.forEach(r=>{
      const t = norm(r.team || r.teamName || r.name);
      const j = norm(r.judge);
      if (!t || !j) return;
      const perJudge = onsiteJudgeTotal(r.scores || {});
      ensure(onsiteByTeamJudge, t);
      onsiteByTeamJudge[t][j] = (onsiteByTeamJudge[t][j] || 0) + toInt(perJudge);
    });

    blind.forEach(r=>{
      const t = norm(r.team), j = norm(r.judge);
      if (!t || !j) return;
      ensure(blindByTeamJudge, t);
      blindByTeamJudge[t][j] = (blindByTeamJudge[t][j] || 0) + toInt(r.score);
    });

    sauce.forEach(r=>{
      const t = norm(r.team), j = norm(r.judge);
      if (!t || !j) return;
      ensure(sauceByTeamJudge, t);
      sauceByTeamJudge[t][j] = (sauceByTeamJudge[t][j] || 0) + toInt(r.score);
    });

    // Header: Team, Division, Email, then per judge: On-site – Judge, Blind – Judge, Sauce – Judge, then Total
    const header = ['Team','Division','Email'];
    judges.forEach(j=>{
      header.push(`On-site – ${j}`);
      header.push(`Blind – ${j}`);
      header.push(`Sauce – ${j}`);
    });
    header.push('Total');

    const rows = [header];

    // Build rows per team
    teams.forEach(team=>{
      const div = divMap[team] || '';
      const email = emailMap[team] || '';
      const row = [team, div, email];

      let total = 0;

      judges.forEach(j=>{
        const o = (onsiteByTeamJudge[team] && onsiteByTeamJudge[team][j]) || 0;
        const b = (blindByTeamJudge[team]  && blindByTeamJudge[team][j])  || 0;
        const s = (sauceByTeamJudge[team]  && sauceByTeamJudge[team][j])  || 0;
        row.push(o);
        row.push(b);
        row.push(s);
        total += (o + b + s);
      });

      row.push(total);
      rows.push(row);
    });

    // Convert to CSV string
    const csv = rows.map(r => r.map(csvField).join(',')).join('\r\n');

    // Download
    const ts = new Date();
    const pad = n => n.toString().padStart(2,'0');
    const fname = `wh-report_${ts.getFullYear()}${pad(ts.getMonth()+1)}${pad(ts.getDate())}-${pad(ts.getHours())}${pad(ts.getMinutes())}${pad(ts.getSeconds())}.csv`;
    const blob = new Blob([csv], {type:'text/csv;charset=utf-8;'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = fname;
    document.body.appendChild(a);
    a.click();
    setTimeout(()=>{ URL.revokeObjectURL(a.href); a.remove(); }, 100);
  }

  document.addEventListener('DOMContentLoaded', function(){
    var btn = document.getElementById('wh-build-report-btn');
    if (btn) btn.addEventListener('click', buildReport);
  });
})();
</script>
'@

  if ($updated -match '(?is)</body\s*>\s*</html\s*>') {
    $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>', ($snippet + "`r`n</body></html>"), 1)
    $changed = $true
    Write-Host "✔ Added Build Report button + logic." -ForegroundColor Green
  } else {
    Write-Warning "Could not find </body></html> to inject the report code."
  }
} else {
  Write-Host "ℹ️ Build Report already present." -ForegroundColor Yellow
}

if ($changed) {
  Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
  Write-Host "✅ leaderboard.html updated." -ForegroundColor Green
} else {
  Write-Host "ℹ️ No changes applied." -ForegroundColor Yellow
}
