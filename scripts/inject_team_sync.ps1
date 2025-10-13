# inject_team_sync.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# 1) Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# 2) Read
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# 3) Remove any previous injection of this sync block
$rxOld = '(?is)<!--\s*WH_SYNC_START\s*-->[\s\S]*?<!--\s*WH_SYNC_END\s*-->'
$html = [regex]::Replace($html, $rxOld, '')

# 4) Build the script snippet (with markers)
$snippet = @'
<!-- WH_SYNC_START -->
<script>
(function () {
  document.addEventListener('DOMContentLoaded', () => {
    const supa = window.supabase;
    if (!supa) {
      console.warn('Supabase client not found. Ensure supabase-config.js is loaded before this script.');
      return;
    }

    const els = {
      team: document.getElementById('team') || document.getElementById('teamName'),
      teamSel: document.getElementById('teamSel'),
      chip: document.getElementById('chip'),
      legion: document.getElementById('legionFlag'),
      sons: document.getElementById('sonsFlag'),
      site: document.getElementById('site') || document.getElementById('site_number') || document.getElementById('siteNo') || document.getElementById('siteNum'),
    };

    async function fetchByChip(chip) {
      const { data, error } = await supa
        .from('teams')
        .select('team_name, chip_number, site_number, is_legion, is_sons')
        .eq('chip_number', chip)
        .limit(1);
      if (error) { console.warn('fetchByChip error:', error); return null; }
      return (data && data[0]) || null;
    }

    async function fetchByName(name) {
      const { data, error } = await supa
        .from('teams')
        .select('team_name, chip_number, site_number, is_legion, is_sons')
        .ilike('team_name', name)
        .limit(1);
      if (error) { console.warn('fetchByName error:', error); return null; }
      return (data && data[0]) || null;
    }

    function applyTeam(row) {
      if (!row) return;
      if (els.team && row.team_name) els.team.value = row.team_name;
      if (els.chip && row.chip_number) els.chip.value = row.chip_number;
      if (els.site && (row.site_number ?? '') !== '') els.site.value = row.site_number;
      if (els.legion) els.legion.checked = !!row.is_legion;
      if (els.sons) els.sons.checked = !!row.is_sons;
    }

    async function syncFromChip() {
      const chip = (els.chip && els.chip.value || '').trim().toUpperCase();
      if (!chip) return;
      applyTeam(await fetchByChip(chip));
    }

    async function syncFromTeamName() {
      const name = (els.team && els.team.value || '').trim();
      if (!name) return;
      applyTeam(await fetchByName(name));
    }

    // Listeners
    if (els.chip) els.chip.addEventListener('change', syncFromChip);
    if (els.team) els.team.addEventListener('change', syncFromTeamName);

    // If you have a dropdown of teams
    if (els.teamSel) {
      els.teamSel.addEventListener('change', async () => {
        const opt = els.teamSel.options[els.teamSel.selectedIndex];
        const chip = opt ? (opt.getAttribute('data-chip') || '').trim() : '';
        const name = opt ? opt.textContent.trim() : '';
        if (els.team && name) els.team.value = name;
        if (chip) {
          if (els.chip) els.chip.value = chip;
          await syncFromChip();
        } else {
          await syncFromTeamName();
        }
      });
    }

    // Initial sync if fields were pre-filled by other code
    (async () => {
      if (els.chip && els.chip.value) await syncFromChip();
      else if (els.team && els.team.value) await syncFromTeamName();
    })();
  });
})();
</script>
<!-- WH_SYNC_END -->
'@

# 5) Insert just before </body>, or append if no </body> is present
if ($html -match '(?is)</body\s*>') {
  $html = [regex]::Replace($html, '(?is)</body\s*>', ($snippet + "`r`n</body>"), 1)
} else {
  $html = $html + "`r`n" + $snippet
}

# 6) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Sync script injected into landing.html (backup: $([IO.Path]::GetFileName($bak)))" -ForegroundColor Green
Start-Process $file
