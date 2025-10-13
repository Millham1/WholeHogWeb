(function(){
  // tiny helpers
  function q(sel,root){ return (root||document).querySelector(sel); }
  function qq(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }

  // Create or get an output container right after a node
  function ensureOutput(afterNode, id){
    var out = document.getElementById(id);
    if(!out){
      out = document.createElement("div");
      out.id = id;
      out.className = "wh-list";
      if(afterNode && afterNode.parentNode){
        afterNode.parentNode.insertBefore(out, afterNode.nextSibling);
      } else {
        document.body.appendChild(out);
      }
    }
    return out;
  }

  // Try hard to find the Team form + inputs without depending on exact IDs
  function findTeamBits(){
    // Prefer explicit ids if you have them
    var form = document.getElementById("teamForm") || q("form#team-form");
    if(!form){
      // fallback: first form that has both team & site inputs
      var forms = qq("form");
      for(var i=0;i<forms.length;i++){
        var f=forms[i];
        var ti = q("input[id*=team i],input[name*=team i],input[placeholder*=team i]", f);
        var si = q("input[id*=site i],input[name*=site i],input[placeholder*=site i]", f);
        if(ti && si){ form = f; break; }
      }
    }
    var team = (form && ( q("#teamName",form) || q("input[name=teamName]",form) )) ||
               (form && q("input[id*=team i],input[name*=team i],input[placeholder*=team i]",form));

    var site = (form && ( q("#siteNumber",form) || q("input[name=siteNumber]",form) )) ||
               (form && q("input[id*=site i],input[name*=site i],input[placeholder*=site i]",form));

    return { form: form, team: team, site: site };
  }

  // Judges form + input
  function findJudgeBits(){
    var form = document.getElementById("judgeForm") || q("form#judge-form");
    if(!form){
      var forms = qq("form");
      for(var i=0;i<forms.length;i++){
        var f=forms[i];
        var jn = q("input[id*=judge i],input[name*=judge i],input[placeholder*=judge i]", f);
        if(jn){ form = f; break; }
      }
    }
    var name = (form && ( q("#judgeName",form) || q("input[name=judgeName]",form) )) ||
               (form && q("input[id*=judge i],input[name*=judge i],input[placeholder*=judge i]",form));
    return { form: form, name: name };
  }

  // Render teams into a dedicated output container (never touch your form markup)
  function loadTeams(){
    var bits = findTeamBits();
    if(!bits.form) return;
    var out = ensureOutput(bits.form, "wh-teams-output");

    WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.get("/rest/v1/teams?select=name,site_number&order=site_number.asc")
      .then(function(r){ return r.json(); })
      .then(function(rows){
        var html = (rows||[]).map(function(t){
          var n = t && t.name ? t.name : "";
          var s = t && t.site_number ? t.site_number : "";
          return '<div class="row"><b>'+n+'</b> â€” Site '+s+'</div>';
        }).join("");
        out.innerHTML = html || '<div class="row muted">No teams yet.</div>';
      })
      .catch(function(){ /* keep silent */ });
  }

  // Render judges into a dedicated output container
  function loadJudges(){
    var bits = findJudgeBits();
    if(!bits.form) return;
    var out = ensureOutput(bits.form, "wh-judges-output");

    WHOLEHOG && WHOLEHOG.sb && WHOLEHOG.sb.get("/rest/v1/judges?select=name&order=name.asc")
      .then(function(r){ return r.json(); })
      .then(function(rows){
        var html = (rows||[]).map(function(j){
          var n = j && j.name ? j.name : "";
          return '<div class="row">'+n+'</div>';
        }).join("");
        out.innerHTML = html || '<div class="row muted">No judges yet.</div>';
      })
      .catch(function(){});
  }

  function bindTeamForm(){
    var bits = findTeamBits();
    if(!bits.form || !bits.team || !bits.site) return;

    // Ensure we bind only once
    if(bits.form.__whBound) return;
    bits.form.__whBound = true;

    bits.form.addEventListener("submit", function(ev){
      ev.preventDefault();
      var n = (bits.team.value||"").trim();
      var s = (bits.site.value||"").trim();
      if(!n || !s){ alert("Enter Team Name and Site #"); return; }
      WHOLEHOG.sb.post("/rest/v1/teams", [{ name:n, site_number:s }])
        .then(function(r){ if(!r.ok) return r.text().then(function(t){ throw new Error(t); }); return r.json(); })
        .then(function(){ bits.form.reset(); loadTeams(); })
        .catch(function(e){ alert("Save team failed:\n"+ e.message); });
    });
  }

  function bindJudgeForm(){
    var bits = findJudgeBits();
    if(!bits.form || !bits.name) return;
    if(bits.form.__whBound) return;
    bits.form.__whBound = true;

    bits.form.addEventListener("submit", function(ev){
      ev.preventDefault();
      var n = (bits.name.value||"").trim();
      if(!n){ alert("Enter Judge Name"); return; }
      WHOLEHOG.sb.post("/rest/v1/judges", [{ name:n }])
        .then(function(r){ if(!r.ok) return r.text().then(function(t){ throw new Error(t); }); return r.json(); })
        .then(function(){ bits.form.reset(); loadJudges(); })
        .catch(function(e){ alert("Save judge failed:\n"+ e.message); });
    });
  }

  document.addEventListener("DOMContentLoaded", function(){
    try{
      bindTeamForm();
      bindJudgeForm();
      loadTeams();
      loadJudges();
    }catch(_){}
  });
})();