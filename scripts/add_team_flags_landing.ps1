# add_team_flags_landing.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$landing = Join-Path $root "landing.html"
if (!(Test-Path $landing)) { throw "landing.html not found at $landing" }

# Backup
$bak = "$landing.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $landing -Destination $bak -Force

# Read
$html = Get-Content -LiteralPath $landing -Raw -Encoding UTF8

# ---------- 1) Insert the two checkboxes inside the Teams entry form ----------
# Prefer a form with id="teamForm", fallback to the first form on the page.
$flagsBlock = @'
<div id="wh-team-flags" class="flex" style="margin-top:8px; gap:12px; align-items:center;">
  <label style="display:inline-flex; gap:6px; align-items:center;">
    <input type="checkbox" id="legionFlag"> Legion Team
  </label>
  <label style="display:inline-flex; gap:6px; align-items:center;">
    <input type="checkbox" id="sonsFlag"> Sons Team
  </label>
</div>
'@

# If flags already exist, skip insertion
if ($html -notmatch '(?is)id\s*=\s*"wh-team-flags"') {
  # Insert immediately after the opening <form ... id="teamForm" ...>
  $rxTeamFormOpen = @'
(?is)(<form\b[^>]*\bid\s*=\s*["']teamForm["'][^>]*>)
'@
  if ([regex]::IsMatch($html, $rxTeamFormOpen)) {
    $html = [regex]::Replace($html, $rxTeamFormOpen, "`$1`r`n$flagsBlock", 1)
  } else {
    # Fallback: insert after the first <form> opening tag
    $rxFirstFormOpen = @'
(?is)(<form\b[^>]*>)
'@
    if ([regex]::IsMatch($html, $rxFirstFormOpen)) {
      $html = [regex]::Replace($html, $rxFirstFormOpen, "`$1`r`n$flagsBlock", 1)
    } else {
      # No form found — place flags near top of main content
      $rxMain = '(?is)(<main\b[^>]*>)'
      if ([regex]::IsMatch($html, $rxMain)) {
        $html = [regex]::Replace($html, $rxMain, "`$1`r`n$flagsBlock", 1)
      } else {
        # Last resort: place after <body>
        $rxBody = '(?is)(<body\b[^>]*>)'
        if ([regex]::IsMatch($html, $rxBody)) {
          $html = [regex]::Replace($html, $rxBody, "`$1`r`n$flagsBlock", 1)
        } else {
          $html = $flagsBlock + "`r`n" + $html
        }
      }
    }
  }
}

# ---------- 2) Patch Supabase save to include the flags ----------
# Look for .from('teams').upsert([... { ... } ...]) or .insert([... { ... } ...])
# and inject the fields at the start of the first object.
$rxPatch = @'
(?is)(\.from\(\s*["']teams["']\s*\)\s*\.\s*(?:upsert|insert)\s*\(\s*\[\s*\{\s*)
'@
$inject = 'is_legion: (!!document.getElementById("legionFlag") && document.getElementById("legionFlag").checked), is_sons: (!!document.getElementById("sonsFlag") && document.getElementById("sonsFlag").checked), '

$before = $html
$html = [regex]::Replace($html, $rxPatch, "`$1$inject")
$patched = ($html -ne $before)

# If nothing patched inside landing.html, we leave a tiny console hint (non-breaking) for external JS.
if (-not $patched -and $html -notmatch '(?is)wh-team-flags-note') {
  $note = @'
<script id="wh-team-flags-note">
  // NOTE: Team flags UI present.
  // Ensure your teams insert/upsert includes:
  //   is_legion: (!!document.getElementById("legionFlag") && document.getElementById("legionFlag").checked),
  //   is_sons:   (!!document.getElementById("sonsFlag")   && document.getElementById("sonsFlag").checked)
  // This is only a reminder if your saving code lives in an external JS file.
</script>
'@
  $html = $html + "`r`n" + $note
}

# Write back
Set-Content -LiteralPath $landing -Encoding UTF8 -Value $html

# ---------- 3) Write the SQL to add columns + scoring model views ----------
$sqlPath = Join-Path $root "db_team_flags.sql"
$sql = @'
-- === Add flags to teams (idempotent) ===
alter table teams add column if not exists is_legion boolean default false;
alter table teams add column if not exists is_sons   boolean default false;

-- === Totals per team (by chip) ===
create or replace view team_totals as
select
  t.chip_number,
  t.team_name,
  t.site_number,
  coalesce(sum(s.score), 0) as total_score
from teams t
left join scores s
  on s.chip_number = t.chip_number
group by t.chip_number, t.team_name, t.site_number;

-- === Legion Team Winner (highest total among is_legion=true) ===
create or replace view legion_winner as
select tt.*
from team_totals tt
join teams t on t.chip_number = tt.chip_number
where coalesce(t.is_legion, false) is true
order by tt.total_score desc nulls last
limit 1;

-- === Sons Team Winner (highest total among is_sons=true) ===
create or replace view sons_winner as
select tt.*
from team_totals tt
join teams t on t.chip_number = tt.chip_number
where coalesce(t.is_sons, false) is true
order by tt.total_score desc nulls last
limit 1;
'@
Set-Content -LiteralPath $sqlPath -Encoding UTF8 -Value $sql

Write-Host "✅ landing.html updated: added Legion/Sons checkboxes and patched team save (if inline). Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Write-Host "📄 SQL written: $sqlPath — open Supabase SQL Editor, paste, and run to add columns & views." -ForegroundColor Yellow
Start-Process $landing
Start-Process notepad.exe $sqlPath
