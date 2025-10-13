param(
  [string]$Root = ".",
  [string]$HtmlFile = "blind-taste.html"
)

$Root     = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile
if (-not (Test-Path $htmlPath)) { Write-Error "Not found: $htmlPath"; exit 1 }

$html = Get-Content $htmlPath -Raw

# single-quoted here-strings to avoid $(...) expansion
$styleBlock = @'
<style id="score-highlight-style">
/* Yellow highlight for selected/filled scores */
.score-selected { background: yellow !important; color: black !important; }

/* If your scores are buttons, make the selection obvious */
button[data-score].score-selected { outline: 2px solid #d4b000; }

/* Radios are tiny—highlight their label if present */
label.score-selected { background: yellow !important; color: black !important; border-radius: 4px; padding: 2px 4px; }
</style>
'@

$scriptBlock = @'
<script id="score-highlight-script">
(function(){
  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }

  function setHighlight(el, on){
    if (!el) return;
    if (el.tagName === "INPUT" && el.type === "radio") {
      var lbl = el.closest("label");
      if (lbl) { lbl.classList.toggle("score-selected", !!on); return; }
    }
    el.classList.toggle("score-selected", !!on);
  }

  function clearGroup(el){
    var cat = el.getAttribute("data-category");
    if (cat){
      $all("[data-category=\""+cat+"\"][data-score]").forEach(function(sib){
        if (sib !== el) setHighlight(sib, false);
      });
      return;
    }
    if (el.name && el.type === "radio"){
      $all("input[type=\"radio\"][name=\""+el.name+"\"]").forEach(function(sib){
        if (sib !== el){ setHighlight(sib, false); }
      });
    }
  }

  function wire(){
    $all("input[data-score], input.score-field").forEach(function(inp){
      var update = function(){
        var v = (inp.value==null ? "" : String(inp.value).trim());
        setHighlight(inp, v !== "" && !Number.isNaN(Number(v)));
      };
      inp.addEventListener("input", update, {passive:true});
      inp.addEventListener("change", update, {passive:true});
      update();
    });

    $all("select[name*=\"appear\" i], select[name*=\"tender\" i], select[name*=\"flavor\" i], select[data-score], select.score-field").forEach(function(sel){
      var update = function(){
        var v = (sel.value==null ? "" : String(sel.value).trim());
        setHighlight(sel, v !== "" && !Number.isNaN(Number(v)));
      };
      sel.addEventListener("change", update, {passive:true});
      sel.addEventListener("input", update, {passive:true});
      update();
    });

    $all("input[type=\"radio\"][name*=\"appear\" i], input[type=\"radio\"][name*=\"tender\" i], input[type=\"radio\"][name*=\"flavor\" i]").forEach(function(r){
      var onChange = function(){
        clearGroup(r);
        setHighlight(r, r.checked);
      };
      r.addEventListener("change", onChange);
      if (r.checked) setHighlight(r, true);
    });

    $all("button[data-score]").forEach(function(btn){
      btn.addEventListener("click", function(ev){
        ev.preventDefault();
        clearGroup(btn);
        setHighlight(btn, true);
        var cat = btn.getAttribute("data-category");
        var val = btn.getAttribute("data-score");
        if (cat){
          var hidden = document.querySelector('input[type="hidden"][name="'+cat+'"], input[name="'+cat+'"].score-field, input[name="'+cat+'"][data-score]');
          if (hidden){
            hidden.value = val;
            hidden.dispatchEvent(new Event("input"));
            hidden.dispatchEvent(new Event("change"));
          }
        }
      });
    });
  }

  document.addEventListener("DOMContentLoaded", wire);
  window.addEventListener("load", wire);
})();
</script>
'@

# inject style if missing
if ($html -notlike '*id="score-highlight-style"*') {
  if ($html -match '</head>') {
    $html = [regex]::Replace($html, '</head>', "`n  $styleBlock`n</head>", 'IgnoreCase')
  } else {
    $html = $styleBlock + "`n" + $html
  }
}

# inject script if missing
if ($html -notlike '*id="score-highlight-script"*') {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', "`n  $scriptBlock`n</body>", 'IgnoreCase')
  } else {
    $html += "`n$scriptBlock`n"
  }
}

$html | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "Done. Score highlighting wired in $HtmlFile (yellow per selected/filled category)."

