# fix_team_layout_landing.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# Read
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# =========================
# 0) STYLE (small, scoped)
# =========================
$style = @'
<style id="wh-team-inline-style">
  /* Row that holds: Team Name (existing) + flags + Site # */
  #wh-team-inline-row{
    display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap; margin-top:8px;
  }
  #wh-team-flags-inline{
    display:flex; gap:12px; align-items:center;
  }
  #wh-team-flags-inline label{
    display:inline-flex; gap:6px; align-items:center; font-size:14px; color:#333;
  }
  #wh-team-inline-row label{
    display:flex; flex-direction:column; font-size:12px; color:#555;
  }
  #wh-team-inline-row input, #wh-team-inline-row select{
    padding:8px 10px; border:1px solid #ddd; border-radius:10px; min-width:130px;
  }

  /* Chip + Add Team inline row */
  #wh-chip-inline-row{
    display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap; margin-top:10px;
  }
  #wh-chip-inline-row label{
    display:flex; flex-direction:column; font-size:12px; color:#555;
  }
  #wh-chip-inline-row input{
    padding:8px 10px; border:1px solid #ddd; border-radius:10px; min-width:160px;
  }
</style>
'@
# Replace previous version (if any), then insert/append
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"wh-team-inline-style"[^>]*>[\s\S]*?</style>','')
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$style + "`r`n</head>",1)
} else {
  $html = $style + "`r`n" + $html
}

# ==============================================
# 1) Build flags block (same row, right of Team)
# ==============================================
$flagsInline = @'
<span id="wh-team-flags-inline">
  <label><input type="checkbox" id="legionFlag"> <span>Legion Team</span></label>
  <label><input type="checkbox" id="sonsFlag"> <span>Sons Team</span></label>
</span>
'@

# Remove any prior flag blocks we may have added in earlier attempts
$html = [regex]::Replace($html,'(?is)<div[^>]*\bid\s*=\s*"wh-team-flags"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<span[^>]*\bid\s*=\s*"wh-team-flags-inline"[^>]*>[\s\S]*?</span>','')

# ==========================================================
# 2) Capture Site # (label+input or input) so we can relocate
# ==========================================================
$siteLabelBlock = $null
$siteInputOnly  = $null

# Try a <label>...Site...<input id="site*">...</label>
$rxSiteLabelBlock = @'
(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>[\s\S]*?</label>)
'@
$m = [regex]::Match($html,$rxSiteLabelBlock)
if ($m.Success) {
  $siteLabelBlock = $m.Groups[1].Value
  $html = $html.Replace($siteLabelBlock,'')
} else {
  # Try standalone input with id="site*"
  $rxSiteInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>)
'@
  $m2 = [regex]::Match($html,$rxSiteInput)
  if ($m2.Success) {
    $siteInputOnly = $m2.Groups[1].Value
    $html = $html.Replace($siteInputOnly,'')
  }
}

# Build Site # block to reinsert on the same row (after flags)
$siteBlock = if ($siteLabelBlock) {
  $siteLabelBlock
} elseif ($siteInputOnly) {
  '<label>Site # ' + $siteInputOnly + '</label>'
} else {
  # Fallback if the page didn’t have a site field
  '<label>Site # <input id="site" type="number" min="1" class="input" placeholder="e.g., 7" /></label>'
}

# ==========================================================
# 3) Insert flags and site right AFTER the Team Name field
# ==========================================================
# Find <input ... id="team" ...> or id="teamName" and drop a row right after it
$inlineRowOpen  = '<span id="wh-team-inline-row">'
$inlineRowClose = '</span>'

$rxTeamInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
if ([regex]::IsMatch($html,$rxTeamInput)) {
  # Insert: team input + (flags + site) grouped in the same row
  $afterTeam = $inlineRowOpen + $flagsInline + $siteBlock + $inlineRowClose
  $html = [regex]::Replace($html,$rxTeamInput,"`$1`r`n$afterTeam",1)
} else {
  # Fallback: after a label containing Team Name and its input
  $rxTeamLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Team\s*Name[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
  if ([regex]::IsMatch($html,$rxTeamLabel)) {
    $afterTeam = $inlineRowOpen + $flagsInline + $siteBlock + $inlineRowClose
    $html = [regex]::Replace($html,$rxTeamLabel,"`$1`r`n$afterTeam",1)
  } else {
    # If we cannot find Team Name reliably, place near start of team form/card
    $rxTeamForm = '(?is)(<form\b[^>]*\bid\s*=\s*["'']teamForm["''][^>]*>)'
    $afterTeam = $inlineRowOpen + $flagsInline + $siteBlock + $inlineRowClose
    if ([regex]::IsMatch($html,$rxTeamForm)) {
      $html = [regex]::Replace($html,$rxTeamForm,"`$1`r`n$afterTeam",1)
    } else {
      $html = $afterTeam + "`r`n" + $html
    }
  }
}

# ==========================================================
# 4) CHIP # before the "Add Team" button (same row as button)
# ==========================================================
# Remove any older Chip inputs we may have inserted
$html = [regex]::Replace($html,'(?is)<label[^>]*>\s*Chip\s*#\s*<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>\s*</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>','')

$chipLabel = '<label id="wh-chip-wrap">Chip # <input id="chip" type="text" class="input" placeholder="e.g., A12" /></label>'

# Find an Add Team button or submit with value
$rxAddBtn = @'
(?is)(<button\b[^>]*>(?:(?!</button>).)*?add\s*team(?:(?!</button>).)*?</button>)
'@
$rxAddSubmit = @'
(?is)(<input\b[^>]*type\s*=\s*["']submit["'][^>]*\bvalue\s*=\s*["']\s*add\s*team\s*["'][^>]*>)
'@

if ([regex]::IsMatch($html,$rxAddBtn)) {
  # Wrap chip + button in one inline row
  $chipRow = '<div id="wh-chip-inline-row">' + $chipLabel + '`$1' + '</div>'
  $html = [regex]::Replace($html,$rxAddBtn,$chipRow,1)
} elseif ([regex]::IsMatch($html,$rxAddSubmit)) {
  $chipRow = '<div id="wh-chip-inline-row">' + $chipLabel + '`$1' + '</div>'
  $html = [regex]::Replace($html,$rxAddSubmit,$chipRow,1)
} else {
  # Couldn’t find the button; try to append chip field near end of form
  $rxFormEnd = '(?is)</form>'
  if ([regex]::IsMatch($html,$rxFormEnd)) {
    $html = [regex]::Replace($html,$rxFormEnd,'<div id="wh-chip-inline-row">' + $chipLabel + '</div>' + "`r`n</form>",1)
  } else {
    $html = $html + "`r`n" + '<div id="wh-chip-inline-row">' + $chipLabel + '</div>'
  }
}

# ==========================================================
# 5) Patch Supabase save (if inline in this file)
# ==========================================================
# Only patch if not already present
$needChip  = ($html -notmatch '(?i)\bchip_number\b')
$needFlags = ($html -notmatch '(?i)\bis_legion\b') -or ($html -notmatch '(?i)\bis_sons\b')

if ($needChip -or $needFlags) {
  $rxPatch = @'
(?is)(\.from\(\s*["']teams["']\s*\)\s*\.\s*(?:upsert|insert)\s*\(\s*\[\s*\{\s*)
'@
  $inject = ''
  if ($needChip)  { $inject += 'chip_number: ((document.getElementById("chip") && document.getElementById("chip").value) ? document.getElementById("chip").value.trim().toUpperCase() : ""), ' }
  if ($needFlags) { $inject += 'is_legion: (!!document.getElementById("legionFlag") && document.getElementById("legionFlag").checked), is_sons: (!!document.getElementById("sonsFlag") && document.getElementById("sonsFlag").checked), ' }
  $html = [regex]::Replace($html,$rxPatch,"`$1$inject")
}

# Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Moved flags inline after Team Name, then Site # on same row. Added Chip # just before Add Team (same row). Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $file
