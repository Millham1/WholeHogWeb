(function(){
  function fix(){
    const sels=[...document.querySelectorAll("select")].filter(el=>{
      const id=(el.id||"").toLowerCase(), nm=(el.name||"").toLowerCase();
      return id.includes("chip")||nm.includes("chip");
    });
    for(const sel of sels){
      for(const opt of sel.options){
        const txt=String(opt.textContent||opt.label||"").trim();
        const m=txt.match(/^(\d{1,6})\b/); if(m){ const n=m[1]; opt.textContent=n; opt.label=n; opt.value=n; }
      }
    }
  }
  document.addEventListener("DOMContentLoaded", fix);
  window.addEventListener("load", fix);
  setTimeout(fix, 500);
})();
