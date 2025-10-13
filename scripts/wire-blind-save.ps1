param(
  [string]$Root = ".",
  [string]$HtmlFile = "blind.html",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$ErrorActionPreference = "Stop"

$Root     = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile
$jsPath   = Join-Path $Root "bt-save-rest.js"

if (!(Test-Path $htmlPath)) { Write-Error "Not found: $htmlPath"; exit 1 }

# Backup once per run
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $htmlPath (Join-Path $Root ("blind.backup-" + $stamp + ".html")) -Force

# JS (single-quoted here-string to avoid interpolation)
$js = @'
(function(){
  var thisScript   = document.currentScript;
  var SUPABASE_URL = (thisScript && thisScript.dataset && thisScript.dataset.url) || "";
  var SUPABASE_KEY = (thisScript && thisScript.dataset && thisScript.dataset.key) || "";
  var REST         = SUPABASE_URL.replace(/\/+$/,"") + "/rest/v1";

  function $(s){ return document.querySelector(s); }
  function $all(s){ return Array.prototype.slice.call(document.querySelectorAll(s)); }
  function firstSel(list){ for (var i=0;i<list.length;i++){ var el=$(list[i]); if(el) return el; } return null; }

  function judgeEl(){ return firstSel(["#judge-select","select[name='judge']","select[name*='judge' i]"]); }
  function chipEl(){  return firstSel(["#chip-select","select[name='chip']","select[name*='chip' i]"]); }

  function scoreFields(){ return $all("input[data-score], input.score-field, select[data-score], select.score-field"); }

  function readTotal(){
    var el = firstSel(["#score-total","input[name='score_total']"]);
    if (el && String(el.value||"").trim() !== "") {
      var n = Number(String(el.value).trim());
      if (!Number.isNaN(n)) return n;
    }
    // Fallback: sum scores if no total field
    var t = 0; scoreFields().forEach(function(c){
      var v = (c.value==null ? "" : String(c.value).trim());
      var n = Number(v); if (!Number.isNaN(n)) t += n;
    });
    return t;
  }

  function sHeaders(extra){
    var h = { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY };
    if (extra){ for (var k in extra){ h[k] = extra[k]; } }
    return h;
  }

  async function duplicateExists(judgeId, chipNum){
    var url = REST + "/blind_taste?select=id&judge_id=eq." + encodeURIComponent(judgeId) + "&chip_number=eq." + encodeURIComponent(chipNum) + "&limit=1";
    var res = await fetch(url, { method:"GET", headers: sHeaders({ Accept: "application/json" }) });
    if (!res.ok){ console.error("dup http", res.status); alert("Could not verify duplicates (network/policy)."); return true; }
    var rows = await res.json();
    return Array.isArray(rows) && rows.length > 0;
  }

  async function insertRow(row){
    var res = await fetch(REST + "/blind_taste", {
      method: "POST",
      headers: sHeaders({ "Content-Type": "application/json", Prefer: "return=representation" }),
      body: JSON.stringify(row)
    });
    if (!res.ok){
      var t = await res.text().catch(function(){ return ""; });
      return { error: { message: t || ("HTTP " + res.status) } };
    }
    var data = await res.json();
    return { data: Array.isArray(data) ? data[0] : data };
  }

  async function onSave(){
    alert("Saving…"); // proves handler is wired

    var jEl = judgeEl(), cEl = chipEl();
    var judgeId = jEl ? String(jEl.value||"").trim() : "";
    var chipRaw = cEl ? String(cEl.value||"").trim() : "";
    var chipNum = Number(chipRaw);

    if (!judgeId){ alert("Please select a Judge."); return; }
    if (!chipRaw || Number.isNaN(chipNum) || chipNum <= 0){ alert("Please select a valid Chip #."); return; }

    // Build row using your existing fields (we do NOT change UI)
    var row = { judge_id: judgeId, chip_number: chipNum };
    // Known score names (if present)
    var appEl = firstSel(["[name='appearance']"]);
    var tenEl = firstSel(["[name='tenderness']"]);
    var flaEl = firstSel(["[name='flavor']"]);
    var app = appEl ? Number(String(appEl.value||"").trim()) : NaN;
    var ten = tenEl ? Number(String(tenEl.value||"").trim()) : NaN;
    var fla = flaEl ? Number(String(flaEl.value||"").trim()) : NaN;
    if (!Number.isNaN(app)) row.score_appearance = app;
    if (!Number.isNaN(ten)) row.score_tenderness = ten;
    if (!Number.isNaN(fla)) row.score_flavor = fla;

    // Total (from field if present, else sum)
    row.score_total = readTotal();

    // Duplicate guard
    if (await duplicateExists(judgeId, chipNum)){
      alert("Error: This Judge + Chip # is already saved.");
      return;
    }

    // Insert
    var btn = $("#save-blind-taste"); if (btn) btn.disabled = true;
    var result = await insertRow(row);
    if (btn) btn.disabled = false;

    if (result.error){
      console.error("insert error", result.error);
      alert(result.error.message || "Save failed (permissions or network).");
      return;
    }

    alert("Saved! Chip #" + result.data.chip_number + ", Judge " + result.data.judge_id + ".");
    // Do NOT clear/modify your scoring UI (as requested)
  }

  function wire(){
    var btn = $("#save-blind-taste");
    if (btn){ btn.addEventListener("click", function(e){ e.preventDefault(); onSave(); }); }
    else {
      // Fallback: first form submit on the page
      var form = firstSel(["form"]);
      if (form){ form.addEventListener("submit", function(e){ e.preventDefault(); onSave(); }); }
    }
  }

  document.addEventListener("DOMContentLoaded", wire);
})();
'@

$js | Set-Content -Path $jsPath -Encoding UTF8

# Inject a single <script> tag (idempotent)
$html = Get-Content $htmlPath -Raw
$scriptTag = '<script src="./bt-save-rest.js" data-url="' + $SupabaseUrl + '" data-key="' + $SupabaseAnonKey + '"></script>'

if ($html -notlike "*bt-save-rest.js*") {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $scriptTag`n</body>", 'IgnoreCase')
  } else {
    $html += "`n$scriptTag`n"
  }
}

$html | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "Wired save/duplicate logic into $HtmlFile (REST). Open locally and test the Save button."
