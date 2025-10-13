param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }

# Resolve paths
$abs  = (Resolve-Path -LiteralPath $Path).Path
$root = [System.IO.Path]::GetDirectoryName($abs)
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }

# Backup
$orig = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup: $bak" -ForegroundColor Yellow

$updated = $orig
$changed = $false

# 1) Ensure a Build Report button exists and add inline onclick
#    - add id if missing
#    - add/replace onclick to call buildGroupedReportCSV()
if ($updated -notmatch 'id="wh-build-report-btn"') {
  # Try to locate the existing button by its text and inject the id
  $updated2 = [regex]::Replace($updated,
    '(?is)(<button\b[^>]*>)(\s*Build\s+Report\s*\(CSV\)\s*)(</button>)',
    { param($m) 
      $open = $m.Groups[1].Value
      if ($open -notmatch 'id\s*=') { $open = $open.TrimEnd('>') + ' id="wh-build-report-btn">' }
      $open + $m.Groups[2].Value + $m.Groups[3].Value
    }, 1
  )
  if ($updated2 -ne $updated) {
    $updated = $updated2
    $changed = $true
    Write-Host "✓ Ensured button has id=""wh-build-report-btn""." -ForegroundColor Green
  } else {
    Write-Host "⚠ Could not find the Build Report button by text; adding one near </body>." -ForegroundColor Yellow
    $btn = @'
<div id="wh-build-report-container" style="width:100%;display:flex;justify-content:center;margin:20px 0 32px;">
  <button id="wh-build-report-btn" class="go-btn" type="button">Build Report (CSV)</button>
</div>
'@
    if ($updated -match '(?is)</body\s*>\s*</html\s*>') {
      $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>', ($btn + "`r`n</body></html>"), 1)
      $changed = $true
      Write-Host "✓ Added the Build Report button at the bottom." -ForegroundColor Green
    }
  }
}

# Add/replace inline onclick that calls the exported function
$updated2 = [regex]::Replace($updated,
  '(?is)(<button\b[^>]*\bid\s*=\s*"wh-build-report-btn"[^>]*)(>)',
  { param($m)
    $open = $m.Groups[1].Value
    # remove any existing onclick
    $open = [regex]::Replace($open, '\s+onclick\s*=\s*"[^"]*"', '')
    $open = [regex]::Replace($open, "\s+onclick\s*=\s*'[^']*'", '')
    $open + ' onclick="return buildGroupedReportCSV()"' + $m.Groups[2].Value
  }, 1
)
if ($updated2 -ne $updated) {
  $updated = $updated2
  $changed = $true
  Write-Host "✓ Wired button inline: onclick=""buildGroupedReportCSV()""." -ForegroundColor Green
}

# 2) Write wh-report.js (export function onto window)
$jsPath = Join-Path $root "wh-report.js"
$js = @'
(function(){
  "use strict";
  const getArr = k => { try{ const v=localStorage.getItem(k); return v?JSON.parse(v):[]; }catch{ return []; } };
  const getMap = k => { try{ const v=localStorage.getItem(k); return v?JSON.parse(v):{}; }catch{ return {}; } };
  const norm   = s => (s==null ? '' : String(s)).trim();
  const toInt  = v => { const n=Number(v); return Number.isFinite(n)? Math.trunc(n) : 0; };
  const csvField = x => { const s=(x==null?'':String(x)); return /[",\n]/.test(s) ? '"' + s.replace(/"/g,'""') + '"' : s; };

  const CAT = {
    meatSauce:  ['meatSauce','meat_sauce','meat and sauce','meat&sauce','taste','flavor'],
    skin:       ['skin','crackling'],
    moisture:   ['moisture','juiciness'],
    appearance: ['appearance','visual','presentation'],
    tenderness: ['tenderness','texture']
  };

  const pickInt = (scores, names) => {
    if (!scores || typeof scores!=='object') return 0;
    for (const want of names) {
      if (scores[want] != null) return toInt(scores[want]);
      const tgt = want.toLowerCase().replace(/[ _&]/g,'');
      for (const k in scores) {
        const kk = k.toLowerCase().replace(/[ _&]/g,'');
        if (kk === tgt) return toInt(scores[k]);
      }
    }
    return 0;
  };

  function buildGroupedReportCSV(){
    const onsite = getArr('onsiteScores');
    const blind  = getArr('blindScores');
    const sauce  = getArr('sauceScores');
    const teamsA = getArr('teams');
    const judgesA= getArr('judges');
    const divMap = getMap('landingTeamDivisions');
    const emailM = getMap('teamEmails');

    const teamSet = new Set();
    teamsA.forEach(t=>{ const n=norm(t?.team||t?.name); if(n) teamSet.add(n); });
    Object.keys(divMap||{}).forEach(n=>{ n=norm(n); if(n) teamSet.add(n); });
    Object.keys(emailM||{}).forEach(n=>{ n=norm(n); if(n) teamSet.add(n); });
    onsite.forEach(r=>{ const n=norm(r?.team||r?.teamName||r?.name); if(n) teamSet.add(n); });
    blind .forEach(r=>{ const n=norm(r?.team); if(n) teamSet.add(n); });
    sauce .forEach(r=>{ const n=norm(r?.team); if(n) teamSet.add(n); });

    const teams = Array.from(teamSet).sort((a,b)=>a.localeCompare(b));

    let judges = judgesA.map(j=>norm(j?.name)).filter(Boolean);
    if (!judges.length) {
      const s=new Set();
      onsite.forEach(r=>{ if (r?.judge) s.add(norm(r.judge)); });
      blind .forEach(r=>{ if (r?.judge) s.add(norm(r.judge)); });
      sauce .forEach(r=>{ if (r?.judge) s.add(norm(r.judge)); });
      judges = Array.from(s);
    }
    judges.sort((a,b)=>a.localeCompare(b));

    const onsiteTJ = {}, blindTJ = {}, sauceTJ = {}, teamTotal = {};
    const ensureO  = (t,j)=>{ (onsiteTJ[t] ||= {}); (onsiteTJ[t][j] ||= {ms:0,sk:0,mo:0,ap:0,te:0,total:0}); };
    const ensureTJ = (obj,t,j)=>{ (obj[t] ||= {}); (obj[t][j] ||= 0); };

    onsite.forEach(r=>{
      const t = norm(r?.team||r?.teamName||r?.name);
      const j = norm(r?.judge);
      if (!t||!j) return;
      const sc=r?.scores||{};
      const ms=pickInt(sc,CAT.meatSauce), sk=pickInt(sc,CAT.skin), mo=pickInt(sc,CAT.moisture),
            ap=pickInt(sc,CAT.appearance), te=pickInt(sc,CAT.tenderness), add=ms+sk+mo+ap+te;
      ensureO(t,j);
      onsiteTJ[t][j].ms+=ms; onsiteTJ[t][j].sk+=sk; onsiteTJ[t][j].mo+=mo; onsiteTJ[t][j].ap+=ap; onsiteTJ[t][j].te+=te; onsiteTJ[t][j].total+=add;
      teamTotal[t]=(teamTotal[t]||0)+add;
    });
    blind.forEach(r=>{
      const t=norm(r?.team), j=norm(r?.judge); if(!t||!j) return;
      ensureTJ(blindTJ,t,j); blindTJ[t][j]+=toInt(r?.score); teamTotal[t]=(teamTotal[t]||0)+toInt(r?.score);
    });
    sauce.forEach(r=>{
      const t=norm(r?.team), j=norm(r?.judge); if(!t||!j) return;
      ensureTJ(sauceTJ,t,j); sauceTJ[t][j]+=toInt(r?.score); teamTotal[t]=(teamTotal[t]||0)+toInt(r?.score);
    });

    const rows = [];
    for (const team of teams) {
      const division = divMap[team] || '';
      const email    = emailM[team] || '';
      const ttot     = teamTotal[team] || 0;

      rows.push([`Team: ${team}`, `Division: ${division}`, `Email: ${email}`]);
      rows.push(['Judge','Meat & Sauce','Skin','Moisture','Appearance','Tenderness','On-site Total','Blind','Sauce','Judge Total']);

      const jset = new Set();
      if (onsiteTJ[team]) Object.keys(onsiteTJ[team]).forEach(j=>jset.add(j));
      if (blindTJ [team]) Object.keys(blindTJ [team]).forEach(j=>jset.add(j));
      if (sauceTJ [team]) Object.keys(sauceTJ [team]).forEach(j=>jset.add(j));
      let teamJudges = Array.from(jset);
      if (!teamJudges.length) teamJudges = judges.length ? judges.slice(0,1) : [''];
      teamJudges.sort((a,b)=>a.localeCompare(b));

      for (const j of teamJudges){
        const o = (onsiteTJ[team]?.[j]) || {ms:0,sk:0,mo:0,ap:0,te:0,total:0};
        const b = (blindTJ [team]?.[j]) || 0;
        const s = (sauceTJ [team]?.[j]) || 0;
        rows.push([ j, o.ms, o.sk, o.mo, o.ap, o.te, o.total, b, s, (o.total+b+s) ]);
      }

      rows.push(['Team Total','','','','','','','','', ttot]);
      rows.push(['']);
    }

    if (!rows.length) { alert('No data in localStorage to build the report.'); return false; }

    const csv = rows.map(r => r.map(csvField).join(',')).join('\r\n');
    const ts=new Date(), pad=n=>String(n).padStart(2,'0');
    const name=`wh-report_grouped_${ts.getFullYear()}${pad(ts.getMonth()+1)}${pad(ts.getDate())}-${pad(ts.getHours())}${pad(ts.getMinutes())}${pad(ts.getSeconds())}.csv`;
    const blob=new Blob([csv],{type:'text/csv;charset=utf-8;'}), a=document.createElement('a');
    a.href=URL.createObjectURL(blob); a.download=name; document.body.appendChild(a); a.click();
    setTimeout(()=>{URL.revokeObjectURL(a.href); a.remove();},100);
    return false;
  }

  // Export so inline onclick can call it
  window.buildGroupedReportCSV = buildGroupedReportCSV;

  // Also bind via JS in case inline is stripped by any sanitizer
  function bind(){
    const btn=document.getElementById('wh-build-report-btn');
    if (btn && !btn._whBound) { btn.addEventListener('click', buildGroupedReportCSV); btn._whBound = true; }
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind, { once:true });
  else bind();
})();
'@
Set-Content -LiteralPath $jsPath -Value $js -Encoding UTF8
Write-Host "✓ Wrote $jsPath" -ForegroundColor Green

# 3) Inject <script src="wh-report.js"> include if missing
if ($updated -notmatch '(?is)wh-report\.js') {
  $include = '<script id="wh-report-js" src="wh-report.js"></script>'
  if ($updated -match '(?is)</body\s*>\s*</html\s*>') {
    $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>', ($include + "`r`n</body></html>"), 1)
    $changed = $true
    Write-Host "✓ Injected <script src=""wh-report.js""> include." -ForegroundColor Green
  } else {
    Write-Host "⚠ Could not find </body></html> to add the script include. Add this line near the end:" -ForegroundColor Yellow
    Write-Host '   <script id="wh-report-js" src="wh-report.js"></script>' -ForegroundColor Yellow
  }
} else {
  Write-Host "• Script include already present." -ForegroundColor DarkGray
}

# 4) Save if changed
if ($changed) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Updated $abs" -ForegroundColor Green
} else {
  Write-Host "ℹ No changes needed to $abs" -ForegroundColor Yellow
}
