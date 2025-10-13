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