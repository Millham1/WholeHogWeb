param(
  [string]$Root = "."
)

$Root = Resolve-Path $Root
$indexPath = Join-Path $Root "index.html"
$supabasePath = Join-Path $Root "supabaseClient.js"
$addTeamPath = Join-Path $Root "addTeam.js"

$supabaseContent = @'
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  import.meta?.env?.VITE_SUPABASE_URL ?? 'https://YOUR-PROJECT.supabase.co',
  import.meta?.env?.VITE_SUPABASE_ANON_KEY ?? 'YOUR-ANON-KEY'
);
'@

$addTeamContent = @'
import { supabase } from './supabaseClient.js';

export async function addTeam({ team_name, chip_number }) {
  const n = Number(chip_number);
  if (!team_name?.trim()) throw new Error('Team name is required.');
  if (!Number.isInteger(n) || n <= 0) throw new Error('Chip number must be a positive integer.');

  const { data, error } = await supabase
    .from('teams')
    .insert([{ team_name: team_name.trim(), chip_number: n }])
    .select()
    .single();

  if (error?.code === '23505') throw new Error(`Chip #${n} is already registered.`);
  if (error) throw error;
  return data;
}

document.addEventListener('DOMContentLoaded', () => {
  $form = document.getElementById('add-team-form');
  if (!$form) return;

  $form.addEventListener('submit', async (ev) => {
    ev.preventDefault();
    const team_name = $form.elements['team_name']?.value ?? '';
    const chip_number = $form.elements['chip_number']?.value ?? '';

    try {
      const inserted = await addTeam({ team_name, chip_number });
      alert(`Added ${inserted.team_name} (Chip #${inserted.chip_number})`);
      $form.reset();
    } catch (err) {
      alert(err.message || 'Failed to add team');
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
    <title>Teams - Test</title>
  </head>
  <body>
    <h1>Teams - Add</h1>
    <form id="add-team-form">
      <label>Team name: <input name="team_name" required /></label>
      <label>Chip #: <input name="chip_number" required /></label>
      <button type="submit">Add Team</button>
    </form>

    <!-- script tags will be injected here -->
  </body>
</html>
'@

function Write-IfMissing($path, $content) {
  if (Test-Path $path) {
    Write-Host "[skip] exists:" (Split-Path $path -Leaf)
  } else {
    $content | Out-File -FilePath $path -Encoding utf8
    Write-Host "[created]" (Split-Path $path -Leaf)
  }
}

Write-IfMissing -path $supabasePath -content $supabaseContent
Write-IfMissing -path $addTeamPath -content $addTeamContent

if (-not (Test-Path $indexPath)) {
  $minimalIndex | Out-File -FilePath $indexPath -Encoding utf8
  Write-Host "[created] index.html (minimal)"
}

# inject tags if not present
$html = Get-Content $indexPath -Raw
$tagSupabase = '<script type="module" src="./' + (Split-Path $supabasePath -Leaf) + '"></script>'
$tagAddTeam = '<script type="module" src="./' + (Split-Path $addTeamPath -Leaf) + '"></script>'

if ($html -like "*$tagSupabase*" -and $html -like "*$tagAddTeam*") {
  Write-Host "[skip] index.html already contains script tags"
} else {
  if ($html -match '</body>') {
    $html = $html -replace '(?i)</body>', "`n    $tagSupabase`n    $tagAddTeam`n</body>"
  } else {
    $html += "`n$tagSupabase`n$tagAddTeam`n"
  }
  $html | Out-File -FilePath $indexPath -Encoding utf8
  Write-Host "[updated] injected script tags into index.html"
}

Write-Host "`nDone."
Write-Host " - Edit supabaseClient.js and replace placeholders with your project URL & anon key."
Write-Host " - Serve the folder with a local HTTP server (do NOT open via file://). Example:"
Write-Host "     npx http-server ."

