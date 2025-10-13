/* bt-local.js — local-only scoring (no DB), duplicate guard, Export CSV, one-time picker */
(function(){
  const LS_KEY  = "blindTasteEntries";
  const CFG_KEY = "blindTasteConfig";

  const $ = (q) => document.querySelector(q);
  const uid = (p) => p + "-" + Math.random().toString(36).slice(2,8);

  function readCfg(){ try { return JSON.parse(localStorage.getItem(CFG_KEY)||"{}"); } catch { return {}; } }
  function writeCfg(cfg){ localStorage.setItem(CFG_KEY, JSON.stringify(cfg||{})); }

  function readEntries(){ try { return JSON.parse(localStorage.getItem(LS_KEY)||"[]"); } catch { return []; } }
  function writeEntries(rows){ localStorage.setItem(LS_KEY, JSON.stringify(rows||[])); }

  function readNum(el){
    if (!el) return NaN;
    const n = Number(String(el.value||"").trim());
    return Number.isNaN(n) ? NaN : n;
  }

  function computeTotal(){
    const tot = document.querySelector("#score-total, input[name='score_total']");
    if (tot){
      const n = readNum(tot);
      if (!Number.isNaN(n)) return n;
    }
    let sum = 0;
    document.querySelectorAll("input[data-score],input.score-field,select[data-score],select.score-field")
      .forEach(c => { const n = readNum(c); if (!Number.isNaN(n)) sum += n; });
    return sum;
  }

  function ensureId(el, prefix){
    if (!el.id) el.id = uid(prefix);
    return "#" + el.id;
  }

  function showSetup(){
    const prev = document.getElementById("bt-local-setup");
    if (prev) prev.remove();

    const box = document.createElement("div");
    box.id = "bt-local-setup";
    box.style.cssText = "position:fixed;right:10px;bottom:10px;z-index:999999;background:#111;color:#fff;max-width:380px;font:13px/1.4 Arial;padding:12px;border-radius:10px;box-shadow:0 4px 16px rgba(0,0,0,.35)";
    box.innerHTML = `
      <div style="display:flex;align-items:center;gap:8px;margin-bottom:8px">
        <strong>Local Scoring Setup</strong>
        <button id="bt-close" style="margin-left:auto;background:#444;color:#fff;border:0;border-radius:6px;padding:4px 8px;cursor:pointer">Close</button>
      </div>
      <ol style="margin:0 0 8px 18px;padding:0">
        <li>Click <b>Pick Judge</b>, then click your Judge dropdown.</li>
        <li>Click <b>Pick Chip</b>, then click your Chip # dropdown.</li>
        <li>Click <b>Pick Save</b>, then click your Save button.</li>
      </ol>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button id="bt-pick-judge" style="background:#0d6efd;border:0;color:#fff;border-radius:6px;padding:6px 10px;cursor:pointer">Pick Judge</button>
        <button id="bt-pick-chip"  style="background:#0d6efd;border:0;color:#fff;border-radius:6px;padding:6px 10px;cursor:pointer">Pick Chip</button>
        <button id="bt-pick-save"  style="background:#0d6efd;border:0;color:#fff;border-radius:6px;padding:6px 10px;cursor:pointer">Pick Save</button>
        <button id="bt-clear"      style="background:#6c757d;border:0;color:#fff;border-radius:6px;padding:6px 10px;cursor:pointer">Reset Wiring</button>
      </div>
      <div style="margin-top:8px;font-size:12px;color:#bbb">After picking all three once, this panel won't be needed again.</div>
    `;
    document.body.appendChild(box);

    document.getElementById("bt-close").onclick = () => box.remove();
    document.getElementById("bt-clear").onclick = () => { localStorage.removeItem(CFG_KEY); alert("Wiring reset. Reload and run setup again."); };

    function pick(label, expectTag, key, prefix){
      alert("Click the " + label + " now");
      const handler = (e) => {
        const el = e.target.closest(expectTag);
        if (el){
          document.removeEventListener("click", handler, true);
          const cfg = readCfg();
          cfg[key] = ensureId(el, prefix);
          writeCfg(cfg);
          alert(label + " set to " + cfg[key]);
        }
      };
      document.addEventListener("click", handler, true);
    }

    document.getElementById("bt-pick-judge").onclick = () => pick("Judge dropdown", "select", "judgeSel", "bt-judge");
    document.getElementById("bt-pick-chip").onclick  = () => pick("Chip # dropdown", "select", "chipSel",  "bt-chip");
    document.getElementById("bt-pick-save").onclick  = () => pick("Save button",    "button", "saveBtn",   "bt-save");
  }

  function addExportButton(){
    if (document.getElementById("bt-export-csv")) return;
    const btn = document.createElement("button");
    btn.id = "bt-export-csv";
    btn.textContent = "Export CSV";
    btn.title = "Download local scoring data";
    btn.style.cssText = "position:fixed;left:10px;bottom:10px;z-index:999999;background:#198754;color:#fff;border:0;border-radius:8px;padding:8px 12px;cursor:pointer";
    btn.onclick = () => {
      const rows = readEntries();
      if (!rows.length){ alert("No entries yet."); return; }
      const headers = ["timestamp","judge_id","chip_number","score_appearance","score_tenderness","score_flavor","score_total"];
      const csvRows = [headers.join(",")].concat(rows.map(r => headers.map(h => {
        const v = (r[h]===undefined || r[h]===null) ? "" : String(r[h]).replace(/"/g,'""');
        return '"' + v + '"';
      }).join(",")));
      const blob = new Blob([csvRows.join("\n")], {type:"text/csv"});
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url; a.download = "blind_taste_export.csv";
      document.body.appendChild(a); a.click(); a.remove();
      URL.revokeObjectURL(url);
    };
    document.body.appendChild(btn);
  }

  function wireSave(){
    const cfg = readCfg();
    const jSel = cfg.judgeSel ? $(cfg.judgeSel) : null;
    const cSel = cfg.chipSel  ? $(cfg.chipSel)  : null;
    const sBtn = cfg.saveBtn  ? $(cfg.saveBtn)  : null;

    if (!jSel || !cSel || !sBtn) { showSetup(); return; }

    function computeRow(){
      const judge_id = String(jSel.value||"").trim();
      const chip_raw = String(cSel.value||"").trim();
      const chip_num = Number(chip_raw);
      return {
        timestamp: new Date().toISOString(),
        judge_id: judge_id,
        chip_number: chip_num,
        score_appearance: readNum(document.querySelector("[name='appearance']")),
        score_tenderness: readNum(document.querySelector("[name='tenderness']")),
        score_flavor: readNum(document.querySelector("[name='flavor']")),
        score_total: computeTotal()
      };
    }

    function handler(e){
      e.preventDefault();
      const row = computeRow();
      if (!row.judge_id){ alert("Please select a Judge."); return; }
      if (!row.chip_number || Number.isNaN(row.chip_number) || row.chip_number <= 0){ alert("Please select a valid Chip #."); return; }

      const all = readEntries();
      const dup = all.some(r => String(r.judge_id)===row.judge_id && Number(r.chip_number)===Number(row.chip_number));
      if (dup){ alert("Error: This Judge + Chip # has already been saved."); return; }

      all.push(row);
      writeEntries(all);
      alert("Saved locally! (Judge " + row.judge_id + " / Chip #" + row.chip_number + ")");

      const form = document.querySelector("form");
      if (form && typeof form.reset === "function") form.reset();
    }

    sBtn.addEventListener("click", handler);
    const form = document.querySelector("form");
    if (form) form.addEventListener("submit", handler);
  }

  function start(){
    addExportButton();
    wireSave();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
