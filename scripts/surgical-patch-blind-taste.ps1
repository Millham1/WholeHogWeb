param(
  [string]$Root = ".",
  [string]$HtmlFile = "blind-taste.html",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$ErrorActionPreference = "Stop"
$Root     = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile

if (-not (Test-Path $Root)) { Write-Error "Root not found: $Root"; exit 1 }

# 1) If a backup exists, restore the most recent one (to get your formatting back)
$backup = Get-ChildItem -Path $Root -Filter "blind-taste.backup-*.html" -File |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (Test-Path $htmlPath -and $backup) {
  Copy-Item $backup.FullName $htmlPath -Force
  Write-Host "Restored from backup:" $backup.Name
} elseif (-not (Test-Path $htmlPath)) {
  Write-Error "Cannot find $HtmlFile and no backup present. Aborting."; exit 1
}

# 2) Append small CSS for yellow highlight (idempotent)
$html = Get-Content $htmlPath -Raw
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

# 3) Append inline JS that wires to existing controls (Supabase REST, no CDN) — idempotent
$inline = @'
<script id="blind-taste-inline-rest">
(function(){
  // ===== CONFIG =====
  var SUPABASE_URL = "__SUPABASE_URL__";
  var SUPABASE_KEY = "__SUPABASE_KEY__";
  var REST = SUPABASE_URL.replace(/\/+$/,'') + "/rest/v1";

  // ===== HELPERS =====
  function $(sel){ return document.querySelector(sel); }
  function $all(sel){ return Array.prototype.slice.call(document.querySelectorAll(sel)); }
  function firstSel(arr){ for (var i=0;i<arr.length;i++){ var el=$(arr[i]); if(el) return el; } return null; }

  // Find judge/chip gracefully (your existing IDs/names)
  function getJudgeEl(){ return firstSel(["#judge-select","select[name='judge']","select[name*='judge' i]"]); }
  function getChipEl(){  return firstSel(["#chip-select","select[name='chip']","select[name*='chip' i]"]);  }

  // Score fields: input/select with data-score or .score-field
  function scoreFields(){
    return $all("input[data-score], input.score-field, select[data-score], select.score-field");
  }

  function setHighlight(el,on){
    if (!el) return;
    if (el.tagName === "INPUT" && el.type === "radio") {
      var lbl = el.closest("label"); if (lbl) { lbl.classList.toggle("score-selected", !!on); return; }
    }
    el.classList.toggle("score-selected", !!on);
  }

  function wireHighlighting(){
    // inputs
    $all("input[data-score], input.score-field").forEach(function(inp){
      var upd = function(){
        var v = (inp.value==null ? "" : String(inp.value).trim());
        setHighlight(inp, v !== "" && !Number.isNaN(Number(v)));
      };
      inp.addEventListener("input", upd, {passive:true});
      inp.addEventListener("change", upd, {passive:true});
      upd();
    });
    // selects
    $
