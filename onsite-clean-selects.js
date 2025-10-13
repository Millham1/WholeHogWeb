(() => {
  function clean(s){
    if (s == null) return s;
    try { s = ("" + s).normalize('NFC'); } catch(e) { s = "" + s; }
    s = s.replace(/[\u2013\u2014]/g, '-');  // en/em dash -> hyphen
    s = s.replace(/\u2026/g, '...');       // ellipsis
    s = s.replace(/\u00A0/g, ' ');         // NBSP -> space
    s = s.replace(/[\u200B-\u200D\uFEFF\u2060\u202A-\u202E\u2066-\u2069]/g, ''); // zero-width/bidi
    s = s.replace(/Â/g, '');               // stray 'Â'
    s = s.replace(/\s+/g, ' ').trim();
    return s;
  }
  function cleanAll(){
    document.querySelectorAll('select option').forEach(opt=>{
      if (opt && opt.text != null) opt.text = clean(opt.text);
    });
    document.querySelectorAll('select').forEach(sel=>{
      const opt = sel.querySelector('option[value=""]');
      if(!opt) return;
      const id = (sel.id||'').toLowerCase();
      if(id.includes('team'))  opt.text = 'Select team...';
      if(id.includes('judge')) opt.text = 'Select judge...';
    });
  }
  function run(){ cleanAll(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', run); else run();
  setTimeout(run, 800);
  setTimeout(run, 2000);
  const obs = new MutationObserver(run);
  document.querySelectorAll('select').forEach(sel=>obs.observe(sel,{childList:true,subtree:true,characterData:true}));
  window.WH_CleanOnsiteSelects = run;
})();
