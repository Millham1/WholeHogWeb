(function(){
  function readySupabase(cb){ (function wait(){ if (window.WHOLEHOG && WHOLEHOG.sb) return cb(WHOLEHOG.sb); setTimeout(wait, 120); })(); }
  function byId(id){ return document.getElementById(id); }
  function findSelectLike(keyword){
    keyword = (keyword||"").toLowerCase();
    var all = document.querySelectorAll("select");
    for(var i=0;i<all.length;i++){
      var s = all[i], id=(s.id||"").toLowerCase(), nm=(s.name||"").toLowerCase();
      if(id.indexOf(keyword)>=0 || nm.indexOf(keyword)>=0) return s;
    }
    return null;
  }
  function li(text){ var el=document.createElement("li"); el.textContent=text; return el; }

  readySupabase(function(sb){
    async function loadTeams(){
      var list = byId("teamsList"); if(list) list.innerHTML="";
      var sel = byId("teamSelectLanding") || findSelectLike("team");
      if(sel) sel.innerHTML="";
      var r = await sb.from("teams").select("*").order("name",{ascending:true});
      if(r.error){ console.error(r.error); return; }
      (r.data||[]).forEach(function(t){
        if(list){ list.appendChild(li(t.name+" (Site "+t.site_number+")")); }
        if(sel){ var o=document.createElement("option"); o.value=t.id; o.textContent=t.name+" (Site "+t.site_number+")"; sel.appendChild(o); }
      });
      // reapply selection
      var tid = localStorage.getItem("wh.selectedTeamId");
      if(sel && tid){ for(var i=0;i<sel.options.length;i++){ if(sel.options[i].value===tid){ sel.selectedIndex=i; break; } } }
    }

    async function loadJudges(){
      var list = byId("judgesList"); if(list) list.innerHTML="";
      var sel = byId("judgeSelectLanding") || findSelectLike("judge");
      if(sel) sel.innerHTML="";
      var r = await sb.from("judges").select("*").order("name",{ascending:true});
      if(r.error){ console.error(r.error); return; }
      (r.data||[]).forEach(function(j){
        if(list){ list.appendChild(li(j.name)); }
        if(sel){ var o=document.createElement("option"); o.value=j.id; o.textContent=j.name; sel.appendChild(o); }
      });
      var jid = localStorage.getItem("wh.selectedJudgeId");
      if(sel && jid){ for(var i=0;i<sel.options.length;i++){ if(sel.options[i].value===jid){ sel.selectedIndex=i; break; } } }
    }

    async function addTeam(){
      var nameEl=byId("teamName"), siteEl=byId("siteNumber");
      var name=(nameEl&&nameEl.value||"").trim(), site=(siteEl&&siteEl.value||"").trim();
      if(!name||!site){ alert("Enter Team Name and Site #"); return; }
      var r = await sb.from("teams").insert([{ name:name, site_number:site }]).select().single();
      if(r.error){ alert("Team save failed: "+r.error.message); return; }
      // remember selection even if no dropdown exists
      localStorage.setItem("wh.selectedTeamId", r.data.id);
      localStorage.setItem("wh.selectedTeamText", r.data.name+" (Site "+r.data.site_number+")");
      if(nameEl) nameEl.value=""; if(siteEl) siteEl.value="";
      loadTeams();
    }

    async function addJudge(){
      var jEl=byId("judgeName"); var name=(jEl&&jEl.value||"").trim();
      if(!name){ alert("Enter Judge Name"); return; }
      var r = await sb.from("judges").insert([{ name:name }]).select().single();
      if(r.error){ alert("Judge save failed: "+r.error.message); return; }
      localStorage.setItem("wh.selectedJudgeId", r.data.id);
      localStorage.setItem("wh.selectedJudgeName", r.data.name);
      if(jEl) jEl.value="";
      loadJudges();
    }

    var bt=byId("btnAddTeam");  if(bt) bt.onclick=addTeam;
    var bj=byId("btnAddJudge"); if(bj) bj.onclick=addJudge;

    var teamSel=byId("teamSelectLanding") || findSelectLike("team");
    if(teamSel){ teamSel.onchange=function(){ var o=teamSel.options[teamSel.selectedIndex]; if(!o) return; localStorage.setItem("wh.selectedTeamId",o.value); localStorage.setItem("wh.selectedTeamText",o.textContent||""); }; }
    var judgeSel=byId("judgeSelectLanding") || findSelectLike("judge");
    if(judgeSel){ judgeSel.onchange=function(){ var o=judgeSel.options[judgeSel.selectedIndex]; if(!o) return; localStorage.setItem("wh.selectedJudgeId",o.value); localStorage.setItem("wh.selectedJudgeName",o.textContent||""); }; }

    var go=byId("gotoOnsite"); if(go){ go.onclick=function(){ window.location.href="onsite.html"; }; }

    loadTeams(); loadJudges();
  });
})();