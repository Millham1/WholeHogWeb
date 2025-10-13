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

# Ensure the button exists; if not, add it (non-destructive)
if ($updated -notmatch 'id=["'']wh-build-report-btn["'']') {
$btn = @'
<!-- Build Report (CSV) -->
<div id="wh-build-report-container" style="width:100%;display:flex;justify-content:center;margin:20px 0 32px;">
  <button id="wh-build-report-btn" class="go-btn" type="button"
          style="min-width:220px;padding:10px 14px;border-radius:10px;cursor:pointer;">
    Build Report (CSV)
  </button>
</div>
'@
  if ($updated -match '(?is)</body\s*>\s*</html\s*>') {
    $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>', ($btn + "`r`n</body></html>"), 1)
    Write-Host "✔ Added Build Report button." -ForegroundColor Green
    $changed = $true
  } else {
    Write-Warning "Could not find </body></html> to inject the button."
  }
}

# Replace (or insert) the report logic so it outputs per-judge rows with full category detail
$logicPattern = '(?is)<script[^>]*id=["'']wh-build-report-logic["''][^>]*>.*?</script>'
$logicBlock = @'
<script id="wh-build-report-logic">
(function(){
  "use strict";

  function getArr(k){ try{ const v=localStorage.getItem(k); return v?JSON.parse(v):[]; }catch{ return []; } }
  function getMap(k){ try{ const v=localStorage.getItem(k); return v?JSON.parse(v):{}; }catch{ return {}; } }
  function norm(s){ return (s==null? "": String(s)).trim(); }
  function toInt(v){ const n=Number(v); return Number.isFinite(n)? Math.trunc(n): 0; }

  // CSV escaping
  function csvField(x){
    const s = (x==null? "": String(x));
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g,'""') + '"' : s;
  }

  // On-site category aliases
  const CAT_ALIAS = {
    meatSauce:  ['meatSauce','meat_sauce','meat and sauce','meat&sauce','taste','flavor'],
    skin:       ['skin','crackling'],
    moisture:   ['moisture','juiciness'],
    appearance: ['appearance','visual','presentation'],
    tenderness: ['tenderness','texture']
  };
  const CAT_KEYS = ['meatSauce','skin','moisture','appearance','tenderness'];

  function pickInt(scores, names){
    if (!scores || typeof scores!=='object') return 0;
    for (let i=0;i<names.length;i++){
      const want = names[i];
      if (scores[want] != null) return toInt(scores[want]);
      const tgt = want.toLowerCase().replace(/[ _&]/g,'');
      for (const k in scores){
        if (!Object.prototype.hasOwnProperty.call(scores,k)) continue;
        const kk = k.toLowerCase().replace(/[ _&]/g,'');
        if (kk === tgt) return toInt(scores[k]);
      }
    }
    return 0;
  }

  function buildReport(){
    // Snapshots
    const onsite = getArr('onsiteScores');   // [{team, judge, scores:{...}}]
    const blind  = getArr('blindScores');    // [{team, judge, score}]
    const sauce  = getArr('sauceScores');    // [{team, judge, score}]
    const judgesArr = getArr('judges');      // [{name}]
    const teamsArr  = getArr('teams');       // [{team}]
    const divMap    = getMap('landingTeamDivisions'); // {"Team":"Legion"/"Sons"}
    const emailMap  = getMap('teamEmails');  // {"Team":"email@host"}

    // Judge list
    let judges = judgesArr.map(j => norm(j.name)).filter(Boolean);
    if (!judges.length){
      const seen = new Set();
      onsite.forEach(r => { if (r && r.judge) seen.add(norm(r.judge)); });
      blind.forEach(r => { if (r && r.judge) seen.add(norm(r.judge)); });
      sauce.forEach(r => { if (r && r.judge) seen.add(norm(r.judge)); });
      judges = Array.from(seen);
    }
    judges.sort((a,b)=>a.localeCompare(b));

    // Team list
    let teams = teamsArr.map(t => norm(t.team)).filter(Boolean);
    if (!teams.length){
      const seen = new Set();
      onsite.forEach(r => { if (r && r.team) seen.add(norm(r.team)); });
      blind.forEach(r => { if (r && r.team) seen.add(norm(r.team)); });
      sauce.forEach(r => { if (r && r.team) seen.add(norm(r.team)); });
      teams = Array.from(seen);
    }
    teams.sort((a,b)=>a.localeCompare(b));

    // Build per-team per-judge aggregates
    const onsiteAgg = {}; // team -> judge -> {ms,sk,mo,ap,te, total}
    const blindAgg  = {}; // team -> judge -> blind
    const sauceAgg  = {}; // team -> judge -> sauce
    const teamTotals = {}; // team -> total across all judges (onsite total + blind + sauce)

    function ensureTJ(obj, t, j) {
      if (!obj[t]) obj[t] = {};
      if (!obj[t][j]) obj[t][j] = 0;
    }
    function ensureOnsite(t, j) {
      if (!onsiteAgg[t]) onsiteAgg[t]={};
      if (!onsiteAgg[t][j]) onsiteAgg[t][j]={ms:0,sk:0,mo:0,ap:0,te:0,total:0};
    }

    // On-site: sum by category per judge
    onsite.forEach(r=>{
      const t = norm(r.team || r.teamName || r.name);
      const j = norm(r.judge);
      if (!t || !j) return;
      const sc = r.scores || {};
      ensureOnsite(t,j);
      const ms = pickInt(sc, CAT_ALIAS.meatSauce);
      const sk = pickInt(sc, CAT_ALIAS.skin);
      const mo = pickInt(sc, CAT_ALIAS.moisture);
      const ap = pickInt(sc, CAT_ALIAS.appearance);
      const te = pickInt(sc, CAT_ALIAS.tenderness);
      const add = ms+sk+mo+ap+te;
      onsiteAgg[t][j].ms += ms;
      onsiteAgg[t][j].sk += sk;
      onsiteAgg[t][j].mo += mo;
      onsiteAgg[t][j].ap += ap;
      onsiteAgg[t][j].te += te;
      onsiteAgg[t][j].total += add;
      teamTotals[t] = (teamTotals[t]||0) + add;
    });

    // Blind
    blind.forEach(r=>{
      const t = norm(r.team), j = norm(r.judge);
      if (!t || !j) return;
      ensureTJ(blindAgg, t, j);
      blindAgg[t][j] += toInt(r.score);
      teamTotals[t] = (teamTotals[t]||0) + toInt(r.score);
    });

    // Sauce
    sauce.forEach(r=>{
      const t = norm(r.team), j = norm(r.judge);
      if (!t || !j) return;
      ensureTJ(sauceAgg, t, j);
      sauceAgg[t][j] += toInt(r.score);
      teamTotals[t] = (teamTotals[t]||0) + toInt(r.score);
    });

    // Header: Team, Division, Email, Judge, 5 categories, On-site Total, Blind, Sauce, Judge Total, Team Total
    const header = [
      'Team','Division','Email','Judge',
      'Meat & Sauce','Skin','Moisture','Appearance','Tenderness',
      'On-site Total','Blind','Sauce','Judge Total','Team Total'
    ];
    const rows = [header];

    // Build rows
    teams.forEach(team=>{
      const division = divMap[team] || '';
      const email = emailMap[team] || '';
      const ttotal = teamTotals[team] || 0;

      // If no judges known yet, still emit a single, empty row for the team
      if (!judges.length) {
        rows.push([team,division,email,'',0,0,0,0,0,0,0,0,0,ttotal]);
      } else {
        judges.forEach(j=>{
          const o = (onsiteAgg[team] && onsiteAgg[team][j]) || {ms:0,sk:0,mo:0,ap:0,te:0,total:0};
          const b = (blindAgg[team]  && blindAgg[team][j])  || 0;
          const s = (sauceAgg[team]  && sauceAgg[team][j])  || 0;
          const judgeTotal = (o.total + b + s);
          rows.push([
            team, division, email, j,
            o.ms, o.sk, o.mo, o.ap, o.te,
            o.total, b, s, judgeTotal, ttotal
          ]);
        });
      }
      // blank separator row between teams (helps readability in Excel)
      rows.push(['','','','','','','','','','','','','','']);
    });

    // CSV string
    const csv = rows.map(r => r.map(csvField).join(',')).join('\\r\\n');

    // Download
    const ts = new Date();
    const pad = n => n.toString().padStart(2,'0');
    const fname = `wh-report_detailed_${ts.getFullYear()}${pad(ts.getMonth()+1)}${pad(ts.getDate())}-${pad(ts.getHours())}${pad(ts.getMinutes())}${pad(ts.getSeconds())}.csv`;
    const blob = new Blob([csv], {type:'text/csv;charset=utf-8;'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = fname;
    document.body.appendChild(a);
    a.click();
    setTimeout(()=>{ URL.revokeObjectURL(a.href); a.remove(); }, 100);
  }

  document.addEventListener('DOMContentLoaded', function(){
    const btn = document.getElementById('wh-build-report-btn');
    if (btn) btn.addEventListener('click', buildReport);
  });
})();
</script>
'@

if ($updated -match $logicPattern) {
  $updated = [regex]::Replace($updated, $logicPattern, $logicBlock, 1)
  Write-Host "✔ Replaced existing Build Report logic with detailed per-judge export." -ForegroundColor Green
  $changed = $true
}
elseif ($updated -match '(?is)</body\s*>\s*</html\s*>') {
  $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>', ($logicBlock + "`r`n</body></html>"), 1)
  Write-Host "✔ Inserted detailed Build Report logic." -ForegroundColor Green
  $changed = $true
} else {
  Write-Warning "Could not find a place to insert the report logic."
}

# Write back
if ($changed) {
  Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
  Write-Host "✅ leaderboard.html updated." -ForegroundColor Green
} else {
  Write-Host "ℹ️ No changes applied." -ForegroundColor Yellow
}
