(() => {
  // ------- Data & helpers -------
  const even = (min, max, step) => Array.from({length: Math.floor((max-min)/step)+1}, (_,i)=>min+i*step);
  const APPEARANCE = even(2,40,2);
  const COLOR      = even(2,40,2);
  const STEP4      = even(4,80,4); // skin, moisture, meatSauce

  const $ = sel => document.querySelector(sel);
  const $$ = sel => Array.from(document.querySelectorAll(sel));

  const store = {
    get key() { return 'wh-entries-v1'; },
    get tkey(){ return 'wh-teams-v1'; },
    get jkey(){ return 'wh-judges-v1'; },
    load(k, def){ try{ return JSON.parse(localStorage.getItem(k)||''); }catch{ return def; } },
    save(k, v){ localStorage.setItem(k, JSON.stringify(v)); }
  };

  let entries = store.load(store.key, []);
  let teams   = store.load(store.tkey, ["Team A","Team B","Team C"]);
  let judges  = store.load(store.jkey, ["Judge 1","Judge 2","Judge 3"]);

  const teamSel = $('#teamSelect');
  const judgeSel= $('#judgeSelect');
  const suitableSel = $('#suitableSelect');
  const totalEl = $('#totalScore');

  function fillSelect(el, items){
    el.innerHTML = '<option value="">Select...</option>' + items.map(t=>`<option>${t}</option>`).join('');
  }
  fillSelect(teamSel, teams);
  fillSelect(judgeSel, judges);

  // current scoring state
  const state = {
    team: '', judge: '', suitable: '',
    appearance: null, color: null, skin: null, moisture: null, meatSauce: null,
    compl: { clean:false, knives:false, sauce:false, drinks:false, thermometers:false }
  };

  teamSel.addEventListener('change', e => state.team = e.target.value);
  judgeSel.addEventListener('change', e => state.judge = e.target.value);
  suitableSel.addEventListener('change', e => { state.suitable = e.target.value; computeTotal(); });

  $$('.completeness input[type="checkbox"]').forEach(cb=>{
    cb.addEventListener('change', ()=>{
      state.compl[cb.dataset.comp] = cb.checked;
      computeTotal();
    });
  });

  // ------- Build metric options -------
  const sets = {
    appearance: APPEARANCE,
    color: COLOR,
    skin: STEP4,
    moisture: STEP4,
    meatSauce: STEP4
  };

  Object.keys(sets).forEach(name=>{
    const box = document.getElementById('opt-'+name);
    box.innerHTML = sets[name].map(v=>`<button type="button" class="opt" data-name="${name}" data-val="${v}">${v}</button>`).join('');
  });

  // Toggle open
  document.addEventListener('click', (e)=>{
    const pick = e.target.closest('.pick');
    const opt  = e.target.closest('.opt');

    // close all on outside click
    if(!pick && !opt){
      $$('.options').forEach(o=>o.classList.remove('open'));
      return;
    }

    if(pick){
      const name = pick.dataset.name;
      $$('.options').forEach(o=>o.classList.remove('open'));
      const box = document.getElementById('opt-'+name);
      if(box){ box.classList.toggle('open'); }
      return;
    }

    if(opt){
      const name = opt.dataset.name;
      const val  = Number(opt.dataset.val);
      state[name] = val;
      const pv = document.getElementById('val-'+name);
      if(pv) pv.textContent = String(val);
      const box = document.getElementById('opt-'+name);
      if(box) box.classList.remove('open');
      computeTotal();
      return;
    }
  });

  function completenessPoints(){
    const c = state.compl;
    const count = (c.clean?1:0)+(c.knives?1:0)+(c.sauce?1:0)+(c.drinks?1:0)+(c.thermometers?1:0);
    return count * 8;
  }

  function computeTotal(){
    const parts = ['appearance','color','skin','moisture','meatSauce'].map(k => state[k] || 0);
    const base = parts.reduce((a,b)=>a+b,0);
    const total = base + completenessPoints();
    totalEl.textContent = String(total);
    return total;
  }

  // ------- Save entry + Leaderboard -------
  $('#btnSave').addEventListener('click', ()=>{
    if(!state.team){ alert('Select a Team'); return; }
    if(!state.judge){ alert('Select a Judge'); return; }
    if(!state.suitable){ alert('Select Suitable for public consumption'); return; }
    const missing = ['appearance','color','skin','moisture','meatSauce'].filter(k=>state[k]===null);
    if(missing.length){ alert('Pick all scoring values.'); return; }

    const entry = {
      id: cryptoRandomId(),
      ts: Date.now(),
      team: state.team,
      judge: state.judge,
      suitable: state.suitable,
      appearance: state.appearance,
      color: state.color,
      skin: state.skin,
      moisture: state.moisture,
      meatSauce: state.meatSauce,
      compl: {...state.compl},
      total: computeTotal()
    };
    entries.push(entry);
    store.save(store.key, entries);
    rebuildLeaderboard();
  });

  $('#btnExport').addEventListener('click', ()=>{
    const rows = [
      ['id','ts','team','judge','suitable','appearance','color','skin','moisture','meatSauce','compl.clean','compl.knives','compl.sauce','compl.drinks','compl.thermometers','total'],
      ...entries.map(e=>[
        e.id, e.ts, e.team, e.judge, e.suitable, e.appearance, e.color, e.skin, e.moisture, e.meatSauce,
        e.compl.clean?1:0, e.compl.knives?1:0, e.compl.sauce?1:0, e.compl.drinks?1:0, e.compl.thermometers?1:0, e.total
      ])
    ];
    const csv = rows.map(r=>r.map(x=>`"${String(x).replace(/"/g,'""')}"`).join(',')).join('\r\n');
    const blob = new Blob([csv], {type:'text/csv;charset=utf-8;'});
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'WholeHog-Export.csv';
    document.body.appendChild(a);
    a.click();
    a.remove();
  });

  function rebuildLeaderboard(){
    // group by team
    const byTeam = new Map();
    for(const e of entries){
      const g = byTeam.get(e.team) || { team:e.team, total:0, meatSauce:0, skin:0, moisture:0 };
      g.total     += e.total;
      g.meatSauce += e.meatSauce;
      g.skin      += e.skin;
      g.moisture  += e.moisture;
      byTeam.set(e.team, g);
    }
    const list = Array.from(byTeam.values());
    // sort by total desc; tiebreakers: meatSauce desc, then skin, then moisture
    list.sort((a,b)=>{
      if(b.total !== a.total) return b.total - a.total;
      if(b.meatSauce !== a.meatSauce) return b.meatSauce - a.meatSauce;
      if(b.skin !== a.skin) return b.skin - a.skin;
      if(b.moisture !== a.moisture) return b.moisture - a.moisture;
      return 0;
    });

    const tbody = $('#leaderTable tbody');
    tbody.innerHTML = list.map((r,i)=>`<tr><td>${i+1}</td><td>${escapeHtml(r.team)}</td><td>${r.total}</td></tr>`).join('');
  }

  function escapeHtml(s){ return String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
  function cryptoRandomId(){
    if(window.crypto?.getRandomValues){
      const a = new Uint8Array(16); crypto.getRandomValues(a);
      return Array.from(a,b=>b.toString(16).padStart(2,'0')).join('');
    }
    return String(Date.now()) + Math.random().toString(16).slice(2);
  }

  // initial compute + leaderboard
  computeTotal();
  rebuildLeaderboard();
})();

