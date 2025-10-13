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
  function valInt(id){ var el=byId(id); var v=el?parseInt(el.value||"0",10):0; return isNaN(v)?0:v; }
  function valYN(id){ var el=byId(id); var v=el?String(el.value||"").toUpperCase():""; return v==="YES"?"YES":(v==="NO"?"NO":""); }

  readySupabase(function(sb){

    async function loadTeams(){
      var sel = byId("teamSelect") || findSelectLike("team");
      if(!sel) return;
      sel.innerHTML="";
      var r = await sb.from("teams").select("*").order("name",{ascending:true});
      if(r.error){ console.error(r.error); return; }
      (r.data||[]).forEach(function(t){
        var o=document.createElement("option"); o.value=t.id; o.textContent=t.name+" (Site "+t.site_number+")"; sel.appendChild(o);
      });
      var saved=localStorage.getItem("wh.selectedTeamId");
      if(saved){ for(var i=0;i<sel.options.length;i++){ if(sel.options[i].value===saved){ sel.selectedIndex=i; break; } } }
    }

    async function loadJudges(){
      var sel = byId("judgeSelect") || findSelectLike("judge");
      if(!sel) return;
      sel.innerHTML="";
      var r = await sb.from("judges").select("*").order("name",{ascending:true});
      if(r.error){ console.error(r.error); return; }
      (r.data||[]).forEach(function(j){
        var o=document.createElement("option"); o.value=j.id; o.textContent=j.name; sel.appendChild(o);
      });
      var saved=localStorage.getItem("wh.selectedJudgeId");
      if(saved){ for(var i=0;i<sel.options.length;i++){ if(sel.options[i].value===saved){ sel.selectedIndex=i; break; } } }
    }

    async function saveEntry(){
      var teamSel = byId("teamSelect")  || findSelectLike("team");
      var judgeSel= byId("judgeSelect") || findSelectLike("judge");
      if(!teamSel || teamSel.selectedIndex<0) return alert("Pick a Team");
      if(!judgeSel|| judgeSel.selectedIndex<0) return alert("Pick a Judge");

      var payload = {
        judge_id:  judgeSel.value,
        team_id:   teamSel.value,
        suitable:  valYN("suitable"),
        appearance:valInt("appearance"),
        color:     valInt("color"),
        skin:      valInt("skin"),
        moisture:  valInt("moisture"),
        meat_sauce:valInt("meatSauce"),
        completeness: {
          siteClean:    !!(byId("cln") && byId("cln").checked),
          knives:       !!(byId("knv") && byId("knv").checked),
          sauce:        !!(byId("sau") && byId("sau").checked),
          drinks:       !!(byId("drk") && byId("drk").checked),
          thermometers: !!(byId("thr") && byId("thr").checked)
        }
      };

      var ins = await sb.from("entries").insert([payload]).select().single();
      if(ins.error){
        console.error(ins.error);
        alert("Save failed: " + ins.error.message);
      } else {
        localStorage.setItem("wh.selectedTeamId", teamSel.value);
        localStorage.setItem("wh.selectedJudgeId", judgeSel.value);
        alert("Entry saved.");
      }
    }

    var btn = byId("btnSave");
    if(btn) btn.onclick = saveEntry;

    loadTeams(); loadJudges();
  });
})();