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