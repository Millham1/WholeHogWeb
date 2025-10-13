param(
  [string]$Root = ".",
  [string]$HtmlFile = "blind-taste.html",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$ErrorActionPreference = "Stop"

$Root     = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile
if (-not (Test-Path $htmlPath)) { Write-Error "Not found: $htmlPath"; exit 1 }

$html = Get-Content $htmlPath -Raw

# Ensure Save button exists
if ($html -notmatch 'id\s*=\s*["'']save-blind-taste["'']') {
  $btnHtml = '<button id="save-blind-taste" type="button">Save Blind Taste</button>'
  if ($html -match '</form>') {
    $html = [regex]::Replace($html, '</form>', "`n  $btnHtml`n</form>", 'IgnoreCase')
  } elseif ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $btnHtml`n</body>", 'IgnoreCase')
  } else { $html += "`n$btnHtml`n" }
}

# Style: yellow highlight for selected scores
$styleBlock = @'
<style id="score-highlight-style">
  .score-selected { background: yellow !important; color: black !important; }
  button[data-score].score-selected { outline: 2px solid #d4b000; }
  label.score-selected { background: yellow !important; color: black !important; border-radius: 4px; padding: 2px 4px; }
</style>
'@
if ($html -notlike '*id="score-highlight-style"*') {
  if ($html -match '</head>') {
    $html = [regex]::Replace($html, '</head>', "`n  $styleBlock`n</head>", 'IgnoreCase')
  } else { $html = $styleBlock + "`n" + $html }
}

# Inline JS (pure fetch; no external CDN)
$inline = @'
<script id="blind-taste-inline-rest">
(function(){
  // ========== CONFIG ==========
  var SUPABASE_URL = "__SUPABASE_URL__";
  var SUPABASE_KEY = "__SUPABASE_KEY__";
  var REST = SUPABASE_URL.replace(/\/+$/,'') + "/rest/v1";

  // ========== HELPERS ==========
  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }
  function firstSel(arr){ for (var i=0;i<arr.length;i++){ var el=$(arr[i]); if (el) return el; } return null; }

  function getJudge(){ var el = firstSel(["#judge-select","select[name='judge']","select[name*='judge' i]"]); return el ? String(el.value||"").trim() : ""; }
  function getChip(){  var el = firstSel(["#chip-select","select[name='chip']","select[name*='chip' i]"]);   return el ? String(el.value||"").trim() : ""; }

  function scoreControls(){ return $all(
    "input[data-score], input.score-field, input[type='number'][name*='appear' i], input[type='number'][name*='tender' i], input[type='number'][name*='flavor' i]," +
    "select[data-score], select.score-field, select[name*='appear' i], select[name*='tender' i], select[name*='flavor' i]," +
    "input[type='radio'][name*='appear' i], input[type='radio'][name*='tender' i], input[type='radio'][name*='flavor' i]," +
    "button[data-score]"
  );}

  function setHighlight(el,on){
    if (!el) return;
    if (el.tagName==="INPUT" && el.type==="radio"){
      var lbl = el.closest("label"); if (lbl) { lbl.classList.toggle("score-selected", !!on); return; }
    }
    el.classList.toggle("score-selected", !!on);
  }
  function clearGroup(el){
    var cat = el.getAttribute("data-category");
    if (cat){
      $all('[data-category="'+cat+'"][data-score]').forEach(function(sib){ if (sib!==el) setHighlight(sib,false); });
      return;
    }
    if (el.name && el.type==="radio"){
      $all('input[type="radio"][name="'+el.name+'"]').forEach(function(sib){ if (sib!==el) setHighlight(sib,false); });
    }
  }

  function wireHighlighting(){
    // number inputs
    $all("input[data-score], input.score-field, input[type='number'][name*='appear' i], input[type='number'][name*='tender' i], input[type='number'][name*='flavor' i]").forEach(function(inp){
      var upd = function(){ var v=(inp.value==null?"":String(inp.value).trim()); setHighlight(inp, v!=="" && !Number.isNaN(Number(v))); };
      inp.addEventListener("input", upd, {passive:true}); inp.addEventListener("change", upd, {passive:true}); upd();
    });
    // selects
    $all("select[data-score], select.score-field, select[name*='appear' i], select[name*='tender' i], select[name*='flavor' i]").forEach(function(sel){
      var upd = function(){ var v=(sel.value==null?"":String(sel.value).trim()); setHighlight(sel, v!=="" && !Number.isNaN(Number(v))); };
      sel.addEventListener("change", upd, {passive:true}); sel.addEventListener("input", upd, {passive:true}); upd();
    });
    // radios
    $all("input[type='radio'][name*='appear' i], input[type='radio'][name*='tender' i], input[type='radio'][name*='flavor' i]").forEach(function(r){
      var onChange = function(){ clearGroup(r); setHighlight(r, r.checked); };
      r.addEventListener("change", onChange); if (r.checked) setHighlight(r,true);
    });
    // buttons with data-score
    $all("button[data-score]").forEach(function(btn){
      btn.addEventListener("click", function(ev){
        ev.preventDefault(); clearGroup(btn); setHighlight(btn,true);
        var cat=btn.getAttribute("data-category"), val=btn.getAttribute("data-score");
        if (cat){
          var hidden = document.querySelector('input[type="hidden"][name="'+cat+'"], input[name="'+cat+'"].score-field, input[name="'+cat+'"][data-score]');
          if (hidden){ hidden.value=val; hidden.dispatchEvent(new Event("input")); hidden.dispatchEvent(new Event("change")); }
        }
      });
    });
  }

  function computeTotal(){
    var total = 0;
    scoreControls().forEach(function(c){
      var v = (c.value==null ? "" : String(c.value).trim());
      var n = Number(v); if (!Number.isNaN(n)) total += n;
    });
    var totalEl = firstSel(["#score-total","input[name='score_total']"]);
    if (totalEl) totalEl.value = String(total);
    return total;
  }

  // ========== REST to Supabase ==========
  function sHeaders(extra){
    var h = { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + SUPABASE_KEY };
    if (extra) { for (var k in extra) h[k]=extra[k]; }
    return h;
  }

  async function duplicateExists(judgeId, chipNum){
    var url = REST + '/blind_taste?select=id&judge_id=eq.' + encodeURIComponent(judgeId) + '&chip_number=eq.' + encodeURIComponent(chipNum) + '&limit=1';
    var res = await fetch(url, { method:'GET', headers: sHeaders({ 'Accept': 'application/json' }) });
    if (!res.ok){ console.error('dup check http', res.status); alert('Warning: could not verify duplicates.'); return true; }
    var rows = await res.json();
    return Array.isArray(rows) && rows.length > 0;
  }

  async function insertRow(row){
    var res = await fetch(REST + '/blind_taste', {
      method: 'POST',
      headers: sHeaders({ 'Content-Type': 'application/json', 'Prefer': 'return=representation' }),
      body: JSON.stringify(row)
    });
    if (!res.ok){
      var msg = await res.text().catch(function(){ return ''; });
      return { error: { message: msg || ('HTTP ' + res.status) } };
    }
    var data = await res.json();
    return { data: Array.isArray(data) ? data[0] : data };
  }

  function clearForm(){
    var form = firstSel(["#blind-taste-form","form[id*='blind' i]","form[id*='taste' i]","form"]);
    if (form && form.reset) form.reset();
    scoreControls().forEach(function(c){ setHighlight(c,false); });
    computeTotal();
  }

  async function onSave(){
    alert("Saving…");

    var judgeId = getJudge();
    var chipRaw = getChip();
    var chipNum = Number(chipRaw);

    if (!judgeId){ alert("Please select a Judge."); return; }
    if (!chipRaw || Number.isNaN(chipNum) || chipNum <= 0){ alert("Please select a valid Chip #."); return; }

    var total = computeTotal();
    var row = { judge_id: judgeId, chip_number: chipNum, score_total: total };

    var extras = 1;
    scoreControls().forEach(function(c){
      var name = (c.name || c.id || "").toLowerCase();
      var v = Number((c.value==null ? "" : String(c.value).trim()));
      if (Number.isNaN(v)) return;
      if (/appear/.test(name)) row.score_appearance = v;
      else if (/tender/.test(name)) row.score_tenderness = v;
      else if (/flavor|taste/.test(name)) row.score_flavor = v;
      else { row["score"+(extras++)] = v; }
    });

    if (await duplicateExists(judgeId, chipNum)){
      alert("This Judge + Chip # has already been saved.");
      return;
    }

    var btn = document.getElementById("save-blind-taste"); if (btn) btn.disabled = true;
    var result = await insertRow(row);
    if (btn) btn.disabled = false;

    if (result.error){
      console.error('insert error', result.error);
      // If RLS or key wrong, you’ll see it here
      alert(result.error.message || 'Save failed.');
      return;
    }

    alert("Saved! Chip #"+result.data.chip_number+", Judge "+result.data.judge_id+".");
    clearForm();
  }

  function wire(){
    wireHighlighting(); computeTotal();
    var btn = document.getElementById("save-blind-taste");
    if (btn){ btn.addEventListener("click", function(e){ e.preventDefault(); onSave(); }); }
    else {
      var form = firstSel(["#blind-taste-form","form"]);
      if (form){ form.addEventListener("submit", function(e){ e.preventDefault(); onSave(); }); }
    }
  }
  document.addEventListener("DOMContentLoaded", wire);
})();
</script>
'@

# Replace placeholders literally (no PowerShell interpolation inside single-quoted here-string)
$inline = $inline.Replace('__SUPABASE_URL__', $SupabaseUrl).Replace('__SUPABASE_KEY__', $SupabaseAnonKey)

# Inject inline block once
if ($html -notlike '*id="blind-taste-inline-rest"*') {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $inline`n</body>", 'IgnoreCase')
  } else { $html += "`n$inline`n" }
}

# Save file
$html | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "Patched $HtmlFile for REST (no external CDN needed). Open via: http://localhost:8080/$HtmlFile"
