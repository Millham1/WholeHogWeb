(function(){
  "use strict";

  function byId(id){ return document.getElementById(id); }
  function pickId(ids){
    for(var i=0;i<ids.length;i++){ var el = byId(ids[i]); if(el) return el; }
    return null;
  }
  function makeHeaders(){
    // requires supabase-config.js which defines WHOLEHOG.sbProjectUrl / sbAnonKey (and WHOLEHOG.sb helpers)
    return {
      "apikey": (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || "",
      "Authorization": "Bearer " + ((window.WHOLEHOG && WHOLEHOG.sbAnonKey) || ""),
      "Content-Type": "application/json",
      "Prefer": "return=representation"
    };
  }
  function apiUrl(path){
    var root = (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) || "";
    return root + path;
  }
  function sbGet(path){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.get){
      return WHOLEHOG.sb.get(path).then(function(r){ return r.json(); });
    }
    return fetch(apiUrl(path), { method:"GET", headers: makeHeaders() }).then(function(r){ return r.json(); });
  }
  function sbPost(path, body){
    if(window.WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.post){
      return WHOLEHOG.sb.post(path, body).then(function(r){ return r.json(); });
    }
    return fetch(apiUrl(path), { method:"POST", headers: makeHeaders(), body: JSON.stringify(body) }).then(function(r){ return r.json(); });
  }
  function sbDelete(path){
    return fetch(apiUrl(path), { method:"DELETE", headers: makeHeaders() }).then(function(r){
      // PostgREST often returns empty body for DELETE; treat 2xx as OK
      if(!r.ok) throw new Error("Delete failed: " + r.status);
      return true;
    });
  }

  // ------- TEAMS (read-only list) -------
  function renderTeams(rows){
    var cont = pickId(["teamsList","teamList","teams-list"]);
    if(!cont) return;
    if(!rows || !rows.length){ cont.innerHTML = "<div class=\"muted\">No teams yet.</div>"; return; }
    var html = "<ul class=\"simple-list\">";
    rows.forEach(function(r){
      var label = r.name + (r.site_number ? " (Site " + r.site_number + ")" : "");
      html += "<li>" + label + "</li>";
    });
    html += "</ul>";
    cont.innerHTML = html;
  }
  function loadTeams(){
    sbGet("/rest/v1/teams?select=id,name,site_number&order=site_number.asc,name.asc")
      .then(renderTeams)
      .catch(function(){ /* ignore */ });
  }

  // ------- JUDGES (list + add + remove) -------
  function renderJudges(rows){
    var cont = pickId(["judgesList","judgeList","judges-list"]);
    if(!cont) return;
    if(!rows || !rows.length){ cont.innerHTML = "<div class=\"muted\">No judges yet.</div>"; return; }
    var html = "<ul class=\"judge-list\">";
    rows.forEach(function(r){
      html += "<li class=\"judge-row\"><span class=\"name\">" + (r.name||"(unnamed)") + "</span> " +
              "<button type=\"button\" class=\"btn-remove\" data-id=\"" + r.id + "\">Remove</button></li>";
    });
    html += "</ul>";
    cont.innerHTML = html;
  }
  function loadJudges(){
    sbGet("/rest/v1/judges?select=id,name&order=name.asc")
      .then(renderJudges)
      .catch(function(){ /* ignore */ });
  }
  function hookJudgeAdd(){
    var input = pickId(["judgeName","judge-name","inputJudge"]);
    var btn   = pickId(["btnAddJudge","addJudgeBtn","add-judge"]);
    if(!btn || !input) return;
    // ensure enabled
    input.removeAttribute("disabled");
    input.disabled = false;

    btn.addEventListener("click", function(){
      var name = (input.value||"").trim();
      if(!name){ alert("Enter judge name"); return; }
      sbPost("/rest/v1/judges", [{ name: name }]).then(function(){
        input.value = "";
        loadJudges();
      }).catch(function(err){
        console.error(err);
        alert("Could not add judge.");
      });
    });
  }
  function hookJudgeRemove(){
    var cont = pickId(["judgesList","judgeList","judges-list"]);
    if(!cont) return;
    cont.addEventListener("click", function(ev){
      var t = ev.target;
      if(t && t.classList && t.classList.contains("btn-remove")){
        var id = t.getAttribute("data-id");
        if(!id) return;
        if(!confirm("Remove this judge?")) return;
        sbDelete("/rest/v1/judges?id=eq." + encodeURIComponent(id))
          .then(function(){ loadJudges(); })
          .catch(function(err){ console.error(err); alert("Could not remove judge."); });
      }
    });
  }

  // Init
  document.addEventListener("DOMContentLoaded", function(){
    loadTeams();
    loadJudges();
    hookJudgeAdd();
    hookJudgeRemove();
  });
})();