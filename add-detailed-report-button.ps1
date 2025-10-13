param(
  [Parameter(Mandatory=$true)]
  [string]$Path
)

if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }

# Resolve absolute paths
$abs  = (Resolve-Path -LiteralPath $Path).Path
$root = [System.IO.Path]::GetDirectoryName($abs)
if ([string]::IsNullOrWhiteSpace($root)) { $root = (Get-Location).Path }

# Backup HTML
$orig = Get-Content -LiteralPath $abs -Raw
$bak  = "$abs.bak_$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $abs -Destination $bak -Force
Write-Host "Backup: $bak" -ForegroundColor Yellow

$updated = $orig
$changed = $false

# 1) Append a NEW button under the existing one (id=wh-build-report2-btn)
if ($updated -notmatch 'id="wh-build-report2-btn"') {
  $btn2 = @'
<div id="wh-build-report2-container" style="width:100%;display:flex;justify-content:center;margin:8px 0 32px;">
  <button id="wh-build-report2-btn" class="go-btn" type="button"
          style="min-width:260px;padding:10px 14px;border-radius:10px;cursor:pointer;">
    Build Detailed Report (CSV)
  </button>
</div>
'@
  if ($updated -match '(?is)</body\s*>\s*</html\s*>') {
    $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>', ($btn2 + "`r`n</body></html>"), 1)
    $changed = $true
    Write-Host "✓ Added secondary button: Build Detailed Report (CSV)" -ForegroundColor Green
  } else {
    Write-Host "⚠ Could not find </body></html> to append the button. Add this snippet manually near the end:" -ForegroundColor Yellow
    Write-Host $btn2
  }
} else {
  Write-Host "• Detailed report button already present." -ForegroundColor DarkGray
}

# 2) Write/update wh-report.js with *good* grouped report and bind to the new button only
$jsPath = Join-Path $root "wh-report.js"
$js = @'
(function(){
  "use strict";
  const getArr = k => { try{ const v=localStorage.getItem(k); return v?JSON.parse(v):[]; }catch{ return []; } };
  const getMap = k => { try{ const v=localStorage.getItem(k); return v?JSON.parse(v):{}; }catch{ return {}; } };
  const norm   = s => (s==null ? "" : String(s)).trim();
  const toInt  = v => { const n=Number(v); return Number.isFinite(n)? Math.trunc(n) : 0; };
  const csvField = x => { const s=(x==null?"":String(x)); return /[",\n]/.test(s) ? '"' + s.replace(/"/g,'""') + '"' : s; };

  const CAT = {
    meatSauce:  ["meatSauce","meat_sauce","meat and sauce","meat&sauce","taste","flavor"],
    skin:       ["skin","crackling"],
    moisture:   ["moisture","juiciness"],
    appearance: ["appearance","visual","presentation"],
    tenderness: ["tenderness","texture"]
  };

  const pickInt = (scores, names) => {
    if (!scores || typeof scores!=="object") return 0;
    for (const want of names) {
      if (scores[want] != null) return toInt(scores[want]);
      const tgt = want.toLowerCase().replace(/[ _&]/g,"");
      for (const k in scores) {
        const kk = k.toLowerCase().replace(/[ _&]/g,"");
        if (kk === tgt) return toInt(scores[k]);
      }
    }
    return 0;
  };

  function buildGroupedReportCSV(){
    const onsite = getArr("onsiteScores");
    const blind  = getArr("blindScores");
    const sauce  = getArr("sauceScores");
    const teamsA = getArr("teams");
    const judgesA= getArr("judges");
    const divMap = getMap("landingTeamDivisions");
    const emailM = getMap("teamEmails");

    // union of all known team names (ensures teams show even with no scores)
    const teamSet = new Set();
    teamsA.forEach(t=>{ const n=norm(t?.team||t?.name); if(n) teamSet.add(n); });
    Object.keys(divMap||{}).forEach(n=>{ n=norm(n); if(n) teamSet.add(n); });
    Object.keys(emailM||{}).forEach(n=>{ n=norm(n); if(n) teamSet.add(n); });
    onsite.forEach(r=>{ const n=norm(r?.team||r?.teamName||r?.name); if(n) teamSet.add(n); });
    blind .forEach(r=>{ const n=norm(r?.team); if(n) teamSet.add(n); });
    sauce .forEach(r=>{ const n=norm(r?.team); if(n) teamSet.add(n); });

    const teams = Array.from(teamSet).sort((a,b)=>a.localeCompare(b));

    // judge list
    let judges = judgesA.map(j=>norm(j?.name)).filter(Boolean);
    if (!judges.length) {
      const s=new Set();
      onsite.forEach(r=>{ if (r?.judge) s.add(norm(r.judge)); });
      blind .forEach(r=>{ if (r?.judge) s.add(norm(r.judge)); });
      sauce .forEach(r=>{ if (r?.judge) s.add(norm(r.judge)); });
      judges = Array.from(s);
    }
    judges.sort((a,b)=>a.localeCompare(b));

    // per-team per-judge aggregates
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

    // Build grouped CSV rows
    const rows = [];
    for (const team of teams) {
      const division = divMap[team] || "";
      const email    = emailM[team] || "";
      const ttot     = teamTotal[team] || 0;

      // Team header row
      rows.push([`Team: ${team}`, `Division: ${division}`, `Email: ${email}`]);

      // Judge subheader
      rows.push(["Judge","Meat & Sauce","Skin","Moisture","Appearance","Tenderness","On-site Total","Blind","Sauce","Judge Total"]);

      // judges for this team = any judge seen for team OR fall back to one placeholder line
      const jset = new Set();
      if (onsiteTJ[team]) Object.keys(onsiteTJ[team]).forEach(j=>jset.add(j));
      if (blindTJ [team]) Object.keys(blindTJ [team]).forEach(j=>jset.add(j));
      if (sauceTJ [team]) Object.keys(sauceTJ [team]).forEach(j=>jset.add(j));
      let teamJudges = Array.from(jset);
      if (!teamJudges.length) teamJudges = judges.length ? judges.slice(0,1) : [""];
      teamJudges.sort((a,b)=>a.localeCompare(b));

      for (const j of teamJudges){
        const o = (onsiteTJ[team]?.[j]) || {ms:0,sk:0,mo:0,ap:0,te:0,total:0};
        const b = (blindTJ [team]?.[j]) || 0;
        const s = (sauceTJ [team]?.[j]) || 0;
        rows.push([ j, o.ms, o.sk, o.mo, o.ap, o.te, o.total, b, s, (o.total+b+s) ]);
      }

      // Team total row + spacer
      rows.push(["Team Total","","","","","","","","", ttot]);
      rows.push([""]);
    }

    if (!rows.length) { alert("No data in localStorage to build the report."); return false; }

    // CSV -> download
    const csv = rows.map(r => r.map(csvField).join(",")).join("\\r\\n");
    const ts=new Date(), pad=n=>String(n).padStart(2,"0");
    const name=`wh-report_grouped_${ts.getFullYear()}${pad(ts.getMonth()+1)}${pad(ts.getDate())}-${pad(ts.getHours())}${pad(ts.getMinutes())}${pad(ts.getSeconds())}.csv`;
    const blob=new Blob([csv],{type:"text/csv;charset=utf-8;"}), a=document.createElement("a");
    a.href=URL.createObjectURL(blob); a.download=name; document.body.appendChild(a); a.click();
    setTimeout(()=>{URL.revokeObjectURL(a.href); a.remove();},100);
    return false;
  }

  // Export
  window.buildGroupedReportCSV = buildGroupedReportCSV;

  // Bind only to the NEW button
  function bind(){
    const btn2=document.getElementById("wh-build-report2-btn");
    if (btn2 && !btn2._whBound) {
      btn2.addEventListener("click", function(e){
        e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
        buildGroupedReportCSV();
      });
      btn2._whBound = true;
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", bind, { once:true });
  else bind();
})();
'@
Set-Content -LiteralPath $jsPath -Value $js -Encoding UTF8
Write-Host "✓ Wrote/updated wh-report.js" -ForegroundColor Green

# 3) Ensure script include present
if ($updated -notmatch '(?is)wh-report\.js') {
  if ($updated -match '(?is)</body\s*>\s*</html\s*>') {
    $updated = [regex]::Replace($updated, '(?is)</body\s*>\s*</html\s*>',
      '<script id="wh-report-js" src="wh-report.js"></script>' + "`r`n</body></html>", 1)
    $changed = $true
    Write-Host "✓ Injected <script src=""wh-report.js""> include." -ForegroundColor Green
  } else {
    Write-Host "⚠ Could not find </body></html>. Add this line near the end:" -ForegroundColor Yellow
    Write-Host '   <script id="wh-report-js" src="wh-report.js"></script>' -ForegroundColor Yellow
  }
} else {
  Write-Host "• Script include already present." -ForegroundColor DarkGray
}

# 4) Save HTML if changed
if ($changed) {
  Set-Content -LiteralPath $abs -Value $updated -Encoding UTF8
  Write-Host "✅ Updated $abs" -ForegroundColor Green
} else {
  Write-Host "ℹ No changes needed to $abs" -ForegroundColor Yellow
}
