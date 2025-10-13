
param(
  [string]$Root = ".",
  [string]$HtmlFile = "blind.html"
)

$ErrorActionPreference = "Stop"

$Root     = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile
$jsPath   = Join-Path $Root "bt-wire.js"

if (!(Test-Path $htmlPath)) { Write-Error "Not found: $htmlPath"; exit 1 }

# Backup current HTML
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $htmlPath (Join-Path $Root ("blind.backup-" + $stamp + ".html")) -Force

# --- Write bt-wire.js (single-quoted here-string; terminator '@ on its own line) ---
$js = @'
(function(){
  var SUPABASE_URL = "https://wiolulxxfyetvdpnfusq.supabase.co";
  var SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indpb2x1bHh4ZnlldHZkcG5mdXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3Mzg4NjYsImV4cCI6MjA3NDMxNDg2Nn0.zrZI3_Ex3mfqkjKuWB9k-Gec77P7aqf6OJxKvGyxyTc";
  var REST = SUPABASE_URL.replace(/\/+$/,"") + "/rest/v1";

  function $(q){ return document.querySelector(q); }
  function firstSel(arr){ for (var i=0;i<arr.length;i++){ var el=$(arr[i]); if (el) return el; } return null; }
  function headers(extra){ var h={apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY}; if (extra){ for(var k in extra){ h[k]=extra[k]; } } return h; }

  // Load Chip # options from teams.chip_number (numbers only)
  async function loadChips(){
    var el = firstSel(["#chip-select","select[name='chip']","select[name*='chip' i]"]);
    if(!el || el.tagName!=="SELECT") return;
    try{
      var res = await fetch(REST + "/teams?select=chip_number&chip_number=is.not.null&order=chip_number.asc", { headers: headers({ Accept:"application/json" }) });
      if(!res.ok) return;
      var rows = await res.json();
      var seen = {};
      var frag = document.createDocumentFragment();
      var ph = document.createElement("option");
      ph.value = ""; ph.textContent = "Select chip #"; ph.disabled = true; ph.selected = true;
      frag.appendChild(ph);
      rows.forEach(function(r){
        if(!r || r.chip_number==null) return;
        var v = String(r.chip_number);
        if(seen[v]) return; seen[v]=1;
        var o = document.createElement("option");
        o.value = v; o.textContent = v;
        frag.appendChild(o);
      });
      el.innerHTML = ""; el.appendChild(frag);
    } catch(e){ /* leave existing options */ }
  }

  // Optional: load judges if a judges table exists with id, display_name
  async function loadJudges(){
    var el = firstSel(["#judge-select","select[name='judge']","select[name*='judge' i]"]);
    if(!el || el.tagName!=="SELECT") return;
    try{
      var res = await fetch(REST + "/judges?select=id,display_name&order=display_name.asc", { headers: headers({ Accept:"application/json" }) });
      if(!res.ok) return; // keep whatever is already on the page
      var rows = await res.json();
      if(!Array.isArray(rows) || rows.length===0) return;
      var frag = document.createDocumentFragment();
      var ph = document.createElement("option");
      ph.value = ""; ph.textContent = "Select judge"; ph.disabled = true; ph.selected = true;
      frag.appendChild(ph);
      rows.forEach(function(r){
        if(!r || r.id==null) return;
        var id = String(r.id);
        var name = (r.display_name!=null) ? String(r.display_name) : id;
        var o = document.createElement("option");
        o.value = id; o.textContent = name;
        frag.appendChild(o);
      });
      el.innerHTML = ""; el.appendChild(frag);
    } catch(e){ /* ignore, optional */ }
  }

  // Duplicate check
  async function duplicateExists(judgeId, chipNum){
    var url = REST + "/blind_taste?select=id&judge_id=eq." + encodeURIComponent(judgeId) + "&chip_number=eq." + encodeURIComponent(chipNum) + "&limit=1";
    var res = await fetch(url, { headers: headers({ Accept:"application/json" }) });
    if(!res.ok) return true; // if we can't verify, err safe
    var rows = await res.json();
    return Array.isArray(rows) && rows.length>0;
  }

  // Insert
  async function insertRow(row){
    var res = await fetch(REST + "/blind_taste", {
      method: "POST",
      headers: headers({ "Content-Type": "application/json", Prefer: "return=representation" }),
      body: JSON.stringify(row)
    });
    if(!res.ok){
      var t = await res.text().catch(function(){return""});
      return { error: { message: t || ("HTTP " + res.status) } };
    }
    var data = await res.json();
    return { data: Array.isArray(data) ? data[0] : data };
  }

  // Read total (if no explicit total field, sum score fields; no UI changes)
  function readTotal(){
    var tEl = firstSel(["#score-total","input[name='score_total']"]);
    if (tEl && String(tEl.value||"").trim()!==""){
      var n = Number(String(tEl.value).trim()); if(!Number.isNaN(n)) return n;
    }
    var t = 0, fields = document.querySelectorAll("input[data-score],input.score-field,select[data-score],select.score-field");
    fields.forEach(function(c){ var v=(c.value==null?"":String(c.value).trim()); var n=Number(v); if(!Number.isNaN(n)) t+=n; });
    return t;
  }

  async function onSave(){
    alert("Saving…"); // confirms click handler is wired

    var judgeSel = firstSel(["#judge-select","select[name='judge']","select[name*='judge' i]"]);
    var chipSel  = firstSel(["#chip-select","select[name='chip']","select[name*='chip' i]"]);
    var judgeId  = judgeSel ? String(judgeSel.value||"").trim() : "";
    var chipRaw  = chipSel  ? String(chipSel.value||"").trim()  : "";
    var chipNum  = Number(chipRaw);

    if(!judgeId){ alert("Please select a Judge."); return; }
    if(!chipRaw || Number.isNaN(chipNum) || chipNum<=0){ alert("Please select a valid Chip #."); return; }

    var row = { judge_id: judgeId, chip_number: chipNum, score_total: readTotal() };
    // map common score names if present (no UI changes)
    var a = document.querySelector("[name='appearance']"); if(a){ var v=Number(String(a.value||"").trim()); if(!Number.isNaN(v)) row.score_appearance=v; }
    var t = document.querySelector("[name='tenderness']"); if(t){ var v2=Number(String(t.value||"").trim()); if(!Number.isNaN(v2)) row.score_tenderness=v2; }
    var f = document.querySelector("[name='flavor']"); if(f){ var v3=Number(String(f.value||"").trim()); if(!Number.isNaN(v3)) row.score_flavor=v3; }

    if (await duplicateExists(judgeId, chipNum)){
      alert("Error: This Judge + Chip # already exists.");
      return;
    }

    var btn = document.getElementById("save-blind-taste"); if(btn) btn.disabled = true;
    var result = await insertRow(row);
    if(btn) btn.disabled = false;

    if (result.error){
      alert(result.error.message || "Save failed.");
      return;
    }
    alert("Saved! Chip #"+result.data.chip_number+", Judge "+result.data.judge_id+".");
  }

  function wire(){
    loadChips();
    loadJudges(); // optional
    var btn = document.getElementById("save-blind-taste");
    if (btn){ btn.addEventListener("click", function(e){ e.preventDefault(); onSave(); }); }
    else {
      var form = firstSel(["form"]);
      if(form){ form.addEventListener("submit", function(e){ e.preventDefault(); onSave(); }); }
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", wire);
  else wire();
})();
'@

Set-Content -Path $jsPath -Encoding UTF8 -Value $js

# Inject a single <script> tag (idempotent)
$html = Get-Content $htmlPath -Raw
$tag  = '<script src="./bt-wire.js"></script>'

if ($html -notlike "*bt-wire.js*") {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $tag`n</body>", 'IgnoreCase')
  } else {
    $html += "`n$tag`n"
  }
  $html | Set-Content -Path $htmlPath -Encoding UTF8
}

Write-Host "Wired blind.html to Supabase. Open /$HtmlFile and test Chip/Judge load and Save."


