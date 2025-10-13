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
    tSel.innerHTML = '<option value="">Select team...</option>' + teams.map(function(t,ix){
      var label = t.name + " (Site " + t.site + ")";
      // store logical id as "name|site"
      return '<option value="'+escapeAttr(t.name+'|'+t.site)+'">'+escapeHtml(label)+'</option>';
    }).join("");
    jSel.innerHTML = '<option value="">Select judge...</option>' + judges.map(function(j){
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