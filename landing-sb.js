(function(){
  "use strict";

  function byId(id){ return document.getElementById(id); }
  function qs(sel, root){ return (root||document).querySelector(sel); }
  function qsa(sel, root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }

  function makeHeaders(){
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
      if(!r.ok) throw new Error("Delete failed: " + r.status);
      return true;
    });
  }

  function findCardByTitleWord(word){
    var cards = qsa(".card");
    for(var i=0;i<cards.length;i++){
      var h2 = qs("h2", cards[i]);
      if(!h2) continue;
      if((h2.textContent||"").toLowerCase().indexOf(word.toLowerCase()) !== -1){
        return cards[i];
      }
    }
    return null;
  }

  // ------- Teams (read-only) -------
  function ensureTeamsListEl(){
    var card = findCardByTitleWord("team");
    if(!card) return null;
    var list = byId("teamsList") || qs("#teamList", card) || qs("#teams-list", card);
    if(!list){
      list = document.createElement("div");
      list.id = "teamsList";
      // place after h2
      var h2 = qs("h2", card);
      if(h2 && h2.parentNode){ h2.parentNode.insertBefore(list, h2.nextSibling); }
      else { card.appendChild(list); }
    }
    return list;
  }
  function renderTeams(rows){
    var cont = ensureTeamsListEl();
    if(!cont) return;
    if(!rows || !rows.length){ cont.innerHTML = '<div class="muted">No teams yet.</div>'; return; }
    var html = '<ul class="simple-list">';
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

  // ------- Judges (list + add + remove) -------
  function ensureJudgesListEl(){
    var card = findCardByTitleWord("judge");
    if(!card) return null;
    var list = byId("judgesList") || qs("#judges-list", card);
    if(!list){
      list = document.createElement("div");
      list.id = "judgesList";
      var h2 = qs("h2", card);
      if(h2 && h2.parentNode){ h2.parentNode.insertBefore(list, h2.nextSibling); }
      else { card.appendChild(list); }
    }
    return list;
  }
  function renderJudges(rows){
    var cont = ensureJudgesListEl();
    if(!cont) return;
    if(!rows || !rows.length){ cont.innerHTML = '<div class="muted">No judges yet.</div>'; return; }
    var html = '<ul class="judge-list">';
    rows.forEach(function(r){
      html += '<li class="judge-row"><span class="name">' + (r.name||"(unnamed)") + '</span> ' +
              '<button type="button" class="btn-remove" data-id="' + r.id + '">Remove</button></li>';
    });
    html += '</ul>';
    cont.innerHTML = html;
  }
  function loadJudges(){
    sbGet("/rest/v1/judges?select=id,name&order=name.asc")
      .then(renderJudges)
      .catch(function(){ /* ignore */ });
  }
  function hookJudgeAdd(){
    var card = findCardByTitleWord("judge");
    if(!card) return;

    // find/create input
    var inp = byId("judgeName") || qs('input[type="text"]', card);
    if(!inp){
      inp = document.createElement("input");
      inp.type = "text";
      inp.id = "judgeName";
      inp.placeholder = "Judge name";
      card.appendChild(inp);
    } else {
      inp.removeAttribute("disabled");
      inp.disabled = false;
      if(!inp.id) inp.id = "judgeName";
    }

    // find/create button
    var btn = byId("btnAddJudge") || qs('button, a', card);
    if(!btn || ((btn.textContent||"").toLowerCase().indexOf("add") === -1)){
      btn = document.createElement("button");
      btn.type = "button";
      btn.id = "btnAddJudge";
      btn.textContent = "Add Judge";
      card.appendChild(btn);
    } else {
      if(!btn.id) btn.id = "btnAddJudge";
    }

    btn.addEventListener("click", function(){
      var name = (inp.value||"").trim();
      if(!name){ alert("Enter judge name"); return; }
      sbPost("/rest/v1/judges", [{ name: name }]).then(function(resp){
        inp.value = "";
        loadJudges();
      }).catch(function(err){
        console.error(err);
        alert("Could not add judge.");
      });
    });
  }
  function hookJudgeRemove(){
    var list = ensureJudgesListEl();
    if(!list) return;
    list.addEventListener("click", function(ev){
      var t = ev.target;
      if(t && t.classList && t.classList.contains("btn-remove")){
        var id = t.getAttribute("data-id");
        if(!id) return;
        if(!confirm("Remove this judge?")) return;
        sbDelete("/rest/v1/judges?id=eq." + encodeURIComponent(id))
          .then(function(){ loadJudges(); })
          .catch(function(e){ console.error(e); alert("Could not remove judge."); });
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function(){
    loadTeams();
    loadJudges();
    hookJudgeAdd();
    hookJudgeRemove();
  });
})();
/* WH JUDGES START */
(function(){
  "use strict";
  function qs(sel,root){ return (root||document).querySelector(sel); }
  function qsa(sel,root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }
  function headers(){
    var key = (window.WHOLEHOG && WHOLEHOG.sbAnonKey) || "";
    return { "apikey": key, "Authorization":"Bearer "+key, "Content-Type":"application/json", "Prefer":"return=representation" };
  }
  function base(){ return (window.WHOLEHOG && WHOLEHOG.sbProjectUrl) || ""; }
  function get(p){ return fetch(base()+p,{method:"GET",headers:headers()}).then(r=>r.json()); }
  function post(p,b){ return fetch(base()+p,{method:"POST",headers:headers(),body:JSON.stringify(b)}).then(r=>r.json()); }
  function del(p){ return fetch(base()+p,{method:"DELETE",headers:headers()}).then(r=>{ if(!r.ok) throw new Error("delete failed"); }); }

  function findJudgesCard(){
    var cards = qsa(".card");
    for(var i=0;i<cards.length;i++){
      var h2 = qs("h2", cards[i]);
      if(!h2) continue;
      if((h2.textContent||"").toLowerCase().indexOf("judge") !== -1) return cards[i];
    }
    return null;
  }
  function ensureInputAndButton(card){
    var inp = document.getElementById("judgeName") || qs('input[type="text"]', card);
    if(!inp){
      inp = document.createElement("input");
      inp.type = "text"; inp.id = "judgeName"; inp.placeholder = "Judge name";
      card.appendChild(inp);
    }
    inp.removeAttribute("disabled"); inp.disabled=false;

    var btn = document.getElementById("btnAddJudge");
    if(!btn){
      btn = document.createElement("button");
      btn.type="button"; btn.id="btnAddJudge"; btn.textContent="Add Judge";
      card.appendChild(btn);
    }
    return {inp:inp, btn:btn};
  }
  function ensureList(card){
    var list = document.getElementById("judgesList");
    if(!list){ list = document.createElement("div"); list.id="judgesList"; card.appendChild(list); }
    return list;
  }
  function renderJudges(rows){
    var list = document.getElementById("judgesList");
    if(!list) return;
    if(!rows || !rows.length){ list.innerHTML = '<div class="muted">No judges yet.</div>'; return; }
    var html = '<ul class="judge-list">';
    rows.forEach(function(r){
      html += '<li class="judge-row"><span class="name">'+(r.name||"(unnamed)")+'</span> '+
              '<button type="button" class="btn-remove" data-id="'+r.id+'">Remove</button></li>';
    });
    html += '</ul>';
    list.innerHTML = html;
  }
  function loadJudges(){
    get('/rest/v1/judges?select=id,name&order=name.asc').then(renderJudges).catch(()=>{});
  }
  function hookRemove(){
    var list = document.getElementById("judgesList");
    if(!list) return;
    list.addEventListener("click", function(ev){
      var t = ev.target;
      if(t && t.classList && t.classList.contains("btn-remove")){
        var id = t.getAttribute("data-id");
        if(!id) return;
        if(!confirm("Remove this judge?")) return;
        del('/rest/v1/judges?id=eq.'+encodeURIComponent(id)).then(loadJudges).catch(()=>alert('Could not remove judge.'));
      }
    });
  }

  document.addEventListener("DOMContentLoaded", function(){
    var card = findJudgesCard();
    if(card){
      var ui = ensureInputAndButton(card);
      ensureList(card);
      ui.btn.addEventListener("click", function(){
        var name = (ui.inp.value||"").trim();
        if(!name){ alert("Enter judge name"); return; }
        post('/rest/v1/judges', [{name:name}]).then(function(){ ui.inp.value=""; loadJudges(); })
          .catch(()=>alert("Could not add judge."));
      });
      hookRemove();
    }
    loadJudges();
  });
})();
/* WH JUDGES END */

/* WH tweak: move judge entry to top */
(function(){
  try {
    var list = document.getElementById('judgesList');
    if(!list) return;
    var card = (list.closest && list.closest('.card')) || list.parentElement;
    if(!card) return;

    // Find header inside card
    var h2 = card.querySelector('h2');
    if(!h2) return;

    // Existing controls
    var input = document.getElementById('judgeName');
    var btn   = document.getElementById('btnAddJudge');

    if(!input && !btn) return;

    // Build a top row for input
    var rowInput = document.createElement('div');
    rowInput.className = 'row judge-entry-top';
    if(input){
      var lbl = document.createElement('label');
      lbl.setAttribute('for','judgeName');
      lbl.textContent = 'Judge Name';
      rowInput.appendChild(lbl);
      rowInput.appendChild(input); // move node
    }

    // Build a row for the Add button (right column)
    var rowBtn = document.createElement('div');
    rowBtn.className = 'row judge-entry-actions';
    var spacer = document.createElement('div');
    spacer.style.width = '160px';
    rowBtn.appendChild(spacer);
    if(btn){ rowBtn.appendChild(btn); } // move node

    // Insert directly after the H2
    if(h2.nextSibling){
      card.insertBefore(rowInput, h2.nextSibling);
      card.insertBefore(rowBtn, rowInput.nextSibling);
    } else {
      card.appendChild(rowInput);
      card.appendChild(rowBtn);
    }
  } catch(e) {
    console.warn('WH judge-entry move failed', e);
  }
})();

