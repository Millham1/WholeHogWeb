param(
  [string]$Root = ".",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

# --- setup paths ---
$Root = Resolve-Path $Root
$indexPath     = Join-Path $Root "index.html"
$supabasePath  = Join-Path $Root "supabaseClient.js"
$addTeamPath   = Join-Path $Root "addTeam.js"

# --- file contents (kept template-literal free for PS safety) ---
$supabaseContent = @'
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  "__SUPABASE_URL__",
  "__SUPABASE_ANON_KEY__"
);
'@

$addTeamContent = @'
import { supabase } from './supabaseClient.js';

export async function addTeam(args) {
  const team_name = (args && args.team_name ? String(args.team_name).trim() : "");
  const chip_raw  = (args && args.chip_number != null ? String(args.chip_number).trim() : "");
  const n = Number(chip_raw);

  if (!team_name) throw new Error("Team name is required.");
  if (!Number.isInteger(n) || n <= 0) throw new Error("Chip number must be a positive integer.");

  const res = await supabase
    .from("teams")
    .insert([{ team_name: team_name, chip_number: n }])
    .select()
    .single();

  if (res && res.error) {
    if (res.error.code === "23505") throw new Error("That chip number is already registered.");
    throw new Error(res.error.message || "Insert failed.");
  }
  return res.data;
}

document.addEventListener("DOMContentLoaded", function () {
  var form = document.getElementById("add-team-form");
  if (!form) return;

  form.addEventListener("submit", async function (ev) {
    ev.preventDefault();
    var team_name   = form.elements["team_name"] ? form.elements["team_name"].value : "";
    var chip_number = form.elements["chip_number"] ? form.elements["chip_number"].value : "";

    try {
      var inserted = await addTeam({ team_name: team_name, chip_number: chip_number });
      alert("Added " + inserted.team_name + " (Chip #" + inserted.chip_number + ")");
      form.reset();
    } catch (err) {
      alert(err && err.message ? err.message : "Failed to add team");
      console.error(err);
    }
  }, { passive: false });
});
'@

$minimalIndex = @'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <title>Teams - Add</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 2rem; }
      form { display: grid; gap: 0.5rem; max-width: 420px; }
      label { display: grid; gap: 0.25rem; }
      input { padding: 0.5rem; }
      button { padding: 0.6rem 0.9rem; }
    </style>
  </head>
  <body>
    <h1>Add Team</h1>
    <form id="add-team-form">
      <label>
        Team name
        <input name="team_name" required />
      </label>
      <label>
        Chip #
        <input name="chip_number" inputmode="numeric" required />
      </label>
      <button type="submit">Add Team</button>
    </form>

    <!-- scripts injected before </body> -->
  </body>
</html>
'@

function Write-File($Path, $Content) {
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $Content | Set-Content -Path $Path -Encoding UTF8
}

function Write-IfMissing($Path, $Content) {
  if (Test-Path $Path) {
    Write-Host "[skip] exists:" (Split-Path $Path -Leaf)
  } else {
    Write-File -Path $Path -Content $Content
    Write-Host "[created]" (Split-Path $Path -Leaf)
  }
}

# --- create or update JS files ---
$supabaseFinal = $supabaseContent.Replace("__SUPABASE_URL__", $SupabaseUrl).Replace("__SUPABASE_ANON_KEY__", $SupabaseAnonKey)
Write-File -Path $supabasePath -Content $supabaseFinal
Write-Host "[updated]" (Split-Path $supabasePath -Leaf)

Write-File -Path $addTeamPath -Content $addTeamContent
Write-Host "[updated]" (Split-Path $addTeamPath -Leaf)

# --- ensure index.html exists ---
Write-IfMissing -Path $indexPath -Content $minimalIndex

# --- inject script tags (idempotent) ---
$html = Get-Content $indexPath -Raw
$tagSupabase = '<script type="module" src="./' + (Split-Path $supabasePath -Leaf) + '"></script>'
$tagAddTeam  = '<script type="module" src="./' + (Split-Path $addTeamPath  -Leaf) + '"></script>'

if ($html -notlike "*$tagSupabase*" -or $html -notlike "*$tagAddTeam*") {
  if ($html -match '</body>') {
    $inj = "`n    $tagSupabase`n    $tagAddTeam`n"
    $html = [regex]::Replace($html, '</body>', ($inj + '</body>'), 'IgnoreCase')
  } else {
    $html += "`n$tagSupabase`n$tagAddTeam`n"
  }
  Write-File -Path $indexPath -Content $html
  Write-Host "[updated] injected script tags into index.html"
} else {
  Write-Host "[skip] index.html already has script tags"
}

Write-Host "`nDone."
Write-Host "Next steps:"
Write-Host " 1) Serve this folder over HTTP (not file://). Example:  npx http-server ."
Write-Host " 2) Open the shown http://localhost:... URL and use the Add Team form."


