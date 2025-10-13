param(
  [string]$Root = ".",
  [string]$HtmlFile = "blind-taste.html",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$ErrorActionPreference = "Stop"

$Root      = Resolve-Path $Root
$htmlPath  = Join-Path $Root $HtmlFile
$cssPath   = Join-Path $Root "bt-style.css"
$jsPath    = Join-Path $Root "bt-inline.js"

if (!(Test-Path $htmlPath)) { Write-Error "Not found: $htmlPath"; exit 1 }

# 0) Backup current HTML
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $htmlPath (Join-Path $Root ("blind-taste.backup-" + $stamp + ".html")) -Force

# 1) CSS (yellow highlight)
$css = @'
.score-selected { background: yellow !important; color: black !important; }
button[data-score].score-selected { outline: 2px solid #d4b000; }
label.score-selected { background: yellow !important; color: black !important; border-radius: 4px; padding: 2px 4px; }
'@
$css | Set-Content -Path $cssPath -Encoding UTF8

# 2) JS (pure fetch; reads URL/KEY from data-* attributes on the script tag)
$js = @'
(function(){
  var thisScript  = document.currentScript;
  var SUPABASE_URL = (thisScript && thisScript.dataset && thisScript.dataset.url) || "";
  var SUPABASE_KEY = (thisScript && thisScript.dataset && thisScript.dataset.key) || "";
  var REST = SUPABASE_URL.replace(/\/+$/,"") + "/rest/v1";

  function $(s){ return document.querySelector(s); }
  function $all(s){ return Array.prototype.slice.call(document.querySelectorAll(s)); }
  function firstSel(list){ for (var i=0;i<list.length;i++){ var el=$(list[i]); if(el) return el; } return null; }

  function getJudgeEl(){ return firstSel(["#judge-select","select[name='judge']","select[name*='judge' i]"]); }
  function getChipEl(){  return firstSel(["#chip-select","select[name='chip']","select[name*='chip' i]"]); }

  function scoreFields(){ return $all("input[data-score], input.score-field, select[data-score], select.score-field"); }

  function setHighlight(el,on){
    if(!el) return;
    if (el.tagName === "INPUT" && el.type === "radio"){
      var lbl = el.closest("label"); if (lbl) { lbl.classList.toggle("score-selected", !!on); return; }
    }
    el.classList.toggle("score-selected", !!on);
  }

  function wireHighlighting(){
    // inputs
    $all("input[data-score], input.score-field").forEach(function(inp){
      var upd=function(){ var v=(inp.value==null?"":String(inp.value).trim()); setHighlight(inp, v!=="" && !Number.isNaN(Number(v))); };
      inp.addEventListener("input", upd, {passive:true});
      inp.addEventListener("change", upd, {passive:true});
      upd();
    });
    // selects
    $all("select[data-score], select.score-field").forEach(function(sel){
      var upd=function(){ var v=(sel.value==null?"":String(sel.value).trim()); setHighlight(sel, v!=="" && !Number.isNaN(Number(v))); };
      sel.addEventListener("change", upd, {passive:true});
      sel.addEventListener("input",  upd, {passive:true});
      upd();
    });
    // optional radios/buttons support
    $all("input[type='radio'][name*='appear' i], input[type='radio'][name*='tender' i], input[type='radio'][name*='flavor' i]").forEach(function(r){
      var onCh=function(){ setHighlight(r, r.checked); };
      r.addEventListener("change", onCh);
      if (r.checked) setHighlight(r, true);
    });
    $all("button[data-score]").forEach(function(btn){
      btn.addEventListener("click", function(e){
        e.preventDefault();
        setHighlight(btn, true);
        var cat = btn.getAttribute("data-category");
        var val = btn.getAttribute("data-score");
        if (cat){
          var hid = document.querySelector('input[type="hidden"][name="'+cat+'"], input[name="'+cat+'"].score-field, input[name="'+cat+'"][data-score]');
          if (hid){
            hid.value = val;
            hid.dispatchEvent(new Event("input"));
            hid.dispatchEvent(new Event("change"));
          }
        }
      });
    });
  }

  function computeTotal(){
    var t = 0;
    scoreFields().forEach(function(c){
      var v = (c.value==null ? "" : String(c.value).trim());
      var n = Number(v);
      if (!Number.isNaN(n)) t += n;
    });
    var totalEl = firstSel(["#score-total","input[name='score_total']"]);
    if (totalEl) totalEl.value = String(t);
    return t;
  }

  function sHeaders(extra){
    var h = { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY };
    if (extra){ for (var k in extra){ h[k]=extra[k]; } }
    return h;
  }

  async function duplicateExists(judgeId, chipNum){
    var url = REST + "/blind_taste?select=id&judge_id=eq." + encodeURIComponent(judgeId) + "&chip_number=eq." + encodeURIComponent(chipNum) + "&limit=1";
    var res = await fetch(url, { method:"GET", headers: sHeaders({ Accept: "application/json" }) });
    if (!res.ok){ console.error("dup http", res.status); alert("Warning: could not verify duplicates."); return true; }
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

  function clearForm(){
    var form = firstSel(["#blind-taste-form","form[id*='blind' i]","form[id*='taste' i]","form"]);
    if (form && form.reset) form.reset();
    $all(".score-selected").forEach(function(el){ el.classList.remove("score-selected"); });
    computeTotal();
  }

  async function onSave(){
    alert("Saving…");
    var judgeEl = getJudgeEl(), chipEl = getChipEl();
    var judgeId = judgeEl ? String(judgeEl.value||"").trim() : "";
    var chipRaw = chipEl ? String(chipEl.value||"").trim() : "";
    var chipNum = Number(chipRaw);

    if (!judgeId){ alert("Please select a Judge."); return; }
    if (!chipRaw || Number.isNaN(chipNum) || chipNum <= 0){ alert("Please select a valid Chip #."); return; }

    var total = computeTotal();
    var row = { judge_id: judgeId, chip_number: chipNum, score_total: total };

    // map expected names if present
    var appEl = firstSel(["[name='appearance']"]);
    var tenEl = firstSel(["[name='tenderness']"]);
    var flaEl = firstSel(["[name='flavor']"]);
    var app = appEl ? Number(String(appEl.value||"").trim()) : NaN;
    var ten = tenEl ? Number(String(tenEl.value||"").trim()) : NaN;
    var fla = flaEl ? Number(String(flaEl.value||"").trim()) : NaN;
    if (!Number.isNaN(app)) row.score_appearance = app;
    if (!Number.isNaN(ten)) row.score_tenderness  = ten;
    if (!Number.isNaN(fla)) row.score_flavor      = fla;

    if (await duplicateExists(judgeId, chipNum)){
      alert("This Judge + Chip # has already been saved.");
      return;
    }

    var btn = $("#save-blind-taste"); if (btn) btn.disabled = true;
    var result = await insertRow(row);
    if (btn) btn.disabled = false;

    if (result.error){
      console.error("insert error", result.error);
      alert(result.error.message || "Save failed.");
      return;
    }

    alert("Saved! Chip #" + result.data.chip_number + ", Judge " + result.data.judge_id + ".");
    clearForm();
  }

  function wire(){
    wireHighlighting();
    computeTotal();
    var btn = $("#save-blind-taste");
    if (btn){ btn.addEventListener("click", function(e){ e.preventDefault(); onSave(); }); }
    else {
      var form = firstSel(["#blind-taste-form","form"]);
      if (form){ form.addEventListener("submit", function(e){ e.preventDefault(); onSave(); }); }
    }
  }
  document.addEventListener("DOMContentLoaded", wire);
})();
'@
$js | Set-Content -Path $jsPath -Encoding UTF8

# 3) Inject link + script (idempotent)
$html = Get-Content $htmlPath -Raw
$linkTag   = '<link rel="stylesheet" href="./bt-style.css">'
$scriptTag = '<script src="./bt-inline.js" data-url="' + $SupabaseUrl + '" data-key="' + $SupabaseAnonKey + '"></script>'

if ($html -notlike "*$linkTag*") {
  if ($html -match '</head>') { $html = [regex]::Replace($html, '</head>', "`n  $linkTag`n</head>", 'IgnoreCase') }
  else { $html = $linkTag + "`n" + $html }
}
if ($html -notlike "*$scriptTag*") {
  if ($html -match '</body>') { $html = [regex]::Replace($html, '</body>', "`n  $scriptTag`n</body>", 'IgnoreCase') }
  else { $html += "`n$scriptTag`n" }
}

# 4) Save
$html | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "Patched $HtmlFile. Serve the folder and open /$HtmlFile"

