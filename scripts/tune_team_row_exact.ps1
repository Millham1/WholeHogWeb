# tune_team_row_exact.ps1
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

# --- 0) Style: single-row layout; flags stack at left; Team Name ~1/3 width; small Chip field ---
$style = @'
<style id="wh-team-one-row-style">
  /* Force the entire team entry to one row */
  #teamForm{
    display:flex; gap:12px; align-items:flex-end; flex-wrap:nowrap;
    min-height:88px; /* tall enough to fit the vertical flags */
  }

  /* Left-side vertical flags stack */
  #wh-team-flags-stack{
    display:flex; flex-direction:column; gap:4px; align-items:flex-start;
    flex:0 0 120px; /* small, fixed column for the two checkboxes */
  }
  #wh-team-flags-stack label{ display:inline-flex; gap:6px; align-items:center; font-size:14px; color:#333; }

  /* Team Name shrunk to ~1/3 of the row (reduced by ~2/3) */
  #teamForm input#team, #teamForm input#teamName{
    flex:0 0 33%;
    min-width:220px;
  }

  /* Site # block (kept compact) */
  #wh-site-wrap{ display:flex; flex-direction:column; font-size:12px; color:#555; flex:0 0 150px; }
  #wh-site-wrap input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; }

  /* Chip # just before Add Team, made small so it fits on same row */
  #wh-chip-wrap{ display:flex; flex-direction:column; font-size:12px; color:#555; flex:0 0 120px; }
  #wh-chip-wrap input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; text-transform:uppercase; }

  /* Keep the button inline and compact */
  #teamForm button, #teamForm input[type=submit]{ display:inline-flex; align-items:center; flex:0 0 auto; white-space:nowrap; }
</style>
'@
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"wh-team-one-row-style"[^>]*>[\s\S]*?</style>','')
if ($html -match '(?is)</head>') { $html = [regex]::Replace($html,'(?is)</head>',$style + "`r`n</head>",1) } else { $html = $style + "`r`n" + $html }

# --- 1) Remove any older flag blocks & duplicate legion/sons inputs we may have added previously ---
$html = [regex]::Replace($html,'(?is)<div[^>]*\bid\s*=\s*"(?:wh-team-flags|wh-team-flags-inline|wh-team-inline-row)"[^>]*>[\s\S]*?</div>','')
# Remove labels containing old legion/sons inputs (avoid duplicates)
$html = [regex]::Replace($html,'(?is)<label\b[^>]*>[\s\S]*?<input\b[^>]*\bid\s*=\s*"legionFlag"[\s\S]*?</label>','')
$html = [regex]::Replace($html,'(?is)<label\b[^>]*>[\s\S]*?<input\b[^>]*\bid\s*=\s*"sonsFlag"[\s\S]*?</label>','')
# Remove bare input remnants if any
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*"(?:legionFlag|sonsFlag)"[^>]*>','')

# --- 2) Ensure the Site # is not duplicated and not "number" type with spinners ---
# delete type="number" version if it exists; keep/fix the plain input
$html = [regex]::Replace($html,'(?is)<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*\btype\s*=\s*["'']number["''][^>]*>[\s\S]*?</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*\btype\s*=\s*["'']number["''][^>]*>','')

# Build a tidy Site # wrapper if we can find the remaining input or label
$siteBlock = $null
$rxSiteLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>[\s\S]*?</label>)
'@
$rxSiteInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>)
'@
$m = [regex]::Match($html,$rxSiteLabel)
if ($m.Success) {
  $siteBlock = '<span id="wh-site-wrap">' + $m.Groups[1].Value + '</span>'
  $html = $html.Replace($m.Groups[1].Value,'')
} else {
  $m = [regex]::Match($html,$rxSiteInput)
  if ($m.Success) {
    $siteBlock = '<span id="wh-site-wrap"><label>Site # ' + $m.Groups[1].Value + '</label></span>'
    $html = $html.Replace($m.Groups[1].Value,'')
  } else {
    $siteBlock = '<span id="wh-site-wrap"><label>Site # <input id="site" class="input" placeholder="e.g., 7" /></label></span>'
  }
}

# --- 3) Insert FLAGS STACK to the LEFT of Team Name field, then keep Team Name, then Site # (all one row) ---
$flagsStack = @'
<div id="wh-team-flags-stack">
  <label class="wh-flag"><input type="checkbox" id="legionFlag"> <span>Legion</span></label>
  <label class="wh-flag"><input type="checkbox" id="sonsFlag"> <span>Sons</span></label>
</div>
'@

# Insert flags stack immediately BEFORE the Team input (id="team" or "teamName")
$rxTeamInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
if ([regex]::IsMatch($html,$rxTeamInput)) {
  $html = [regex]::Replace($html,$rxTeamInput,$flagsStack + "`r`n" + '`$1',1)
} else {
  # Fallback: before Team Name label+input block
  $rxTeamLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Team\s*Name[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
  if ([regex]::IsMatch($html,$rxTeamLabel)) {
    $html = [regex]::Replace($html,$rxTeamLabel,$flagsStack + "`r`n" + '`$1',1)
  } else {
    # If we can’t find it, at least place flags at form start
    $rxFormOpen = '(?is)(<form\b[^>]*\bid\s*=\s*["'']teamForm["''][^>]*>)'
    if ([regex]::IsMatch($html,$rxFormOpen)) {
      $html = [regex]::Replace($html,$rxFormOpen,"`$1`r`n$flagsStack",1)
    } else {
      $html = $flagsStack + "`r`n" + $html
    }
  }
}

# After inserting flags, append the Site # wrapper right AFTER the Team input (so order is: flags -> team -> site)
$rxAfterTeamOnce = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
if ([regex]::IsMatch($html,$rxAfterTeamOnce)) {
  $html = [regex]::Replace($html,$rxAfterTeamOnce,'`$1' + "`r`n" + $siteBlock,1)
} else {
  # If team input wasn’t matched, place site after flags stack
  $html = $html -replace '(?is)(</div>\s*<!-- end of wh-team-flags-stack -->)','`$1' + $siteBlock
}

# --- 4) Make sure Chip # is small and directly to the left of the Add Team button (still one row) ---
# Remove duplicate chip fields
$html = [regex]::Replace($html,'(?is)<label[^>]*>\s*Chip\s*#\s*<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>\s*</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>','')

$chipLabel = '<label id="wh-chip-wrap">Chip # <input id="chip" type="text" class="input" placeholder="e.g., A12" /></label>'
$rxAddBtn = @'
(?is)(<button\b[^>]*>(?:(?!</button>).)*?add\s*team(?:(?!</button>).)*?</button>)
'@
$rxAddSubmit = @'
(?is)(<input\b[^>]*type\s*=\s*["']submit["'][^>]*\bvalue\s*=\s*["']\s*add\s*team\s*["'][^>]*>)
'@
if ([regex]::IsMatch($html,$rxAddBtn)) {
  $html = [regex]::Replace($html,$rxAddBtn,$chipLabel + "`r`n" + '`$1',1)
} elseif ([regex]::IsMatch($html,$rxAddSubmit)) {
  $html = [regex]::Replace($html,$rxAddSubmit,$chipLabel + "`r`n" + '`$1',1)
} else {
  # fallback: add near end of form
  $html = [regex]::Replace($html,'(?is)</form>',$chipLabel + "`r`n</form>",1)
}

# --- 5) Write back ---
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Team row tuned: flags vertically at far left, Team ~1/3 width, compact Site #, small Chip # before Add Team — all in one row. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $file
