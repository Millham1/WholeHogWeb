param(
  [string]$Root = ".",
  [string]$HtmlFile = "index.html",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$Root     = Resolve-Path $Root
$htmlPath = Join-Path $Root $HtmlFile
$clientJs = Join-Path $Root "supabaseClient.js"
$saveJs   = Join-Path $Root "saveBlindTaste.js"

if (-not (Test-Path $htmlPath)) { Write-Error "HTML not found: $htmlPath"; exit 1 }

# 1) Ensure minimal required HTML elements exist (form, judge select, chip select, scores, save button)
$html = Get-Content $htmlPath -Raw

$needed = @()
if ($html -notmatch 'id\s*=\s*["'']blind-taste-form["'']') { $needed += 'form' }
if ($html -notmatch 'id\s*=\s*["'']judge-select["'']')     { $needed += 'judge' }
if ($html -notmatch 'id\s*=\s*["'']chip-select["'']')      { $needed += 'chip' }
if ($html -notmatch 'data-score')                          { $needed += 'scores' }
if ($html -notmatch 'id\s*=\s*["'']save-blind-taste["'']') { $needed += 'button' }

$snippet = @"
<form id="blind-taste-form" style="border:1px solid #ddd;padding:12px;margin:10px 0;">
  <label>Judge
    <select id="judge-select" name="judge-select">
      <option value="" selected disabled>Choose judge…</option>
      <option value="J1">Judge 1</option>
      <option value="J2">Judge 2</option>
    </select>
  </label>
  <label>Chip #
    <select id="chip-select" name="chip-select">
      <option value="" selected disabled>Select chip #</option>
      <!-- your chipSelect.js can populate these; static fallback: -->
      <option value="101">101</option>
      <option value="102">102</option>
    </select>
  </label>
  <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-top:8px;">
    <label>Appearance <input data-score name="appearance" type="number" min="0" step="1"></label>
    <label>Tenderness <input data-score name="tenderness" type="number" min="0" step="1"></label>
    <label>Flavor <input data-score name="flavor" type="number" min="0" step="1"></label>
  </div>
  <label style="margin-top:8px;display:block;">Total
    <input id="score-total" name="score_total" type="number" readonly>
  </label>
  <button id="save-blind-taste" type="button" style="margin-top:10px;">Save Blind Taste</button>
</form>
"@

if ($needed.Count -gt 0) {
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', ("`n  $snippet`n</body>"), 'IgnoreCase')
  } else {
    $html += "`n$snippet`n"
  }
  $html | Set-Content -Path $htmlPath -Encoding UTF8
}

# 2) Write supabase client (overwrite to ensure keys)
@"
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient("$SupabaseUrl", "$SupabaseAnonKey");
"@ | Set-Content -Path $clientJs -Encoding UTF8

# 3) Save logic: logs, alerts, duplicate check, insert, confirm, clear
@'
import { supabase } from "./supabaseClient.js";

const $ = (s) => document.querySelector(s);

function getScores() {
  return Array.from(document.querySelectorAll("input[data-score]"));
}

function computeTotal() {
  let t = 0;
  for (const f of getScores()) {
    const n = Number((f.value ?? "").trim());
    if (!Number.isNaN(n)) t += n;
  }
  const totalEl = $("#score-total");
  if (totalEl) totalEl.value = String(t);
  return t;
}

async function duplicateExists(judgeId, chipNum) {
  const { count, error } = await supabase
    .from("blind_taste")
    .select("id", { count: "exact", head: true })
    .eq("judge_id", judgeId)
    .eq("chip_number", chipNum);
  if (error) {
    console.error("dup check error", error);
    return true; // fail-closed
  }
  return (count ?? 0) > 0;
}

function clearForm() {
  const form = $("#blind-taste-form");
  if (form) form.reset();
  computeTotal();
}

async function onSave() {
  // Immediate visible feedback so we know handler is firing:
  console.log("[BlindTaste] Save clicked");
  alert("Saving… (you will see OK or a warning next)");

  const judgeId = ($("#judge-select")?.value ?? "").trim();
  const chipRaw = ($("#chip-select")?.value ?? "").trim();
  const chipNum = Number(chipRaw);

  if (!judgeId) { alert("Please choose a Judge."); return; }
  if (!chipRaw || Number.isNaN(chipNum) || chipNum <= 0) { alert("Please choose a valid Chip #."); return; }

  const total = computeTotal();

  const row = {
    judge_id: judgeId,
    chip_number: chipNum,
    score_total: total
  };
  for (const f of getScores()) {
    const name = (f.name || f.id || "").toLowerCase();
    const val  = Number((f.value ?? "").trim());
    if (Number.isNaN(val)) continue;
    if (name.includes("appear")) row.score_appearance = val;
    else if (name.includes("tender")) row.score_tenderness = val;
    else if (name.includes("flavor") || name.includes("taste")) row.score_flavor = val;
  }

  if (await duplicateExists(judgeId, chipNum)) {
    alert("Warning: this Judge + Chip # was already saved.");
    return;
  }

  const btn = $("#save-blind-taste");
  if (btn) btn.disabled = true;

  const { data, error } = await supabase
    .from("blind_taste")
    .insert([row])
    .select()
    .single();

  if (btn) btn.disabled = false;

  if (error) {
    console.error("insert error", error);
    if (error.code === "23505") {
      alert("Warning: duplicate Judge + Chip #.");
    } else {
      alert(error.message || "Save failed.");
    }
    return;
  }

  alert(`Saved! Chip #${data.chip_number}, Judge ${data.judge_id}.`);
  clearForm();
}

document.addEventListener("DOMContentLoaded", () => {
  // live total
  getScores().forEach(inp => {
    inp.addEventListener("input", computeTotal, { passive: true });
    inp.addEventListener("change", computeTotal, { passive: true });
  });
  computeTotal();

  const btn = document.getElementById("save-blind-taste");
  if (btn) btn.addEventListener("click", (e)=>{ e.preventDefault(); onSave(); });
});
'@ | Set-Content -Path $saveJs -Encoding UTF8

# 4) Inject script tags (module) at end of body if missing
$html = Get-Content $htmlPath -Raw
$tagClient = '<script type="module" src="./' + (Split-Path $clientJs -Leaf) + '"></script>'
$tagSave   = '<script type="module" src="./' + (Split-Path $saveJs  -Leaf) + '"></script>'

$needsClient = ($html -notlike "*$tagClient*")
$needsSave   = ($html -notlike "*$tagSave*")

if ($needsClient -or $needsSave) {
  $inj = "`n  " + ($needsClient ? $tagClient : "") + (($needsClient -and $needsSave) ? "`n  " : "") + ($needsSave ? $tagSave : "") + "`n"
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', ($inj + '</body>'), 'IgnoreCase')
  } else {
    $html += $inj
  }
  $html | Set-Content -Path $htmlPath -Encoding UTF8
}

Write-Host "Done. Files updated:"
Write-Host " - $HtmlFile (ensured required elements)"
Write-Host " - $(Split-Path $clientJs -Leaf)"
Write-Host " - $(Split-Path $saveJs -Leaf)"
Write-Host "`nServe over HTTP (not file://), open the page, click Save. You should see a 'Saving…' alert first, then OK or a warning."
