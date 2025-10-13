(function(){
  const DATA_SOURCE = "/data/scores.json";
  const val = (obj, key, def=null) => (obj && obj[key] != null ? obj[key] : def);
  function timeNum(x){
    if (x == null) return Number.MAX_SAFE_INTEGER;
    if (typeof x === "number") return x;
    const d = new Date(x);
    return isNaN(d) ? Number.MAX_SAFE_INTEGER : d.getTime();
  }
  function compareOnSite(a, b){
    if (val(b,"total",0) !== val(a,"total",0)) return val(b,"total",0) - val(a,"total",0);
    if (val(b,"taste",0) !== val(a,"taste",0)) return val(b,"taste",0) - val(a,"taste",0);
    if (val(b,"tenderness",0) !== val(a,"tenderness",0)) return val(b,"tenderness",0) - val(a,"tenderness",0);
    if (val(b,"appearance",0) !== val(a,"appearance",0)) return val(b,"appearance",0) - val(a,"appearance",0);
    const at = timeNum(val(a,"submit_time",null));
    const bt = timeNum(val(b,"submit_time",null));
    if (bt !== at) return at - bt;
    return String(val(a,"team","")).localeCompare(String(val(b,"team","")));
  }
  const compareDescBy = (key) => (a,b) => {
    const diff = (val(b,key,0) - val(a,key,0));
    return diff !== 0 ? diff : String(val(a,"team","")).localeCompare(String(val(b,"team","")));
  };
  function compareKeyFor(r){
    return [
      val(r,"total",0),
      val(r,"taste",0),
      val(r,"tenderness",0),
      val(r,"appearance",0),
      val(r,"submit_time",Number.MAX_SAFE_INTEGER)
    ].join("|");
  }
  function rank(items, compareFn){
    const sorted = [...items].sort(compareFn);
    let place = 0, lastKey = null;
    return sorted.map((row, idx) => {
      const key = compareKeyFor(row);
      if (key !== lastKey) { place = idx + 1; lastKey = key; }
      return { ...row, _place: place };
    });
  }
  function trHighlight(place){
    if (place === 1) return "highlight-1";
    if (place === 2) return "highlight-2";
    if (place === 3) return "highlight-3";
    return "";
  }
  function renderTable(tbody, rows, cols){
    tbody.innerHTML = rows.map(r=>{
      const cls = trHighlight(r._place);
      const tds = cols.map(c=>{
        const content = (typeof c.render === "function") ? c.render(r) : val(r, c.key, "");
        return `<td>${content ?? ""}</td>`;
      }).join("");
      return `<tr class="${cls}">${tds}</tr>`;
    }).join("");
  }
  function build(data){
    const onsite = (data.onsite || []);
    const blind  = (data.blind  || []);
    const people = (data.people || []);
    const sauce  = (data.sauce  || []);
    const onsiteRanked = rank(onsite, compareOnSite);
    renderTable(
      document.querySelector("#table-onsite tbody"),
      onsiteRanked,
      [
        { key:"_place", render:r=>r._place },
        { key:"team" },
        { key:"total" },
        { key:"taste" },
        { key:"tenderness" },
        { key:"appearance" }
      ]
    );
    const blindRanked = rank(blind, compareDescBy("total"));
    renderTable(
      document.querySelector("#table-blind tbody"),
      blindRanked,
      [
        { key:"_place", render:r=>r._place },
        { key:"team" },
        { key:"total" }
      ]
    );
    const peopleRanked = rank(people, compareDescBy("votes"));
    renderTable(
      document.querySelector("#table-people tbody"),
      peopleRanked,
      [
        { key:"_place", render:r=>r._place },
        { key:"team" },
        { key:"votes" }
      ]
    );
    const sauceRanked = rank(sauce, compareDescBy("total"));
    renderTable(
      document.querySelector("#table-sauce tbody"),
      sauceRanked,
      [
        { key:"_place", render:r=>r._place },
        { key:"team" },
        { key:"total" }
      ]
    );
    const ts = new Date();
    const ga = document.getElementById("generated-at");
    if (ga) ga.textContent = `Updated: ${ts.toLocaleString()}`;
  }
  async function load(){
    if (window.WholeHogData && (window.WholeHogData.onsite || window.WholeHogData.blind || window.WholeHogData.people || window.WholeHogData.sauce)) {
      build(window.WholeHogData);
      return;
    }
    try {
      const res = await fetch(DATA_SOURCE, { cache: "no-store" });
      if (!res.ok) throw new Error("fetch failed");
      const data = await res.json();
      build(data);
    } catch (e) {
      console.error("Could not load scores:", e);
      build({ onsite:[], blind:[], people:[], sauce:[] });
    }
  }
  document.addEventListener("DOMContentLoaded", load);
})();