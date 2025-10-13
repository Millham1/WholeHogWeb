param(
  [Parameter(Mandatory=$true)] [string]$LandingPath,
  [Parameter(Mandatory=$true)] [string]$OnsitePath,
  [Parameter(Mandatory=$true)] [string]$BlindPath,
  [Parameter(Mandatory=$true)] [string]$LeaderboardPath,
  [Parameter(Mandatory=$true)] [string]$SaucePath
)

# ---------- helpers ----------
function Read-Utf8NoBom([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8NoBom([string]$p, [string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $s, $enc)
}
function Backup([string]$p){
  if (!(Test-Path $p)) { return $null }
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $bak = "$p.$stamp.bak"
  Copy-Item $p $bak -Force
  Write-Host "🔒 Backup: $bak"
  return $bak
}

# ---------- 0) backups ----------
$bk1 = Backup $LandingPath
$bk2 = Backup $OnsitePath
$bk3 = Backup $BlindPath
$bk4 = Backup $LeaderboardPath
if (Test-Path $SaucePath) { $bk5 = Backup $SaucePath }

# ---------- 1) add “Go to Sauce Tasting” button to navs (non-destructive) ----------
$sauceAnchor = '<a href="./sauce.html">Go to Sauce Tasting</a>'

function Add-NavButton([string]$html){
  $changed = $false

  # Prefer <nav id="wholehog-nav">
  $navPat = '(?is)(<nav\s+[^>]*\bid\s*=\s*["'']wholehog-nav["''][^>]*>)(.*?)(</nav>)'
  if ([regex]::IsMatch($html, $navPat)) {
    $html = [regex]::Replace($html, $navPat, {
      param($m)
      $open = $m.Groups[1].Value
      $inner = $m.Groups[2].Value
      $close = $m.Groups[3].Value
      if ($inner -notmatch '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
        $inner = $inner.Trim() + "`r`n  $sauceAnchor`r`n"
        $changed = $true
      }
      return $open + $inner + $close
    }, 1)
  } else {
    # Fallback: #top-go-buttons
    $topPat = '(?is)(<div\s+[^>]*\bid\s*=\s*["'']top-go-buttons["''][^>]*>)(.*?)(</div>)'
    if ([regex]::IsMatch($html, $topPat)) {
      $html = [regex]::Replace($html, $topPat, {
        param($m)
        $open = $m.Groups[1].Value
        $inner = $m.Groups[2].Value
        $close = $m.Groups[3].Value
        if ($inner -match '(?is)<a\b' -and $inner -notmatch '(?is)href\s*=\s*["'']\./sauce\.html["'']') {
          $inner = $inner.Trim() + "`r`n  $sauceAnchor`r`n"
          $changed = $true
        }
        return $open + $inner + $close
      }, 1)
    }
  }

  # Add the red/bold nav styling once if we changed nav
  if ($changed -and $html -notmatch '(?is)id\s*=\s*["'']sauce-nav-override["'']') {
    $style = @'
<style id="sauce-nav-override">
  #wholehog-nav{
    max-width: 820px;
    margin: 12px auto;
    display:flex; justify-content:center; align-items:center; gap:12px; flex-wrap:wrap; text-align:center;
  }
  #wholehog-nav a, #top-go-buttons a{
    display:inline-flex; align-items:center; justify-content:center; white-space:nowrap;
    padding:10px 14px; border-radius:10px; background:#e53935 !important; color:#000 !important;
    font-weight:800 !important; border:2px solid #000 !important; text-decoration:none; min-width:180px;
  }
  #wholehog-nav a:hover, #top-go-buttons a:hover{ filter:brightness(0.92); }
</style>
'@
    if ($html -match '(?is)</head\s*>') {
      $html = [regex]::Replace($html, '(?is)</head\s*>', ($style + "`r`n</head>"), 1)
    } else {
      $html = $style + $html
    }
  }

  return $html
}

# Apply to pages
$landingHtml = Read-Utf8NoBom $LandingPath
$landingHtml = Add-NavButton $landingHtml
Write-Utf8NoBom $LandingPath $landingHtml
Write-Host "✅ Updated nav in: $LandingPath"

$onsiteHtml = Read-Utf8NoBom $OnsitePath
$onsiteHtml = Add-NavButton $onsiteHtml
Write-Utf8NoBom $OnsitePath $onsiteHtml
Write-Host "✅ Updated nav in: $OnsitePath"

$blindHtml = Read-Utf8NoBom $BlindPath
$blindHtml = Add-NavButton $blindHtml
Write-Utf8NoBom $BlindPath $blindHtml
Write-Host "✅ Updated nav in: $BlindPath"

$leaderHtml = Read-Utf8NoBom $LeaderboardPath
$leaderHtml = Add-NavButton $leaderHtml

# ---------- 2) add Sauce Tasting card & logic to leaderboard (non-destructive) ----------
if ($leaderHtml -notmatch '(?is)id\s*=\s*["'']sauce-card["'']') {
  $sauceCard = @'
    <section class="card" id="sauce-card" style="margin-top:18px;">
      <h2>Sauce Tasting</h2>
      <div class="muted">Combined sauce score across all judges per team.</div>
      <div id="sauce-list" class="list"></div>
    </section>
'@
  if ($leaderHtml -match '(?is)</main\s*>') {
    $leaderHtml = [regex]::Replace($leaderHtml, '(?is)</main\s*>', ($sauceCard + "`r`n</main>"), 1)
    Write-Host "➕ Inserted Sauce Tasting card into: $LeaderboardPath"
  } else {
    $leaderHtml = [regex]::Replace($leaderHtml, '(?is)</body\s*>', ($sauceCard + "`r`n</body>"), 1)
    Write-Host "➕ Appended Sauce Tasting card near end of: $LeaderboardPath"
  }
}

if ($leaderHtml -notmatch '(?is)wh-sauce-leaders-script') {
  $leadersJs = @'
<script id="wh-sauce-leaders-script">
(function(){
  const K = { chipMap:'wh_chipByTeam', sauce:'sauceScores' };

  function getList(k){ try { return JSON.parse(localStorage.getItem(k)||"[]"); } catch { return []; } }
  function getJSON(k,fb){ try { const v = localStorage.getItem(k); return v?JSON.parse(v):fb; } catch { return fb; } }
  function norm(v){ return (v||"").toString().trim(); }
  function sumNumbers(obj){
    let s=0; if(!obj||typeof obj!=='object') return 0;
    for (const [k,v] of Object.entries(obj)){ const n=Number(v); if (Number.isFinite(n)) s+=n; }
    return s;
  }
  function chipFor(team){
    const name = norm(team); if (!name) return "";
    const map = getJSON(K.chipMap, null);
    if (map && typeof map==="object" && map[name]) return String(map[name]);
    const arr = getList(K.sauce);
    for (const r of arr){
      const tn = norm(r.team||r.teamName);
      if (tn===name){
        if (r.chip) return String(r.chip);
        if (r.chip_number) return String(r.chip_number);
      }
    }
    return "";
  }

  function buildSauce(){
    const raw = getList(K.sauce); // expected: {team, judge, score, ts}
    const byTeam = new Map();
    for (const r of raw){
      const team = norm(r.team||r.teamName);
      if (!team) continue;
      const val = Number(r.score);
      const add = Number.isFinite(val) ? val : (r.scores ? sumNumbers(r.scores) : 0);
      const agg = byTeam.get(team) || { team, total:0, cnt:0 };
      agg.total += add; agg.cnt += 1;
      byTeam.set(team, agg);
    }
    return Array.from(byTeam.values()).sort((a,b)=> b.total - a.total);
  }

  function renderSauce(){
    const host = document.getElementById('sauce-list');
    if (!host) return;
    const items = buildSauce();
    if (!items.length){ host.innerHTML = '<div class="muted">No sauce tasting scores yet.</div>'; return; }

    host.innerHTML = items.map(({team,total})=>{
      const chip = chipFor(team);
      const chipId = 'chip-' + btoa(unescape(encodeURIComponent('sauce:'+team))).replace(/=+$/,'');
      return `
        <div class="row">
          <div>
            <div><strong>${team}</strong></div>
            <div class="muted">sauce total</div>
          </div>
          <div class="score">${total}</div>
          <div>
            <button class="btn" type="button" data-chip-target="${chipId}">Show chip</button>
            <span id="${chipId}" class="chip">${chip ? ('Chip: '+chip) : 'Chip: (none)'}</span>
          </div>
        </div>`;
    }).join('');

    host.querySelectorAll('button[data-chip-target]').forEach(btn=>{
      btn.addEventListener('click', ()=>{
        const id = btn.getAttribute('data-chip-target');
        const span = document.getElementById(id);
        if (!span) return;
        const on = span.classList.toggle('show');
        btn.textContent = on ? 'Hide chip' : 'Show chip';
      });
    });
  }

  function renderAll(){ renderSauce(); }
  document.addEventListener('DOMContentLoaded', renderAll);
  window.addEventListener('storage', (e)=>{ if (e && e.key==='sauceScores') renderAll(); });
  document.addEventListener('visibilitychange', ()=>{ if (!document.hidden) renderAll(); });
})();
</script>
'@
  if ($leaderHtml -match '(?is)</body\s*>') {
    $leaderHtml = [regex]::Replace($leaderHtml, '(?is)</body\s*>', ($leadersJs + "`r`n</body>"), 1)
  } else {
    $leaderHtml += "`r`n" + $leadersJs
  }
  Write-Host "🧮 Added sauce leaderboard logic to: $LeaderboardPath"
}

Write-Utf8NoBom $LeaderboardPath $leaderHtml
Write-Host "✅ Leaderboard updated."

# ---------- 3) create sauce.html page (if missing) ----------
if (-not (Test-Path $SaucePath)) {
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
    body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif; margin:0; background:#fafafa; }
    header { height:var(--wh-header-h); min-height:var(--wh-header-h); position:relative; display:flex; align-items:center; justify-content:center; background:white; }
    header h1 { margin:0; line-height:1.1; text-align:center; }
    header img:first-of-type { position:absolute; left:14px; top:50%; transform:translateY(-50%); height:calc(100% - 20px); width:auto; }
    header img:last-of-type  { position:absolute; right:14px; top:50%; transform:translateY(-50%); height:calc(100% - 20px); width:auto; }

    #wholehog-nav { max-width:820px; margin:12px auto; display:flex; justify-content:center; align-items:center; gap:12px; flex-wrap:wrap; text-align:center; }
    #wholehog-nav a { display:inline-flex; align-items:center; justify-content:center; white-space:nowrap; padding:10px 14px; border-radius:10px; background:#e53935; color:#000; font-weight:800; border:2px solid #000; text-decoration:none; min-width:180px; }
    #wholehog-nav a:hover { filter:brightness(0.92); }

    .container { max-width:1100px; margin:18px auto; padding:0 14px; }
    .card { border:1px solid var(--line); border-radius:12px; padding:14px; background:#fff; }
    .card h2 { margin:0 0 10px 0; }
    .row { display:flex; gap:14px; flex-wrap:wrap; align-items:flex-end; }
    .field { display:flex; flex-direction:column; gap:6px; }
    .field label { font-weight:600; }
    .input, select { padding:8px 10px; border:1px solid #bbb; border-radius:8px; }
    .btn { padding:10px 16px; border-radius:10px; border:1px solid #111; background:#f5f5f5; cursor:pointer; }
    .btn-primary { background:#111; color:#fff; }
    .muted { color:#666; font-size:12px; }
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
    <a href="./sauce.html">Go to Sauce Tasting</a>
  </nav>

  <main class="container">
    <section class="card">
      <h2>Enter Sauce Score</h2>
      <div class="row">
        <div class="field" style="flex:1 1 260px; min-width:220px;">
          <label for="team">Team</label>
          <select id="team" class="input">
            <option value="">Select team…</option>
          </select>
        </div>
        <div class="field" style="flex:1 1 260px; min-width:220px;">
          <label for="judge">Judge</label>
          <select id="judge" class="input">
            <option value="">Select judge…</option>
          </select>
        </div>
        <div class="field" style="flex:0 0 140px;">
          <label for="score">Score</label>
          <input id="score" class="input" type="number" step="0.1" min="0" placeholder="e.g., 9.2"/>
        </div>
        <div style="flex:0 0 auto;">
          <button id="enterBtn" class="btn btn-primary" type="button">Enter</button>
        </div>
      </div>
      <div class="muted" id="status" style="margin-top:8px;">Saved scores appear on the Leaderboard → Sauce Tasting.</div>
    </section>
  </main>

  <script>
  (function(){
    const K = { teams:'wh_Teams', judges:'wh_Judges', selTeam:'selectedTeamName', selJudge:'selectedJudgeName', sauce:'sauceScores' };
    const $ = (s,r)=> (r||document).querySelector(s);
    function getList(k){ try { return JSON.parse(localStorage.getItem(k)||'[]'); } catch { return []; } }
    function setList(k,v){ localStorage.setItem(k, JSON.stringify(v)); }
    function getStr(k){ const v=localStorage.getItem(k); return (typeof v==='string')?v:''; }
    function uniqNames(arr,prop){ if(!Array.isArray(arr)) return []; const n=arr.map(o=>(o&&o[prop])?String(o[prop]):'').filter(Boolean); return Array.from(new Set(n)); }

    function refreshDropdowns(){
      const teams  = uniqNames(getList(K.teams),'name');
      const judges = uniqNames(getList(K.judges),'name');
      const teamSel = $('#team'), judgeSel = $('#judge');
      const curT = getStr(K.selTeam), curJ = getStr(K.selJudge);

      if (teamSel){
        teamSel.innerHTML = ['<option value="">Select team…</option>'].concat(teams.map(n=>`<option value="${n}">${n}</option>`)).join('');
        if (curT && teams.includes(curT)) teamSel.value = curT;
      }
      if (judgeSel){
        judgeSel.innerHTML = ['<option value="">Select judge…</option>'].concat(judges.map(n=>`<option value="${n}">${n}</option>`)).join('');
        if (curJ && judges.includes(curJ)) judgeSel.value = curJ;
      }
    }

    function enterScore(){
      const team = $('#team')?.value || '';
      const judge = $('#judge')?.value || '';
      const scr = Number($('#score')?.value);
      if (!team)  { alert('Please select a team.'); return; }
      if (!judge) { alert('Please select a judge.'); return; }
      if (!Number.isFinite(scr)) { alert('Enter a numeric score.'); return; }

      const arr = getList(K.sauce);
      arr.unshift({ team, judge, score: scr, ts: new Date().toISOString() });
      setList(K.sauce, arr);

      localStorage.setItem(K.selTeam, team);
      localStorage.setItem(K.selJudge, judge);

      if ($('#score')) $('#score').value = '';
      const st = $('#status'); if (st) { st.textContent = 'Saved locally at ' + new Date().toLocaleTimeString(); setTimeout(()=>st.textContent='Saved scores appear on the Leaderboard → Sauce Tasting.', 3000); }
      alert('Sauce score saved for ' + team);
    }

    document.addEventListener('DOMContentLoaded', ()=>{
      refreshDropdowns();
      const btn = $('#enterBtn'); if (btn) btn.addEventListener('click', enterScore);
      const teamSel = $('#team'); if (teamSel) teamSel.addEventListener('change', ()=>{ if(teamSel.value) localStorage.setItem(K.selTeam, teamSel.value); });
      const judgeSel = $('#judge'); if (judgeSel) judgeSel.addEventListener('change', ()=>{ if(judgeSel.value) localStorage.setItem(K.selJudge, judgeSel.value); });
    });
    window.addEventListener('storage', (e)=>{ if (e && (e.key==='wh_Teams' || e.key==='wh_Judges')) refreshDropdowns(); });
    document.addEventListener('visibilitychange', ()=>{ if (!document.hidden) refreshDropdowns(); });
  })();
  </script>
</body>
</html>
'@
  Write-Utf8NoBom $SaucePath $sauceHtml
  Write-Host "✅ Created: $SaucePath"
} else {
  Write-Host "ℹ️ $SaucePath already exists; not overwriting."
}

Write-Host "🎉 Done. Nav updated on all pages, Sauce page created, leaderboard extended."
