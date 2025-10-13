param(
  [string]$Root = ".",
  [string]$HtmlFile = "index.html",   # change to your blind taste page if different, e.g. "blind-taste.html"
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$Root      = Resolve-Path $Root
$htmlPath  = Join-Path $Root $HtmlFile
$clientJs  = Join-Path $Root "supabaseClient.js"
$saveJs    = Join-Path $Root "saveBlindTaste.js"
$sqlFile   = Join-Path $Root "blind_taste.sql"

# 1) Supabase client (create if missing; overwrite to ensure correct keys)
@"
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient(
  "$SupabaseUrl",
  "$SupabaseAnonKey"
);
"@ | Set-Content -Path $clientJs -Encoding UTF8

# 2) Frontend logic: save + duplicate check + confirm + reset
@'
import { supabase } from "./supabaseClient.js";

/** Helpers to find form elements even if IDs differ slightly */
function $(sel) { return document.querySelector(sel); }
function firstExisting(selectors) {
  for (const s of selectors) { const el = $(s); if (el) return el; }
  return null;
}

function getJudgeValue() {
  // Prefer #judge-select; otherwise first select with id|name containing "judge"
  const el = firstExisting([
    "#judge-select",
    "select[id*='judge' i]",
    "select[name*='judge' i]"
  ]);
  return el ? (el.value || "").trim() : "";
}

function getChipValue() {
  // Prefer #chip-select; otherwise first select with id|name containing "chip"
  const el = firstExisting([
    "#chip-select",
    "select[id*='chip' i]",
    "select[name*='chip' i]"
  ]);
  return el ? (el.value || "").trim() : "";
}

function getScoreInputs() {
  // Any input with data-score OR class "score-field"
  return Array.from(document.querySelectorAll("input[data-score], input.score-field"));
}

function computeTotal() {
  const fields = getScoreInputs();
  let total = 0;
  for (const f of fields) {
    const n = Number(String(f.value ?? "").trim());
    if (!Number.isNaN(n)) total += n;
  }
  const totalEl = firstExisting(["#score-total", "input[name='score_total']"]);
  if (totalEl) totalEl.value = String(total);
  return total;
}

async function duplicateExists(judgeId, chipNum) {
  // HEAD + count=exact is efficient
  const { count, error } = await supabase
    .from("blind_taste")
    .select("id", { count: "exact", head: true })
    .eq("judge_id", judgeId)
    .eq("chip_number", chipNum);

  if (error) {
    console.error("Duplicate check error:", error);
    // Fail-closed: if we cannot verify, warn the user
    alert("Warning: could not verify duplicates. Please try again or contact admin.");
    return true;
  }
  return (count ?? 0) > 0;
}

function clearForm() {
  const form = firstExisting(["#blind-taste-form", "form[id*='blind' i]", "form[id*='taste' i]", "form"]);
  if (form) form.reset();
  // Keep #chip-select refreshed if you’re repopulating it elsewhere
}

async function saveBlindTaste() {
  // Recompute total in case the UI didn’t
  const total = computeTotal();

  const judgeId = getJudgeValue();
  const chipRaw = getChipValue();
  const chipNum = Number(chipRaw);

  if (!judgeId) { alert("Please select a Judge."); return; }
  if (!chipRaw || Number.isNaN(chipNum) || chipNum <= 0) { alert("Please select a valid Chip #."); return; }

  // Grab individual scores (store what exists)
  const scoreFields = getScoreInputs();
  const row = {
    judge_id: judgeId,
    chip_number: chipNum,
    score_total: total
  };
  // Persist individual scores as dedicated columns (appearance, tenderness, flavor) if inputs named that way,
  // else just dump them as score1, score2, ...
  let unnamedIdx = 1;
  for (const f of scoreFields) {
    const name = (f.name || f.id || "").trim();
    const val  = Number(String(f.value ?? "").trim());
    if (Number.isNaN(val)) continue;

    if (/appearance/i.test(name)) row.score_appearance = val;
    else if (/tender/i.test(name)) row.score_tenderness = val;
    else if (/flavor|taste/i.test(name)) row.score_flavor = val;
    else {
      row["score" + unnamedIdx] = val;
      unnamedIdx++;
    }
  }

  // Duplicate guard before insert
  if (await duplicateExists(judgeId, chipNum)) {
    alert("This Judge + Chip # has already been saved. Please choose a different combination.");
    return;
  }

  // Insert
  const btn = firstExisting(["#save-blind-taste", "button[id*='save' i]"]);
  if (btn) btn.disabled = true;

  const { data, error } = await supabase
    .from("blind_taste")
    .insert([row])
    .select()
    .single();

  if (btn) btn.disabled = false;

  if (error) {
    if (error.code === "23505") {
      alert("This Judge + Chip # has already been saved (unique).");
      return;
    }
    console.error("Insert error:", error);
    alert(error.message || "Save failed. Please try again.");
    return;
  }

  // Confirmation and clear
  alert("Blind Taste saved for Chip #" + data.chip_number + " and Judge " + data.judge_id + ".");
  clearForm();
}

// Wire up
document.addEventListener("DOMContentLoaded", () => {
  // Auto-update total if user changes any score
  getScoreInputs().forEach(inp => {
    inp.addEventListener("input", computeTotal, { passive: true });
    inp.addEventListener("change", computeTotal, { passive: true });
  });

  const saveBtn = document.getElementById("save-blind-taste");
  if (saveBtn) {
    saveBtn.addEventListener("click", (e) => {
      e.preventDefault();
      saveBlindTaste();
    });
  } else {
    // Fallback: bind to first submit button in the form
    const form = firstExisting(["#blind-taste-form", "form[id*='blind' i]", "form[id*='taste' i]", "form"]);
    if (form) {
      form.addEventListener("submit", (e) => {
        e.preventDefault();
        saveBlindTaste();
      });
    }
  }
});
'@ | Set-Content -Path $saveJs -Encoding UTF8

# 3) Inject <script> tags (idempotent)
if (-not (Test-Path $htmlPath)) {
  Write-Error "HTML file not found: $htmlPath"
  exit 1
}
$html = Get-Content $htmlPath -Raw
$tagClient = '<script type="module" src="./' + (Split-Path $clientJs -Leaf) + '"></script>'
$tagSave   = '<script type="module" src="./' + (Split-Path $saveJs  -Leaf) + '"></script>'

$needsClient = ($html -notlike "*$tagClient*")
$needsSave   = ($html -notlike "*$tagSave*")

if ($needsClient -or $needsSave) {
  $inj = "`n    " + ($needsClient ? $tagClient : "") + (($needsClient -and $needsSave) ? "`n    " : "") + ($needsSave ? $tagSave : "") + "`n"
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', ($inj + '</body>'), 'IgnoreCase')
  } else {
    $html += $inj
  }
  $html | Set-Content -Path $htmlPath -Encoding UTF8
}

# 4) Create a ready-to-run SQL file for Supabase (schema + RLS + uniqueness)
@"
-- Create table for blind taste records
create table if not exists public.blind_taste (
  id uuid primary key default gen_random_uuid(),
  judge_id text not null,
  chip_number integer not null,
  score_appearance numeric,
  score_tenderness numeric,
  score_flavor numeric,
  score1 numeric,
  score2 numeric,
  score3 numeric,
  score_total numeric not null,
  created_at timestamptz not null default now()
);

-- Uniqueness: a judge may score a chip only once
create unique index if not exists blind_taste_judge_chip_uniq
  on public.blind_taste (judge_id, chip_number);

-- Enable RLS
alter table public.blind_taste enable row level security;

-- Read for everyone (adjust to your needs)
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='blind_taste' and policyname='blind_taste_select_all'
  ) then
    create policy blind_taste_select_all on public.blind_taste
      for select using (true);
  end if;
end $$;

-- Allow inserts from anon (no-login) — change "to anon" to "to authenticated" if you require login
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='blind_taste' and policyname='blind_taste_insert_anon'
  ) then
    create policy blind_taste_insert_anon on public.blind_taste
      for insert to anon with check (true);
  end if;
end $$;
"@ | Set-Content -Path $sqlFile -Encoding UTF8

Write-Host "`nDone."
Write-Host ("Updated: " + (Split-Path $clientJs -Leaf) + ", " + (Split-Path $saveJs -Leaf))
Write-Host ("Injected scripts into: " + (Split-Path $htmlPath -Leaf))
Write-Host ("Created SQL file: " + (Split-Path $sqlFile -Leaf) + "  (open in Supabase SQL editor and run)")
