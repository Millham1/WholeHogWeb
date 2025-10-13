# rollback-to-local.ps1  (PowerShell 5.1 compatible)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ensure-Dir([string]$p){
  $d = Split-Path $p -Parent
  if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}
function Write-Text([string]$Path,[string]$Content){
  Ensure-Dir $Path
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Backup-IfExists([string[]]$Files, [string]$Root){
  $stamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
  $bak = Join-Path $Root ("BACKUP_" + $stamp)
  $copied = $false
  foreach($f in $Files){
    $p = Join-Path $Root $f
    if(Test-Path $p){
      if(-not $copied){ New-Item -ItemType Directory -Force -Path $bak | Out-Null; $copied=$true }
      $destDir = Join-Path $bak (Split-Path $p -Parent | Split-Path -Leaf)
      if(-not (Test-Path $destDir)){ New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
      Copy-Item $p (Join-Path $bak (Split-Path $p -Leaf)) -Force
    }
  }
  if($copied){ Write-Host "Backed up to $bak" -ForegroundColor Yellow }
}

if(-not (Test-Path $WebRoot)){ throw "Web root not found: $WebRoot" }

# Back up current files if they exist
Backup-IfExists @('landing.html','landing.js','onsite.html','onsite.js','styles.css') $WebRoot

# ---------------- styles.css ----------------
$css = @'
:root{
  /* colors reversed: BLUE–WHITE–RED */
  --brand-blue:#083d8c;
  --brand-white:#ffffff;
  --brand-red:#b10020;

  --bg:#f7f9ff;
  --card:#ffffff;
  --ink:#111;
  --muted:#666;

  --radius:14px;
  --shadow:0 6px 20px rgba(0,0,0,.12);
}
*{box-sizing:border-box}
body{
  margin:0; font-family:system-ui,Segoe UI,Arial; color:var(--ink); background:var(--bg);
}
.container{max-width:1100px; margin:0 auto; padding:16px;}

.header{
  position:relative;
  display:flex; align-items:center; justify-content:center;
  height:120px; border-radius:16px; margin:16px;
  background: linear-gradient(90deg, var(--brand-blue) 0%, var(--brand-white) 50%, var(--brand-red) 100%);
  box-shadow: var(--shadow);
}
.header .title{
  position:absolute; left:50%; top:50%; transform:translate(-50%,-50%);
  margin:0; color:#000; font-weight:900; font-size:34px; letter-spacing:.3px;
  text-align:center;
}
.header .left-img{
  position:absolute; left:18px; top:50%; transform:translateY(-50%);
  width:3in; height:auto; display:block; /* pig 3 inches, vertically centered */
}
.header .right-img{
  position:absolute; right:18px; top:50%; transform:translateY(-50%);
  width:1.5in; height:auto; display:block; /* medallion 1.5 inches, vertically centered */
}

.card{
  background:var(--card); border-radius:var(--radius); padding:16px; margin:16px; box-shadow:var(--shadow);
}
.card h2{ margin:0 0 10px 0; font-size:20px }
.row{ padding:4px 0; border-bottom:1px solid #eee }
.row:last-child{ border-bottom:none }
.muted{ color:var(--muted) }

.flex{ display:flex; gap:12px; flex-wrap:wrap; }
.input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; min-width:200px; }
.btn{ padding:10px 14px; border-radius:12px; border:0; cursor:pointer; background:#222; color:#fff; box-shadow:0 2px 8px rgba(0,0,0,.12);}
.btn.secondary{ background:#f2f3f8; color:#111; border:1px solid #e6e8f2; }

.grid-2{ display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:12px; }
.grid-3{ display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:12px; }

.badge{ display:inline-block; background:#f2f3ff; border:1px solid #e5e8fb; padding:4px 8px; border-radius:999px; font-size:12px; }

.scoring-wrap{ display:grid; grid-template-columns: 1fr; gap:12px; }
.scoring-top{
  display:flex; align-items:center; justify-content:space-between; gap:12px;
}
.suitable{
  display:flex; align-items:center; gap:8px; font-weight:700; font-size:17px;
}
.suitable select{ padding:6px 8px; border:1px solid #ddd; border-radius:10px; }

.minicard{
  background:#fff; border:1px solid #eee; border-radius:12px; padding:12px;
  display:flex; align-items:center; justify-content:space-between; gap:10px;
}
.minicard h4{ margin:0; font-size:16px; font-weight:700; }
.minicard .value{ font-weight:800; }

.picker{
  position:relative;
}
.picker button{
  padding:8px 10px; border-radius:10px; border:1px solid #ddd; background:#fafbfd; cursor:pointer;
}
.picker .panel{
  position:absolute; left:0; top:calc(100% + 6px);
  display:none; z-index:50;
  background:#fff; border:1px solid #e7e9f4; border-radius:12px; padding:8px; width:420px; max-width:95vw;
  box-shadow:0 10px 30px rgba(0,0,0,.15);
}
.picker.open .panel{ display:block; }
.panel .optbar{ display:flex; flex-wrap:wrap; gap:6px; }
.panel .optbar .opt{
  padding:6px 8px; min-width:44px; text-align:center; border-radius:8px; border:1px solid #eee; cursor:pointer; background:#f8f9fe;
}
.panel .opt:hover{ background:#eef1ff; }

.compl{ border:1px dashed #e0e4f3; border-radius:12px; padding:10px; }
.compl legend{ font-size:12px; color:#555; }
.compl .grid{
  display:grid; grid-template-columns:repeat(2,minmax(200px,1fr)); gap:8px;
}
.compl label{ display:flex; align-items:center; gap:6px; }
.compl .pts{ margin-left:auto; font-weight:700; }

.totalbar{
  display:flex; align-items:center; justify-content:center; gap:10px; margin-top:8px;
}
.totalbar .total{ font-weight:900; font-size:22px; }

.leader table{ width:100%; border-collapse:collapse; }
.leader th, .leader td{ padding:8px; border-bottom:1px solid #eee; text-align:left; }
.leader th{ background:#f7f8ff; }
'@
Write-Text (Join-Path $WebRoot 'styles.css') $css

# ---------------- landing.html ----------------
$landing = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Whole Hog Competition 2025</title>
  <link rel="stylesheet" href="styles.css"/>
</head>
<body>
  <header class="header">
    <img class="left-img" src="pig-rwb-1024.png" alt="Pig"/>
    <h1 class="title">Whole Hog Competition 2025</h1>
    <img class="right-img" src="AL Medallion.png" alt="American Legion"/>
  </header>

  <div class="container">
    <div class="card">
      <h2>Teams</h2>
      <form id="teamForm" class="flex">
        <input id="teamName" class="input" placeholder="Team name"/>
        <input id="siteNumber" class="input" placeholder="Site #"/>
        <button class="btn" type="submit">Add Team</button>
      </form>
      <div id="teamsOut" class="grid-2" style="margin-top:10px;"></div>
    </div>

    <div class="card">
      <h2>Judges</h2>
      <form id="judgeForm" class="flex">
        <input id="judgeName" class="input" placeholder="Judge name"/>
        <button class="btn" type="submit">Add Judge</button>
      </form>
      <div id="judgesOut" class="grid-2" style="margin-top:10px;"></div>
    </div>

    <div class="card">
      <a class="btn" href="onsite.html">Go to On-Site Scoring</a>
    </div>
  </div>

  <script src="landing.js"></script>
</body>
</html>
'@
Write-Text (Join-Path $WebRoot 'landing.html') $landing

# ---------------- landing.js (localStorage) ----------------
$landingJs = @'
(function(){
  var LS_TEAMS = "wh_teams";
  var LS_JUDGES = "wh_judges";

  function read(key){ try{ return JSON.parse(localStorage.getItem(key)||"[]"); }catch(_){ return []; } }
  function write(key,val){ localStorage.setItem(key, JSON.stringify(val)); }

  function renderTeams(){
    var out = document.getElementById("teamsOut");
    var teams = read(LS_TEAMS);
    out.innerHTML = teams.map(function(t){
      return '<div class="card" style="padding:10px;"><b>'+escapeHtml(t.name)+'</b><div class="muted">Site '+escapeHtml(t.site)+'</div></div>';
    }).join("") || '<div class="muted">No teams yet.</div>';
  }
  function renderJudges(){
    var out = document.getElementById("judgesOut");
    var judges = read(LS_JUDGES);
    out.innerHTML = judges.map(function(j){
      return '<div class="card" style="padding:10px;">'+escapeHtml(j.name)+'</div>';
    }).join("") || '<div class="muted">No judges yet.</div>';
  }

  function escapeHtml(s){ return String(s||"").replace(/[&<>"']/g, function(c){ return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]); }); }

  document.addEventListener("DOMContentLoaded", function(){
    var fT = document.getElementById("teamForm");
    var fJ = document.getElementById("judgeForm");

    if(fT){
      fT.addEventListener("submit", function(ev){
        ev.preventDefault();
        var name = (document.getElementById("teamName").value||"").trim();
        var site = (document.getElementById("siteNumber").value||"").trim();
        if(!name || !site){ alert("Enter Team name and Site #"); return; }
        var teams = read(LS_TEAMS);
        // prevent dup by name or site
        for(var i=0;i<teams.length;i++){ if(teams[i].name.toLowerCase()===name.toLowerCase() || teams[i].site===site){ alert("Duplicate team name or site #"); return; } }
        teams.push({name:name, site:site});
        write(LS_TEAMS, teams);
        fT.reset();
        renderTeams();
      });
    }

    if(fJ){
      fJ.addEventListener("submit", function(ev){
        ev.preventDefault();
        var name = (document.getElementById("judgeName").value||"").trim();
        if(!name){ alert("Enter Judge name"); return; }
        var judges = read(LS_JUDGES);
        for(var i=0;i<judges.length;i++){ if(judges[i].name.toLowerCase()===name.toLowerCase()){ alert("Duplicate judge"); return; } }
        judges.push({name:name});
        write(LS_JUDGES, judges);
        fJ.reset();
        renderJudges();
      });
    }

    renderTeams();
    renderJudges();
  });
})();
'@
Write-Text (Join-Path $WebRoot 'landing.js') $landingJs

# ---------------- onsite.html ----------------
$onsite = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Whole Hog On-Site Scoring</title>
  <link rel="stylesheet" href="styles.css"/>
</head>
<body>
  <header class="header">
    <img class="left-img" src="pig-rwb-1024.png" alt="Pig"/>
    <h1 class="title">Whole Hog On-Site Scoring</h1>
    <img class="right-img" src="AL Medallion.png" alt="American Legion"/>
  </header>

  <div class="container">
    <div class="card">
      <h2>Teams & Judges</h2>
      <div class="flex">
        <label>Team
          <select id="teamSel" class="input"></select>
        </label>
        <label>Judge
          <select id="judgeSel" class="input"></select>
        </label>
      </div>
      <div class="muted" style="margin-top:6px;">Pick an existing Team and current Judge.</div>
    </div>

    <div class="card">
      <div class="scoring-wrap">
        <div class="scoring-top">
          <span class="badge">All numeric picks open horizontally; choose a value then it collapses.</span>
          <div class="suitable">
            <span>Suitable for public consumption</span>
            <select id="suitableSel">
              <option value="">Select...</option>
              <option value="YES">YES</option>
              <option value="NO">NO</option>
            </select>
          </div>
        </div>

        <div id="miniGrid" class="grid-3" style="margin-top:4px;">
          <!-- mini cards inserted by JS -->
        </div>

        <fieldset class="compl" style="margin-top:6px;">
          <legend>Completeness (8 pts each)</legend>
          <div class="grid">
            <label><input type="checkbox" id="cln"> Site &amp; cooker cleanliness <span class="pts">+8</span></label>
            <label><input type="checkbox" id="knv"> Four sharp knives <span class="pts">+8</span></label>
            <label><input type="checkbox" id="sau"> Four sauce bowls/cups <span class="pts">+8</span></label>
            <label><input type="checkbox" id="drk"> Four drinks &amp; towels <span class="pts">+8</span></label>
            <label><input type="checkbox" id="thr"> Two functioning meat thermometers <span class="pts">+8</span></label>
          </div>
        </fieldset>

        <div class="totalbar">
          <span>Total:</span>
          <span id="totalVal" class="total">0</span>
        </div>

        <div style="display:flex; justify-content:center; margin-top:6px;">
          <button id="saveBtn" class="btn">Save Entry</button>
        </div>
      </div>
    </div>

    <div class="card leader">
      <h2>Leaderboard</h2>
      <div id="leaderWrap"></div>
    </div>

    <div class="card">
      <button id="exportBtn" class="btn secondary">Export CSV</button>
    </div>
  </div>

  <script src="onsite.js"></script>
</body>
</html>
'@
Write-Text (Join-Path $WebRoot 'onsite.html') $onsite

# ---------------- onsite.js (localStorage + tie-breaks + mini pickers) ----------------
$onsiteJs = @'
(function(){
  var LS_TEAMS   = "wh_teams";
  var LS_JUDGES  = "wh_judges";
  var LS_ENTRIES = "wh_entries";

  function read(key){ try{ return JSON.parse(localStorage.getItem(key)||"[]"); }catch(_){ return []; } }
  function write(key,val){ localStorage.setItem(key, JSON.stringify(val)); }

  var APPEAR = even(2,40,2);
  var COLOR  = even(2,40,2);
  var STEP4  = even(4,80,4);

  function even(min,max,step){ var a=[]; for(var v=min; v<=max; v+=step) a.push(v); return a; }

  var state = {
    teamId:"",
    judge:"",
    suitable:"",
    vals: { appearance:null, color:null, skin:null, moisture:null, meat_sauce:null },
    comp: { cln:false, knv:false, sau:false, drk:false, thr:false }
  };

  function id(s){ return document.getElementById(s); }

  function fillSelectors(){
    var teams = read(LS_TEAMS);
    var judges= read(LS_JUDGES);

    var tSel = id("teamSel");
    var jSel = id("judgeSel");
    tSel.innerHTML = '<option value="">Select team…</option>' + teams.map(function(t,ix){
      var label = t.name + " (Site " + t.site + ")";
      // store logical id as "name|site"
      return '<option value="'+escapeAttr(t.name+'|'+t.site)+'">'+escapeHtml(label)+'</option>';
    }).join("");
    jSel.innerHTML = '<option value="">Select judge…</option>' + judges.map(function(j){
      return '<option value="'+escapeAttr(j.name)+'">'+escapeHtml(j.name)+'</option>';
    }).join("");
  }

  function escapeHtml(s){ return String(s||"").replace(/[&<>"']/g,function(c){return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]);}); }
  function escapeAttr(s){ return String(s||"").replace(/"/g,"&quot;"); }

  function buildMiniCards(){
    var cfg = [
      { key:"appearance",  title:"Appearance (2&ndash;40)", options:APPEAR },
      { key:"color",       title:"Color (2&ndash;40)",      options:COLOR  },
      { key:"skin",        title:"Skin (4&ndash;80)",       options:STEP4  },
      { key:"moisture",    title:"Moisture (4&ndash;80)",   options:STEP4  },
      { key:"meat_sauce",  title:"Meat &amp; Sauce (4&ndash;80)", options:STEP4 }
    ];
    var html = cfg.map(function(c){
      var val = state.vals[c.key];
      return [
        '<div class="minicard" data-key="'+c.key+'">',
          '<h4>'+c.title+'</h4>',
          '<div class="picker">',
            '<button type="button" class="pickBtn">'+(val==null?'Choose':val)+'</button>',
            '<div class="panel"><div class="optbar">',
              c.options.map(function(v){ return '<div class="opt" data-val="'+v+'">'+v+'</div>'; }).join(""),
            '</div></div>',
          '</div>',
        '</div>'
      ].join("");
    }).join("");
    id("miniGrid").innerHTML = html;

    // wire pickers
    Array.prototype.slice.call(document.querySelectorAll(".minicard .pickBtn")).forEach(function(btn){
      btn.addEventListener("click", function(){
        var holder = btn.parentNode;
        closeAllPanels();
        holder.classList.add("open");
      });
    });
    Array.prototype.slice.call(document.querySelectorAll(".minicard .opt")).forEach(function(o){
      o.addEventListener("click", function(){
        var mc = o.closest(".minicard");
        var key = mc.getAttribute("data-key");
        var val = parseInt(o.getAttribute("data-val"),10);
        state.vals[key] = val;
        mc.querySelector(".pickBtn").textContent = String(val);
        closeAllPanels();
        recalcTotal();
      });
    });
    document.addEventListener("click", function(ev){
      if(!ev.target.closest(".picker")) closeAllPanels();
    });
  }

  function closeAllPanels(){
    Array.prototype.slice.call(document.querySelectorAll(".picker")).forEach(function(p){
      p.classList.remove("open");
    });
  }

  function recalcTotal(){
    var t = 0;
    var v = state.vals;
    if(v.appearance!=null) t+=v.appearance;
    if(v.color!=null)      t+=v.color;
    if(v.skin!=null)       t+=v.skin;
    if(v.moisture!=null)   t+=v.moisture;
    if(v.meat_sauce!=null) t+=v.meat_sauce;
    var c = state.comp;
    var bonus = (c.cln?8:0)+(c.knv?8:0)+(c.sau?8:0)+(c.drk?8:0)+(c.thr?8:0);
    t += bonus;
    id("totalVal").textContent = String(t);
  }

  function wireCompleteness(){
    [["cln","cln"],["knv","knv"],["sau","sau"],["drk","drk"],["thr","thr"]].forEach(function(pair){
      var cb = id(pair[0]);
      if(cb){
        cb.addEventListener("change", function(){
          state.comp[pair[1]] = !!cb.checked;
          recalcTotal();
        });
      }
    });
  }

  function saveEntry(){
    if(!state.teamId){ alert("Pick a Team"); return; }
    if(!state.judge){ alert("Pick a Judge"); return; }
    if(!state.suitable){ alert("Select Suitable for public consumption"); return; }
    var v = state.vals;
    if(v.appearance==null||v.color==null||v.skin==null||v.moisture==null||v.meat_sauce==null){
      alert("Choose all scoring values"); return;
    }

    var entry = {
      id: guid(),
      ts: Date.now(),
      teamId: state.teamId,  // "name|site"
      judge: state.judge,
      suitable: state.suitable,
      appearance:v.appearance, color:v.color, skin:v.skin, moisture:v.moisture, meat_sauce:v.meat_sauce,
      compl: state.comp
    };
    var arr = read(LS_ENTRIES); arr.push(entry); write(LS_ENTRIES, arr);

    // reset selections (keep team/judge)
    state.suitable=""; id("suitableSel").value="";
    state.vals = { appearance:null,color:null,skin:null,moisture:null,meat_sauce:null };
    state.comp = { cln:false,knv:false,sau:false,drk:false,thr:false };
    buildMiniCards();
    ["cln","knv","sau","drk","thr"].forEach(function(k){ var cb=id(k); if(cb) cb.checked=false; });
    recalcTotal();
    renderLeaderboard();
    alert("Entry saved.");
  }

  function renderLeaderboard(){
    var wrap = document.getElementById("leaderWrap");
    var teams = read(LS_TEAMS);
    var entries = read(LS_ENTRIES);

    // aggregate by teamId (name|site)
    var map = {};
    entries.forEach(function(e){
      var total = e.appearance + e.color + e.skin + e.moisture + e.meat_sauce +
        ((e.compl&&e.compl.cln?8:0)+(e.compl&&e.compl.knv?8:0)+(e.compl&&e.compl.sau?8:0)+(e.compl&&e.compl.drk?8:0)+(e.compl&&e.compl.thr?8:0));
      if(!map[e.teamId]) map[e.teamId] = { total:0, meat:0, skin:0, moist:0, name:"", site:"" };
      map[e.teamId].total += total;
      map[e.teamId].meat  += e.meat_sauce;
      map[e.teamId].skin  += e.skin;
      map[e.teamId].moist += e.moisture;
    });

    // join with team names
    Object.keys(map).forEach(function(k){
      var parts = k.split("|");
      var tn = parts[0]||""; var sn=parts[1]||"";
      map[k].name = tn; map[k].site = sn;
    });

    var rows = Object.keys(map).map(function(k){ var m=map[k]; return { name:m.name, site:m.site, total:m.total, meat:m.meat, skin:m.skin, moist:m.moist }; });

    // tie-breakers: meat_sauce desc, then skin desc, then moisture desc
    rows.sort(function(a,b){
      if(b.total!==a.total) return b.total-a.total;
      if(b.meat!==a.meat)   return b.meat-a.meat;
      if(b.skin!==a.skin)   return b.skin-a.skin;
      return b.moist-a.moist;
    });

    var html = '<table><thead><tr><th>#</th><th>Team</th><th>Site</th><th>Total</th></tr></thead><tbody>'+
      rows.map(function(r,ix){ return '<tr><td>'+(ix+1)+'</td><td>'+escapeHtml(r.name)+'</td><td>'+escapeHtml(r.site)+'</td><td>'+r.total+'</td></tr>'; }).join("")+
      '</tbody></table>';
    wrap.innerHTML = rows.length? html : '<div class="muted">No entries yet.</div>';
  }

  function exportCsv(){
    var entries = read(LS_ENTRIES);
    var head = ["id","ts","team","site","judge","suitable","appearance","color","skin","moisture","meat_sauce","siteClean","knives","sauce","drinks","thermometers","total"];
    var lines = [ head.join(",") ];
    entries.forEach(function(e){
      var parts = (e.teamId||"").split("|"); var tn=parts[0]||"", sn=parts[1]||"";
      var tot = e.appearance + e.color + e.skin + e.moisture + e.meat_sauce +
        ((e.compl&&e.compl.cln?8:0)+(e.compl&&e.compl.knv?8:0)+(e.compl&&e.compl.sau?8:0)+(e.compl&&e.compl.drk?8:0)+(e.compl&&e.compl.thr?8:0));
      var row = [
        e.id, e.ts, csv(tn), csv(sn), csv(e.judge), e.suitable,
        e.appearance, e.color, e.skin, e.moisture, e.meat_sauce,
        e.compl&&e.compl.cln?1:0,
        e.compl&&e.compl.knv?1:0,
        e.compl&&e.compl.sau?1:0,
        e.compl&&e.compl.drk?1:0,
        e.compl&&e.compl.thr?1:0,
        tot
      ];
      lines.push(row.join(","));
    });
    var blob = new Blob([lines.join("\n")], {type:"text/csv;charset=utf-8"});
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "WholeHog-Export.csv";
    document.body.appendChild(a); a.click(); a.remove();
  }
  function csv(s){ s=String(s||""); return '"'+s.replace(/"/g,'""')+'"'; }

  function guid(){ return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g,function(c){ var r=Math.random()*16|0, v=c=="x"?r:(r&0x3|0x8); return v.toString(16); }); }

  document.addEventListener("DOMContentLoaded", function(){
    fillSelectors();
    buildMiniCards();
    wireCompleteness();
    recalcTotal();
    renderLeaderboard();

    id("teamSel").addEventListener("change", function(){ state.teamId = this.value; });
    id("judgeSel").addEventListener("change", function(){ state.judge = this.value; });
    id("suitableSel").addEventListener("change", function(){ state.suitable = this.value; });
    id("saveBtn").addEventListener("click", saveEntry);
    id("exportBtn").addEventListener("click", exportCsv);
  });
})();
'@
Write-Text (Join-Path $WebRoot 'onsite.js') $onsiteJs

Write-Host "`nRollback complete. Open landing.html, add a team/judge, then go to onsite.html (Ctrl+F5 to hard-refresh)." -ForegroundColor Green
