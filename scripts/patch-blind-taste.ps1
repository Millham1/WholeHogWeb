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

# Load HTML
$html = Get-Content $htmlPath -Raw

# 0) Ensure a Save button with id="save-blind-taste"
if ($html -notmatch 'id\s*=\s*["'']save-blind-taste["'']') {
  $btnHtml = '<button id="save-blind-taste" type="button">Save Blind Taste</button>'
  if ($html -match '</form>') {
    $html = [regex]::Replace($html, '</form>', "`n  $btnHtml`n</form>", 'IgnoreCase')
  } elseif ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $btnHtml`n</body>", 'IgnoreCase')
  } else {
    $html += "`n$btnHtml`n"
  }
}

# 1) Supabase CDN <script> (non-module)
$cdnTag = '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
if ($html -notlike "*$cdnTag*") {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $cdnTag`n</body>", 'IgnoreCase')
  } else {
    $html += "`n$cdnTag`n"
  }
}

# 2) Yellow highlight styling
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
  } else {
    $html = $styleBlock + "`n" + $html
  }
}

# 3) Inline JS (single-quoted here-string, placeholders replaced after)
$inline = @'
<script id="blind-taste-inline">
(function(){
  var SUPABASE_URL = "__SUPABASE_URL__";
  var SUPABASE_KEY = "__SUPABASE_KEY__";
  if (!window.supabase || !window.supabase.createClient) { alert("Supabase failed to load."); return; }
  var sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }
  function firstSel(list){ for (var i=0;i<list.length;i++){ var el=$(list[i]); if(el) return el; } return null; }

  function getJudge(){ var el=firstSel(["#judge-select","select[name='judge']","select[name*='judge' i]"]); return el?String(el.value||"").trim():""; }
  function getChip(){  var el=firstSel(["#chip-select","select[name='chip']","select[name*='chip' i]"]);   return el?String(el.value||"").trim():""; }

  function scoreControls(){ return $all(
    "input[data-score], input.score-field, input[type='number'][name*='appear' i], input[type='number'][name*='tender' i], input[type='number'][name*='flavor' i]," +
    "select[data-score], select.score-field, select[name*='appear' i], select[name*='tender' i], select[name*='flavor' i]," +
    "input[type='radio'][name*='appear' i], input[type='radio'][name*='tender' i], input[type='radio'][name*='flavor' i]," +
    "button[data-score]"
  );}

  function setHighlight(el,on){
    if(!el) return;
    if (el.tagName==="INPUT" && el.type==="radio"){
      var lbl=el.closest("label"); if(lbl){ lbl.classList.toggle("score-selected",!!on); return; }
    }
    el.classList.toggle("score-selected", !!on);
  }

  function clearGroup(el){
    var cat = el.getAttribute("data-category");
    if (cat){
      $all('[data-category="'+cat+'"][data-score]').forEach(function(sib){ if(sib!==el) setHighlight(sib,false); });
      return;
    }
    if (el.name && el.type==="radio"){
      $all('input[type="radio"][name="'+el.name+'"]').forEach(function(sib){ if(sib!==el) setHighlight(sib,false); });
    }
  }

  function wireHighlighting(){
    // number inputs
    $all("input[data-score], input.score-field, input[type='number'][name*='appear' i], input[type='number'][name*='tender' i], input[type='number'][name*='flavor' i]")
      .forEach(function(inp){
        var upd=function(){ var v=(inp.value==null?"":String(inp.value).trim()); setHighlight(inp, v!=="" && !Number.isNaN(Number(v))); };
        inp.addEventListener("input",upd,{passive:true}); inp.addEventListener("change",upd,{passive:true}); upd();
      });
    // selects
    $all("select[data-score], select.score-field, select[name*='appear' i], select[name*='tender' i], select[name*='flavor' i]")
      .forEach(function(sel){
        var upd=function(){ var v=(sel.value==null?"":String(sel.value).trim()); setHighlight(sel, v!=="" && !Number.isNaN(Number(v))); };
        sel.addEventListener("change",upd,{passive:true}); sel.addEventListener("input",upd,{passive:true}); upd();
      });
    // radios
    $all("input[type='radio'][name*='appear' i], input[type='radio'][name*='tender' i], input[type='radio'][name*='flavor' i]")
      .forEach(function(r){ var onChange=function(){ clearGroup(r); setHighlight(r, r.checked); }; r.addEventListener("change",onChange); if(r.checked) setHighlight(r,true); });
    // buttons with data-score
    $all("button[data-score]").forEach(function(btn){
      btn.addEventListener("click",function(ev){
        ev.preventDefault(); clearGroup(btn); setHighlight(btn,true);
        var cat=btn.getAttribute("data-category"), val=btn.getAttribute("data-score");
        if(cat){
          var hidden=document.querySelector('input[type="hidden"][name="'+cat+'"], input[name="'+cat+'"].score-field, input[name="'+cat+'"][data-score]');
          if(hidden){ hidden.value=val; hidden.dispatchEvent(new Event("input")); hidden.dispatchEvent(new Event("change")); }
        }
      });
    });
  }

  function computeTotal(){
    var total=0;
    scoreControls().forEach(function(c){ var v=(c.value==null?"":String(c.value).trim()), n=Number(v); if(!Number.isNaN(n)) total+=n; });
    var totalEl = firstSel(["#score-total","input[name='score_total']"]); if(totalEl) totalEl.value=String(total);
    return total;
  }

  async function duplicateExists(judgeId, chipNum){
    var res = await sb.from("blind_taste").select("id", {count:"exact", head:true})
      .eq("judge_id", judgeId).eq("chip_number", chipNum);
    if(res.error){ console.error("Duplicate check error:", res.error); alert("Warning: could not verify duplicates."); return true; }
    return (res.count||0)>0;
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
    if(!judgeId){ alert("Please select a Judge."); return; }
    if(!chipRaw || Number.isNaN(chipNum) || chipNum<=0){ alert("Please select a valid Chip #."); return; }

    var total = computeTotal();
    var row = { judge_id: judgeId, chip_number: chipNum, score_total: total };

    var extras=1;
    scoreControls().forEach(function(c){
      var name=(c.name||c.id||"").toLowerCase();
      var v=Number((c.value==null?"":String(c.value).trim()));
      if(Number.isNaN(v)) return;
      if(/appear/.test(name)) row.score_appearance=v;
      else if(/tender/.test(name)) row.score_tenderness=v;
      else if(/flavor|taste/.test(name)) row.score_flavor=v;
      else { row["score"+(extras++)]=v; }
    });

    if (await duplicateExists(judgeId, chipNum)){ alert("This Judge + Chip # has already been saved."); return; }

    var btn = document.getElementById("save-blind-taste"); if(btn) btn.disabled=true;
    var res = await sb.from("blind_taste").insert([row]).select().single();
    if(btn) btn.disabled=false;

    if(res.error){
      console.error("Insert error:", res.error);
      alert(res.error.code==="23505" ? "Duplicate Judge + Chip #." : (res.error.message || "Save failed."));
      return;
    }
    alert("Saved! Chip #"+res.data.chip_number+", Judge "+res.data.judge_id+".");
    clearForm();
  }

  function wire(){
    wireHighlighting(); computeTotal();
    var btn = document.getElementById("save-blind-taste");
    if (btn) { btn.addEventListener("click", function(e){ e.preventDefault(); onSave(); }); }
    else {
      var form = firstSel(["#blind-taste-form","form"]); if(form){ form.addEventListener("submit", function(e){ e.preventDefault(); onSave(); }); }
    }
  }
  document.addEventListener("DOMContentLoaded", wire);
})();
</script>
'@

# Replace placeholders literally
$inline = $inline.Replace('__SUPABASE_URL__', $SupabaseUrl).Replace('__SUPABASE_KEY__', $SupabaseAnonKey)

# Inject inline block once
if ($html -notlike '*id="blind-taste-inline"*') {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $inline`n</body>", 'IgnoreCase')
  } else {
    $html += "`n$inline`n"
  }
}

# Save file
$html | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "Patched $HtmlFile. Open via a local server: http://localhost:8080/$HtmlFile"



