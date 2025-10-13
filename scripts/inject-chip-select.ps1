param(
  [string]$Root = ".",
  [string]$SupabaseUrl = "https://YOUR-PROJECT.supabase.co",
  [string]$SupabaseAnonKey = "YOUR-ANON-KEY"
)

$Root = Resolve-Path $Root
$indexPath    = Join-Path $Root "index.html"
$clientPath   = Join-Path $Root "supabaseClient.js"
$chipsJsPath  = Join-Path $Root "chipSelect.js"

# Create supabase client if missing
if (-not (Test-Path $clientPath)) {
  @"
import { createClient } from '@supabase/supabase-js';
export const supabase = createClient(
  "$SupabaseUrl",
  "$SupabaseAnonKey"
);
"@ | Set-Content -Path $clientPath -Encoding UTF8
  Write-Host "[created] supabaseClient.js"
} else {
  Write-Host "[skip] supabaseClient.js exists"
}

# Create chipSelect.js (populates #chip-select with numbers ONLY)
@"
import { supabase } from './supabaseClient.js';

async function loadChips() {
  const { data, error } = await supabase
    .from('teams')
    .select('chip_number')
    .order('chip_number', { ascending: true });

  if (error) {
    console.error('Load chips error:', error);
    return [];
  }
  return data ?? [];
}

export async function populateChipSelect() {
  const sel = document.getElementById('chip-select');
  if (!sel) return;

  const chips = await loadChips();

  sel.innerHTML = '';
  const ph = document.createElement('option');
  ph.value = '';
  ph.textContent = 'Select chip #';
  ph.disabled = true;
  ph.selected = true;
  sel.appendChild(ph);

  for (const row of chips) {
    if (row?.chip_number == null) continue;
    const n = row.chip_number;
    const opt = document.createElement('option');
    opt.value = String(n);
    opt.textContent = String(n); // label shows ONLY the number
    sel.appendChild(opt);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  populateChipSelect();
});
"@ | Set-Content -Path $chipsJsPath -Encoding UTF8
Write-Host "[created/updated] chipSelect.js"

# Ensure index.html exists (minimal if missing)
if (-not (Test-Path $indexPath)) {
  @"
<!doctype html>
<html><head><meta charset='utf-8'><title>BBQ</title></head>
<body>
  <label>Chip #:
    <select id='chip-select' name='chip-select'></select>
  </label>
</body></html>
"@ | Set-Content -Path $indexPath -Encoding UTF8
  Write-Host "[created] index.html (minimal)"
} else {
  Write-Host "[skip] index.html exists"
}

# Inject script tags idempotently
$html = Get-Content $indexPath -Raw

$tagClient = '<script type="module" src="./' + (Split-Path $clientPath -Leaf) + '"></script>'
$tagChips  = '<script type="module" src="./' + (Split-Path $chipsJsPath -Leaf) + '"></script>'

$needsClient = ($html -notlike "*$tagClient*")
$needsChips  = ($html -notlike "*$tagChips*")

if ($needsClient -or $needsChips) {
  $inj = "`n    " + ($needsClient ? $tagClient : "") + (($needsClient -and $needsChips) ? "`n    " : "") + ($needsChips ? $tagChips : "") + "`n"
  if ($html -match '</body>') {
    $html = [regex]::Replace($html, '</body>', ($inj + '</body>'), 'IgnoreCase')
  } else {
    $html += $inj
  }
  $html | Set-Content -Path $indexPath -Encoding UTF8
  Write-Host "[updated] injected script tags into index.html"
} else {
  Write-Host "[skip] script tags already present"
}

Write-Host "`nDone. Serve the folder over HTTP (e.g., npx http-server .) and the chip dropdown will show numbers only."
