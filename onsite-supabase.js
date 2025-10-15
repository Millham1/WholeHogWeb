(function(){
  function waitForSupabase(callback) {
    if (window.supabase && typeof window.supabase.from === 'function') {
      callback(window.supabase);
    } else {
      setTimeout(() => waitForSupabase(callback), 100);
    }
  }

  var APPEAR = even(2,40,2);
  var COLOR  = even(2,40,2);
  var STEP4  = even(4,80,4);
  // Add 70, 74, 78 to STEP4 for skin, moisture, meat_sauce
  STEP4.splice(STEP4.indexOf(72), 0, 70);
  STEP4.splice(STEP4.indexOf(76), 0, 74);
  STEP4.splice(STEP4.indexOf(80), 0, 78);

  function even(min,max,step){ var a=[]; for(var v=min; v<=max; v+=step) a.push(v); return a; }

  var state = {
    teamId:"",
    judgeId:"",
    suitable:"",
    vals: { appearance:null, color:null, skin:null, moisture:null, meat_sauce:null },
    comp: { cln:false, knv:false, sau:false, drk:false, thr:false }
  };

  function id(s){ return document.getElementById(s); }

  async function fillSelectors(sb){
    var tSel = id("teamSel");
    var jSel = id("judgeSel");

    // Load teams
    const { data: teams, error: tErr } = await sb.from('teams').select('*').order('name', { ascending: true });
    if (tErr) {
      console.error('Error loading teams:', tErr);
      tSel.innerHTML = '<option value="">Error loading teams</option>';
    } else {
      tSel.innerHTML = '<option value="">Select team...</option>' + (teams || []).map(function(t){
        var label = t.name + " (Site " + (t.site_number || '') + ")";
        return '<option value="'+t.id+'">'+escapeHtml(label)+'</option>';
      }).join("");
    }

    // Load judges
    const { data: judges, error: jErr } = await sb.from('judges').select('*').order('name', { ascending: true });
    if (jErr) {
      console.error('Error loading judges:', jErr);
      jSel.innerHTML = '<option value="">Error loading judges</option>';
    } else {
      jSel.innerHTML = '<option value="">Select judge...</option>' + (judges || []).map(function(j){
        return '<option value="'+j.id+'">'+escapeHtml(j.name)+'</option>';
      }).join("");
    }
  }

  function escapeHtml(s){ return String(s||"").replace(/[&<>"']/g,function(c){return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]);}); }

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

  async function saveEntry(sb){
    if(!state.teamId){ alert("Pick a Team"); return; }
    if(!state.judgeId){ alert("Pick a Judge"); return; }
    if(!state.suitable){ alert("Select Suitable for public consumption"); return; }
    var v = state.vals;
    if(v.appearance==null||v.color==null||v.skin==null||v.moisture==null||v.meat_sauce==null){
      alert("Choose all scoring values"); return;
    }

    var entry = {
      team_id: state.teamId,
      judge_id: state.judgeId,
      suitable: state.suitable,
      appearance: v.appearance,
      color: v.color,
      skin: v.skin,
      moisture: v.moisture,
      meat_sauce: v.meat_sauce,
      completeness: state.comp
    };

    const { data, error } = await sb.from('onsite_scores').insert([entry]).select().single();
    
    if (error) {
      console.error('Save error:', error);
      alert('Failed to save entry: ' + error.message);
      return;
    }

    // reset selections (keep team/judge)
    state.suitable=""; id("suitableSel").value="";
    state.vals = { appearance:null,color:null,skin:null,moisture:null,meat_sauce:null };
    state.comp = { cln:false,knv:false,sau:false,drk:false,thr:false };
    buildMiniCards();
    ["cln","knv","sau","drk","thr"].forEach(function(k){ var cb=id(k); if(cb) cb.checked=false; });
    recalcTotal();
    alert("Entry saved successfully!");
  }

  async function exportCsv(sb){
    const { data: entries, error } = await sb.from('onsite_scores').select('*, teams(name, site_number), judges(name)');
    
    if (error) {
      console.error('Export error:', error);
      alert('Failed to export: ' + error.message);
      return;
    }

    var head = ["id","created_at","team","site","judge","suitable","appearance","color","skin","moisture","meat_sauce","siteClean","knives","sauce","drinks","thermometers","total"];
    var lines = [ head.join(",") ];
    
    (entries || []).forEach(function(e){
      var teamName = (e.teams && e.teams.name) || '';
      var siteNum = (e.teams && e.teams.site_number) || '';
      var judgeName = (e.judges && e.judges.name) || '';
      var tot = e.appearance + e.color + e.skin + e.moisture + e.meat_sauce +
        ((e.completeness&&e.completeness.cln?8:0)+(e.completeness&&e.completeness.knv?8:0)+(e.completeness&&e.completeness.sau?8:0)+(e.completeness&&e.completeness.drk?8:0)+(e.completeness&&e.completeness.thr?8:0));
      var row = [
        e.id, e.created_at, csv(teamName), csv(siteNum), csv(judgeName), e.suitable,
        e.appearance, e.color, e.skin, e.moisture, e.meat_sauce,
        e.completeness&&e.completeness.cln?1:0,
        e.completeness&&e.completeness.knv?1:0,
        e.completeness&&e.completeness.sau?1:0,
        e.completeness&&e.completeness.drk?1:0,
        e.completeness&&e.completeness.thr?1:0,
        tot
      ];
      lines.push(row.join(","));
    });
    
    var blob = new Blob([lines.join("\n")], {type:"text/csv;charset=utf-8"});
    var a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "WholeHog-Onsite-Export.csv";
    document.body.appendChild(a); a.click(); a.remove();
  }
  
  function csv(s){ s=String(s||""); return '"'+s.replace(/"/g,'""')+'"'; }

  waitForSupabase(function(sb){
    document.addEventListener("DOMContentLoaded", function(){
      fillSelectors(sb);
      buildMiniCards();
      wireCompleteness();
      recalcTotal();

      id("teamSel").addEventListener("change", function(){ state.teamId = this.value; });
      id("judgeSel").addEventListener("change", function(){ state.judgeId = this.value; });
      id("suitableSel").addEventListener("change", function(){ state.suitable = this.value; });
      id("saveBtn").addEventListener("click", function(){ saveEntry(sb); });
      id("exportBtn").addEventListener("click", function(){ exportCsv(sb); });
    });
  });
})();
