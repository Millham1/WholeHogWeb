# wire-pages-supabase.ps1  — PowerShell 5.1 safe
param(
  [string]$WebRoot    = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb",
  [string]$ProjectUrl = "https://wiolulxxfyetvdpnfusq.supabase.co",
  [string]$AnonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ensure-Dir([string]$p){
  $d = Split-Path $p -Parent
  if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}
function Read-Text([string]$Path){
  if (-not (Test-Path $Path)) { return $null }
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path, [string]$Content){
  Ensure-Dir $Path
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}
function Inject-Scripts {
  param(
    [string]$HtmlPath,
    [string[]]$ScriptFilesInOrder
  )
  if (-not (Test-Path $HtmlPath)) { return $false }
  $html = Read-Text $HtmlPath
  if (-not $html) { return $false }

  foreach($sf in $ScriptFilesInOrder){
    $pattern = '(?is)\s*<script[^>]*src=["'']' + [System.Text.RegularExpressions.Regex]::Escape($sf) + '["''][^>]*>\s*</script>\s*'
    $html = [System.Text.RegularExpressions.Regex]::Replace($html, $pattern, '')
  }

  $inj = ""
  foreach($sf in $ScriptFilesInOrder){ $inj += '  <script src="' + $sf + '"></script>' + [Environment]::NewLine }

  $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor `
          [System.Text.RegularExpressions.RegexOptions]::Singleline
  $rx = New-Object System.Text.RegularExpressions.Regex('</body>', $opts)

  if ($rx.IsMatch($html)) {
    $html = $rx.Replace($html, ($inj + '</body>'), 1)
  } else {
    $html += [Environment]::NewLine + $inj
  }

  Write-Text -Path $HtmlPath -Content $html
  return $true
}

# ---------- Write JS files (ASCII only; placeholders replaced) ----------

# supabase-config.js
$cfgTpl = @'
(function(){
  window.WHOLEHOG = window.WHOLEHOG || {};
  window.WHOLEHOG.sbProjectUrl = "__URL__";
  window.WHOLEHOG.sbAnonKey    = "__KEY__";

  function sbHeaders(){
    return {
      "apikey": window.WHOLEHOG.sbAnonKey,
      "Authorization": "Bearer " + window.WHOLEHOG.sbAnonKey,
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    };
  }
  window.WHOLEHOG.sb = {
    get:  function(path){ return fetch(window.WHOLEHOG.sbProjectUrl + path, { method:"GET",  headers: sbHeaders() }); },
    post: function(path, body){ return fetch(window.WHOLEHOG.sbProjectUrl + path, { method:"POST", headers: sbHeaders(), body: JSON.stringify(body) }); }
  };
})();
'@
$cfg = $cfgTpl.Replace('__URL__', $ProjectUrl).Replace('__KEY__', $AnonKey)
Write-Text (Join-Path $WebRoot 'supabase-config.js') $cfg

# landing-sb.js
$landingJs = @'
(function(){
  function el(id){ return document.getElementById(id); }

  function loadTeams(){
    var cont = el("teamsList") || el("teamList") || el("teams-list");
    if(!cont) return;
    WHOLEHOG.sb.get("/rest/v1/teams?select=name,site_number&order=site_number.asc")
      .then(function(r){ return r.json(); })
      .then(function(rows){
        var out = rows.map(function(t){
          var n = t && t.name ? t.name : "";
          var s = t && t.site_number ? t.site_number : "";
          return "<div class=\"row\"><b>" + n + "</b> — Site " + s + "</div>";
        }).join("");
        cont.innerHTML = out || "<div class=\"row muted\">No teams yet.</div>";
      }).catch(function(){});
  }

  function loadJudges(){
    var cont = el("judgesList") || el("judgeList") || el("judges-list");
    if(!cont) return;
    WHOLEHOG.sb.get("/rest/v1/judges?select=name&order=name.asc")
      .then(function(r){ return r.json(); })
      .then(function(rows){
        var out = rows.map(function(j){
          var n = j && j.name ? j.name : "";
          return "<div class=\"row\">" + n + "</div>";
        }).join("");
        cont.innerHTML = out || "<div class=\"row muted\">No judges yet.</div>";
      }).catch(function(){});
  }

  function bindTeamForm(){
    var f = el("teamForm") || document.querySelector("form#team-form");
    if(!f) return;
    var name = el("teamName") || f.querySelector("input[name=teamName]");
    var site = el("siteNumber") || f.querySelector("input[name=siteNumber]");
    if(!name || !site) return;

    f.addEventListener("submit", function(ev){
      ev.preventDefault();
      var n = (name.value||"").trim();
      var s = (site.value||"").trim();
      if(!n || !s){ alert("Enter Team Name and Site #"); return; }
      WHOLEHOG.sb.post("/rest/v1/teams", [{ name:n, site_number:s }])
        .then(function(r){ if(!r.ok) return r.text().then(function(t){ throw new Error(t); }); return r.json(); })
        .then(function(){ name.value=""; site.value=""; loadTeams(); })
        .catch(function(e){ alert("Save team failed:\n" + e.message); });
    });
  }

  function bindJudgeForm(){
    var f = el("judgeForm") || document.querySelector("form#judge-form");
    if(!f) return;
    var name = el("judgeName") || f.querySelector("input[name=judgeName]");
    if(!name) return;

    f.addEventListener("submit", function(ev){
      ev.preventDefault();
      var n = (name.value||"").trim();
      if(!n){ alert("Enter Judge Name"); return; }
      WHOLEHOG.sb.post("/rest/v1/judges", [{ name:n }])
        .then(function(r){ if(!r.ok) return r.text().then(function(t){ throw new Error(t); }); return r.json(); })
        .then(function(){ name.value=""; loadJudges(); })
        .catch(function(e){ alert("Save judge failed:\n" + e.message); });
    });
  }

  document.addEventListener("DOMContentLoaded", function(){
    loadTeams();
    loadJudges();
    bindTeamForm();
    bindJudgeForm();
  });
})();
'@
Write-Text (Join-Path $WebRoot 'landing-sb.js') $landingJs

# onsite-sb.js
$onsiteJs = @'
(function(){
  function el(id){ return document.getElementById(id); }
  function pick(ids){ for(var i=0;i<ids.length;i++){ var n=el(ids[i]); if(n) return n; } return null; }
  function valNum(id){ var n=el(id); if(!n) return null; var v=(n.value||"").trim(); return v?parseInt(v,10):null; }

  function loadTeamsInto(select){
    if(!select) return;
    WHOLEHOG.sb.get("/rest/v1/teams?select=id,name,site_number&order=site_number.asc")
      .then(function(r){ return r.json(); })
      .then(function(rows){
        select.innerHTML = "<option value=\"\">(Select team)</option>" +
          rows.map(function(t){
            var id = t && t.id ? t.id : "";
            var n  = t && t.name ? t.name : "";
            var s  = t && t.site_number ? t.site_number : "";
            return "<option value=\""+id+"\">"+n+" (Site "+s+")</option>";
          }).join("");
      }).catch(function(){});
  }

  function loadJudgesInto(select){
    if(!select) return;
    WHOLEHOG.sb.get("/rest/v1/judges?select=id,name&order=name.asc")
      .then(function(r){ return r.json(); })
      .then(function(rows){
        select.innerHTML = "<option value=\"\">(Select judge)</option>" +
          rows.map(function(j){
            var id = j && j.id ? j.id : "";
            var n  = j && j.name ? j.name : "";
            return "<option value=\""+id+"\">"+n+"</option>";
          }).join("");
      }).catch(function(){});
  }

  function refreshLeaderboard(){
    var body = el("leaderboardBody") || el("leaderboard-body") || document.querySelector("#leaderboard tbody");
    if(!body) return;
    WHOLEHOG.sb.get("/rest/v1/v_leaderboard?select=team_name,site_number,total_points,tie_meat_sauce,tie_skin,tie_moisture&order=total_points.desc,tie_meat_sauce.desc,tie_skin.desc,tie_moisture.desc")
      .then(function(r){ return r.json(); })
      .then(function(rows){
        var out = rows.map(function(x,idx){
          var tn = x && x.team_name ? x.team_name : "";
          var sn = x && x.site_number ? x.site_number : "";
          var tp = x && x.total_points ? x.total_points : 0;
          return "<tr><td>"+(idx+1)+"</td><td>"+tn+"</td><td>"+sn+"</td><td>"+tp+"</td></tr>";
        }).join("");
        body.innerHTML = out || "<tr><td colspan=\"4\">No entries yet</td></tr>";
      }).catch(function(){});
  }

  function bindSave(){
    var btn = el("saveEntry") || el("btnSave") || document.querySelector("button.save");
    if(!btn) return;
    btn.addEventListener("click", function(){
      var teamSel  = pick(["teamSelect","team","teamId"]);
      var judgeSel = pick(["judgeSelect","judge","judgeId"]);
      if(!teamSel || !judgeSel){ alert("Team/Judge dropdowns were not found."); return; }
      var teamId  = (teamSel.value||"").trim();
      var judgeId = (judgeSel.value||"").trim();
      if(!teamId){ alert("Please select a team."); return; }
      if(!judgeId){ alert("Please select a judge."); return; }

      var suitable   = (pick(["suitable","suitableSelect"]) || {value:""}).value || "";
      var appearance = valNum("appearance");
      var color      = valNum("color");
      var skin       = valNum("skin");
      var moisture   = valNum("moisture");
      var meatSauce  = valNum("meatSauce");
      if(appearance===null||color===null||skin===null||moisture===null||meatSauce===null){ alert("Please choose all scoring values."); return; }
      if(!suitable){ alert("Select Suitable for Public Consumption."); return; }

      function cb(id){ var n=el(id); return !!(n && n.checked); }
      var completeness = {
        siteClean:    cb("cln") || cb("siteClean"),
        knives:       cb("knv") || cb("knives"),
        sauce:        cb("sau") || cb("sauce"),
        drinks:       cb("drk") || cb("drinks"),
        thermometers: cb("thm") || cb("thermometers")
      };

      var body = [{
        team_id:    teamId,
        judge_id:   judgeId,
        suitable:   suitable,
        appearance: appearance,
        color:      color,
        skin:       skin,
        moisture:   moisture,
        meat_sauce: meatSauce,
        completeness: completeness
      }];

      WHOLEHOG.sb.post("/rest/v1/entries", body)
        .then(function(r){ if(!r.ok) return r.text().then(function(t){ throw new Error(t); }); return r.json(); })
        .then(function(){ refreshLeaderboard(); alert("Entry saved."); })
        .catch(function(e){ alert("Save failed:\n" + e.message); });
    });
  }

  document.addEventListener("DOMContentLoaded", function(){
    loadTeamsInto( document.getElementById("teamSelect")  || document.querySelector("select#team")  );
    loadJudgesInto(document.getElementById("judgeSelect") || document.querySelector("select#judge") );
    bindSave();
    refreshLeaderboard();
  });
})();
'@
Write-Text (Join-Path $WebRoot 'onsite-sb.js') $onsiteJs

# ---------- Inject into pages ----------
$LandingHtml = Join-Path $WebRoot 'landing.html'
$OnsiteHtml  = Join-Path $WebRoot 'onsite.html'

$didL = $false
$didO = $false

if (Test-Path $LandingHtml) {
  $didL = Inject-Scripts -HtmlPath $LandingHtml -ScriptFilesInOrder @('supabase-config.js','landing-sb.js')
  if ($didL) { Write-Host "Wired: $LandingHtml" -ForegroundColor Green }
} else {
  Write-Host "WARNING: landing.html not found at $LandingHtml" -ForegroundColor Yellow
}
if (Test-Path $OnsiteHtml) {
  $didO = Inject-Scripts -HtmlPath $OnsiteHtml -ScriptFilesInOrder @('supabase-config.js','onsite-sb.js')
  if ($didO) { Write-Host "Wired: $OnsiteHtml" -ForegroundColor Green }
} else {
  Write-Host "WARNING: onsite.html not found at $OnsiteHtml" -ForegroundColor Yellow
}

if (-not ($didL -or $didO)) {
  Write-Host ""
  Write-Host "Nothing was wired. Check WebRoot and that landing.html / onsite.html exist." -ForegroundColor Yellow
} else {
  Write-Host ""
  Write-Host "Done. Hard-refresh both pages (Ctrl+F5)." -ForegroundColor Cyan
}

