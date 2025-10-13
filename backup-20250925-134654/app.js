/* WholeHog web app logic (no bundlers) */

(function(){
  var COMPLETENESS_POINTS = 8;

  var CATS = [
    { key: "appearance", label: "Appearance (2–40)", min: 2,  max: 40, step: 2 },
    { key: "color",      label: "Color (2–40)",      min: 2,  max: 40, step: 2 },
    { key: "skin",       label: "Skin Crispness (4–80)", min: 4,  max: 80, step: 4 },
    { key: "moisture",   label: "Moisture (4–80)",   min: 4,  max: 80, step: 4 },
    { key: "meatSauce",  label: "Meat & Sauce Taste (4–80)", min: 4,  max: 80, step: 4 }
  ];

  var state = {
    team: "", judge: "", suitable: "",
    scores: { appearance:null, color:null, skin:null, moisture:null, meatSauce:null },
    compl:  { cln:false, knv:false, sau:false, drk:false, thr:false },
    total: 0
  };

  function range(min,max,step){
    var out=[], v=min; for(; v<=max; v+=step) out.push(v); return out;
  }

  function loadList(key, fallback){
    try{
      var v = JSON.parse(localStorage.getItem(key)||"null");
      if(Array.isArray(v) && v.length) return v;
    }catch(e){}
    return fallback;
  }
  var TEAMS  = loadList("teams",  ["Team Alpha","Team Bravo","Team Charlie"]);
  var JUDGES = loadList("judges", ["Judge 1","Judge 2","Judge 3"]);

  function byId(id){ return document.getElementById(id) }

  function buildScoreCards(){
    var grid = byId("scoresGrid");
    grid.innerHTML = "";
    CATS.forEach(function(cat){
      var card = document.createElement("div");
      card.className = "score-card";
      card.setAttribute("data-key", cat.key);

      var h3 = document.createElement("h3");
      h3.textContent = cat.label;

      var disp = document.createElement("div");
      disp.className = "score-display";
      disp.id = "score-" + cat.key;
      disp.textContent = "—";

      var toggleRow = document.createElement("div");
      toggleRow.className = "toggle-row";
      var toggleBtn = document.createElement("button");
      toggleBtn.type = "button";
      toggleBtn.className = "toggle";
      toggleBtn.textContent = "Choose";
      toggleRow.appendChild(toggleBtn);

      var opts = document.createElement("div");
      opts.className = "options-row";
      opts.id = "opts-" + cat.key;
      range(cat.min,cat.max,cat.step).forEach(function(v){
        var o = document.createElement("button");
        o.type="button";
        o.className = "opt";
        o.textContent = String(v);
        o.setAttribute("data-val", String(v));
        o.addEventListener("click", function(){
          state.scores[cat.key] = v;
          disp.textContent = String(v);
          // highlight selected
          Array.prototype.forEach.call(opts.querySelectorAll(".opt"), function(b){ b.classList.remove("selected"); });
          o.classList.add("selected");
          opts.classList.remove("open");
          recomputeTotal();
        });
        opts.appendChild(o);
      });

      toggleBtn.addEventListener("click", function(){
        opts.classList.toggle("open");
      });

      card.appendChild(h3);
      card.appendChild(disp);
      card.appendChild(toggleRow);
      card.appendChild(opts);
      grid.appendChild(card);
    });
  }

  function populateSelectors(){
    var tsel = byId("selTeam");
    var jsel = byId("selJudge");
    tsel.innerHTML = '<option value="">Select team…</option>';
    jsel.innerHTML = '<option value="">Select judge…</option>';
    TEAMS.forEach(function(t){ var o=document.createElement("option"); o.value=t; o.textContent=t; tsel.appendChild(o); });
    JUDGES.forEach(function(j){ var o=document.createElement("option"); o.value=j; o.textContent=j; jsel.appendChild(o); });

    tsel.addEventListener("change", function(){ state.team = tsel.value; });
    jsel.addEventListener("change", function(){ state.judge = jsel.value; });
  }

  function completenessListeners(){
    [["cln","cln"],["knv","knv"],["sau","sau"],["drk","drk"],["thr","thr"]].forEach(function(pair){
      var id = pair[0];
      var key= pair[1];
      var el = byId(id);
      if(el){ el.addEventListener("change", function(){
        state.compl[key] = !!el.checked;
        recomputeTotal();
      });}
    });
    var suitable = byId("suitable");
    suitable.addEventListener("change", function(){ state.suitable = suitable.value; });
  }

  function computeTotals(entry){
    var s = entry.scores || {};
    var base =
      (s.appearance|0) + (s.color|0) + (s.skin|0) + (s.moisture|0) + (s.meatSauce|0);
    var c = entry.compl || {};
    var checked = (c.cln?1:0) + (c.knv?1:0) + (c.sau?1:0) + (c.drk?1:0) + (c.thr?1:0);
    return base + checked * COMPLETENESS_POINTS;
  }

  function recomputeTotal(){
    var t = computeTotals(state);
    state.total = t;
    byId("totalScore").textContent = String(t);
  }

  function saveEntry(){
    // basic validation
    if(!state.team){ alert("Select a team."); return; }
    if(!state.judge){ alert("Select a judge."); return; }
    if(!state.suitable){ alert('Select "Suitable for public consumption".'); return; }
    var missing = CATS.filter(function(c){ return !state.scores[c.key] });
    if(missing.length){ alert("Pick all scoring values."); return; }

    var entry = {
      id: String(Date.now()) + "_" + Math.random().toString(36).slice(2),
      ts: Date.now(),
      team: state.team,
      judge: state.judge,
      suitable: state.suitable,
      scores: Object.assign({}, state.scores),
      compl:  Object.assign({}, state.compl),
      total:  computeTotals(state)
    };

    var list = [];
    try{ list = JSON.parse(localStorage.getItem("entries")||"[]") }catch(e){}
    list.push(entry);
    localStorage.setItem("entries", JSON.stringify(list));

    // refresh LB
    updateLeaderboard();

    // clear scores for next entry but keep team/judge/suitable
    state.scores = { appearance:null, color:null, skin:null, moisture:null, meatSauce:null };
    ["appearance","color","skin","moisture","meatSauce"].forEach(function(k){
      var d = byId("score-"+k); if(d) d.textContent = "—";
      var row = byId("opts-"+k); if(row) Array.prototype.forEach.call(row.querySelectorAll(".opt"), function(b){ b.classList.remove("selected"); });
    });
    state.compl = { cln:false, knv:false, sau:false, drk:false, thr:false };
    ["cln","knv","sau","drk","thr"].forEach(function(id){ var e=byId(id); if(e) e.checked=false; });
    recomputeTotal();
  }

  // Build leaderboard by team: sum totals; tie-breaks by best MeatSauce, then Skin, then Moisture
  function updateLeaderboard(){
    var list = [];
    try{ list = JSON.parse(localStorage.getItem("entries")||"[]") }catch(e){}
    var byTeam = {};
    list.forEach(function(e){
      var t = e.team;
      if(!byTeam[t]) byTeam[t] = { team:t, total:0, meatBest:0, skinBest:0, moistBest:0 };
      byTeam[t].total += (e.total|0);
      byTeam[t].meatBest = Math.max(byTeam[t].meatBest, (e.scores && e.scores.meatSauce|0) || 0);
      byTeam[t].skinBest = Math.max(byTeam[t].skinBest, (e.scores && e.scores.skin|0) || 0);
      byTeam[t].moistBest= Math.max(byTeam[t].moistBest,(e.scores && e.scores.moisture|0) || 0);
    });
    var rows = Object.keys(byTeam).map(function(k){ return byTeam[k]; });
    rows.sort(function(a,b){
      if(b.total!==a.total) return b.total-a.total;
      if(b.meatBest!==a.meatBest) return b.meatBest-a.meatBest;
      if(b.skinBest!==a.skinBest) return b.skinBest-a.skinBest;
      return b.moistBest-a.moistBest;
    });

    var tb = byId("lbTable").querySelector("tbody");
    tb.innerHTML = "";
    rows.forEach(function(r,idx){
      var tr = document.createElement("tr");
      tr.innerHTML = "<td>"+(idx+1)+"</td><td>"+r.team+"</td><td>"+r.total+"</td>";
      tb.appendChild(tr);
    });
  }
  window.updateLeaderboard = updateLeaderboard; // (exposed for safety)

  function exportCsv(){
    var list = [];
    try{ list = JSON.parse(localStorage.getItem("entries")||"[]") }catch(e){}
    var headers = ["id","ts","team","judge","suitable","appearance","color","skin","moisture","meatSauce","cln","knv","sau","drk","thr","total"];
    var lines = [headers.join(",")];
    list.forEach(function(e){
      var s=e.scores||{}, c=e.compl||{};
      var row = [
        e.id, e.ts, e.team, e.judge, e.suitable,
        s.appearance||0, s.color||0, s.skin||0, s.moisture||0, s.meatSauce||0,
        c.cln?1:0, c.knv?1:0, c.sau?1:0, c.drk?1:0, c.thr?1:0,
        e.total||0
      ].map(function(v){
        var t = (v==null?"":String(v)); return '"'+t.replace(/"/g,'""')+'"';
      });
      lines.push(row.join(","));
    });
    var blob = new Blob([lines.join("\r\n")], {type:"text/csv;charset=utf-8"});
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "WholeHog-Export.csv";
    a.click();
    setTimeout(function(){ URL.revokeObjectURL(a.href); }, 1000);
  }

  document.addEventListener("DOMContentLoaded", function(){
    populateSelectors();
    buildScoreCards();
    completenessListeners();
    recomputeTotal();
    updateLeaderboard();

    var saveBtn = document.getElementById("saveEntry");
    if(saveBtn) saveBtn.addEventListener("click", saveEntry);

    var ex = document.getElementById("exportCsv");
    if(ex) ex.addEventListener("click", exportCsv);
  });
})();
/* === WHOLEHOG PICKER PATCH START === */
(function(){
  function buildOptions(el){
    var step   = parseInt(el.getAttribute("data-step"),10);
    var min    = parseInt(el.getAttribute("data-min"),10);
    var max    = parseInt(el.getAttribute("data-max"),10);
    var metric = el.getAttribute("data-metric");

    var btn  = el.querySelector('.picker');
    var pane = el.querySelector('.options');
    var out  = el.querySelector('.value');

    var vals = [];
    for(var v=min; v<=max; v+=step){ vals.push(v); }

    pane.innerHTML = '';
    vals.forEach(function(v){
      var o = document.createElement('button');
      o.type = 'button';
      o.className = 'opt';
      o.textContent = String(v);
      o.addEventListener('click', function(){
        out.textContent = String(v);
        btn.textContent = String(v);
        pane.classList.remove('open');
        recalcTotal();
      });
      pane.appendChild(o);
    });

    btn.addEventListener('click', function(e){
      e.stopPropagation();
      Array.prototype.forEach.call(document.querySelectorAll('.options.open'), function(x){ x.classList.remove('open'); });
      pane.classList.toggle('open');
    });
  }

  function getMetricValue(id){
    var t = document.getElementById('val-' + id);
    var n = parseInt((t && t.textContent || '').replace(/\D+/g,''), 10);
    return isNaN(n) ? 0 : n;
  }

  function recalcTotal(){
    var a  = getMetricValue('appearance');
    var c  = getMetricValue('color');
    var s  = getMetricValue('skin');
    var m  = getMetricValue('moisture');
    var ms = getMetricValue('meatsauce');

    var comp = 0;
    Array.prototype.forEach.call(document.querySelectorAll('.completeness .cmp:checked'), function(ch){
      var v = parseInt(ch.value,10) || 0; comp += v;
    });

    var total = a + c + s + m + ms + comp;
    var node = document.getElementById('totalScore');
    if (node) node.textContent = String(total);
  }

  document.addEventListener('click', function(){
    Array.prototype.forEach.call(document.querySelectorAll('.options.open'), function(x){ x.classList.remove('open'); });
  });

  Array.prototype.forEach.call(document.querySelectorAll('.metric'), buildOptions);
  Array.prototype.forEach.call(document.querySelectorAll('.completeness .cmp'), function(ch){
    ch.addEventListener('change', recalcTotal);
  });
})();
 /* === WHOLEHOG PICKER PATCH END === */

/* === WHOLEHOG MINIMAL JS PATCH (picker wiring + save click) === */
(function(){
  function bindPickers(){
    var mets = document.querySelectorAll('.metric');
    Array.prototype.forEach.call(mets, function(m){
      var btn  = m.querySelector('.picker');
      var pane = m.querySelector('.options');
      var out  = m.querySelector('.value');
      if(!btn || !pane) return;
      if(btn._whBound) return; btn._whBound = true;

      btn.addEventListener('click', function(e){
        e.stopPropagation();
        Array.prototype.forEach.call(document.querySelectorAll('.options.open'), function(x){ x.classList.remove('open'); });
        pane.classList.toggle('open');
      });
      Array.prototype.forEach.call(pane.querySelectorAll('.opt'), function(o){
        o.addEventListener('click', function(){
          var v = o.textContent.trim();
          if(out) out.textContent = v;
          btn.textContent = v;
          pane.classList.remove('open');
          if(typeof window.recalcTotal === 'function'){ window.recalcTotal(); }
        });
      });
    });

    document.addEventListener('click', function(){
      Array.prototype.forEach.call(document.querySelectorAll('.options.open'), function(x){ x.classList.remove('open'); });
    });
  }

  // Save button
  var saveBtn = document.getElementById('btnSave');
  if(saveBtn && !saveBtn._whBound){
    saveBtn._whBound = true;
    saveBtn.addEventListener('click', function(){
      var total = (document.getElementById('totalScore')||{}).textContent || '0';
      var ev = new CustomEvent('whSaveClicked', { detail: { total: total }});
      document.dispatchEvent(ev);
      console.log('[WholeHog] Save clicked. Total:', total);
    });
  }

  try{ bindPickers(); }catch(e){}
  setTimeout(function(){ try{ bindPickers(); }catch(e){} }, 100);
})();
 /* === END WHOLEHOG MINIMAL JS PATCH === */