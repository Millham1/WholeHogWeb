(function(){
  var s = document.currentScript;
  var SUPABASE_URL = (s && s.dataset && s.dataset.url) || "";
  var SUPABASE_KEY = (s && s.dataset && s.dataset.key) || "";
  var REST = SUPABASE_URL.replace(/\/+$/,"") + "/rest/v1";

  function $(q){ return document.querySelector(q); }
  function sHeaders(extra){
    var h = { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY };
    if (extra){ for (var k in extra){ h[k]=extra[k]; } }
    return h;
  }
  function keepOrMake(selectEl){
    if (!selectEl) return null;
    // ensure it remains a <select>
    if (selectEl.tagName !== "SELECT") return null;
    return selectEl;
  }

  async function loadChipNumbers(){
    var el = document.querySelector("#chip-select, select[name='chip'], select[name*='chip' i]");
    el = keepOrMake(el);
    if (!el) return; // nothing to do

    var prev = (el.value || "").trim();
    try{
      // fetch numbers (client-dedupe)
      var url = REST + "/teams?select=chip_number&chip_number=is.not.null&order=chip_number.asc";
      var res = await fetch(url, { method:"GET", headers: sHeaders({ Accept: "application/json" }) });
      if (!res.ok) { console.warn("Chip load HTTP", res.status); return; }
      var rows = await res.json();
      var nums = [];
      rows.forEach(function(r){
        if (r && r.chip_number != null) {
          var n = String(r.chip_number);
          if (nums.indexOf(n) === -1) nums.push(n);
        }
      });
      if (nums.length === 0) return;

      // rebuild options (numbers only)
      var frag = document.createDocumentFragment();
      var ph = document.createElement("option");
      ph.value = ""; ph.textContent = "Select chip #"; ph.disabled = true; ph.selected = true;
      frag.appendChild(ph);
      nums.forEach(function(n){
        var o = document.createElement("option");
        o.value = n; o.textContent = n;
        frag.appendChild(o);
      });
      el.innerHTML = "";
      el.appendChild(frag);

      // restore previous selection if still valid
      if (prev && nums.indexOf(prev) !== -1) { el.value = prev; ph.selected = false; }
    } catch (e) {
      console.error("loadChipNumbers error", e);
      // leave existing options unchanged
    }
  }

  async function loadJudges(){
    var el = document.querySelector("#judge-select, select[name='judge'], select[name*='judge' i]");
    el = keepOrMake(el);
    if (!el) return;

    var prev = (el.value || "").trim();
    try{
      // if you have a judges table with id/display_name
      var url = REST + "/judges?select=id,display_name&order=display_name.asc";
      var res = await fetch(url, { method:"GET", headers: sHeaders({ Accept: "application/json" }) });

      if (!res.ok) {
        // No table or blocked by RLS: quietly keep whatever is already in the page
        console.warn("Judge load HTTP", res.status);
        return;
      }

      var rows = await res.json();
      if (!Array.isArray(rows) || rows.length === 0) return;

      var frag = document.createDocumentFragment();
      var ph = document.createElement("option");
      ph.value = ""; ph.textContent = "Select judge"; ph.disabled = true; ph.selected = true;
      frag.appendChild(ph);

      rows.forEach(function(r){
        if (!r) return;
        var id = (r.id != null) ? String(r.id) : "";
        var name = (r.display_name != null) ? String(r.display_name) : id;
        if (!id) return;
        var o = document.createElement("option");
        o.value = id; o.textContent = name;
        frag.appendChild(o);
      });

      el.innerHTML = "";
      el.appendChild(frag);

      if (prev) { el.value = prev; ph.selected = false; }
    } catch (e) {
      console.error("loadJudges error", e);
    }
  }

  function wire(){
    // Populate once on load; do not change your layout/UI
    loadJudges();
    loadChipNumbers();
  }
  document.addEventListener("DOMContentLoaded", wire);
})();
