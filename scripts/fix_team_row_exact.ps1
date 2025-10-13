# fix_team_row_exact.ps1
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

# 0) Add/replace a small, scoped style that forces a single, tidy row for the team inputs
$style = @'
<style id="wh-team-one-row-style">
  /* Entire team row lives in the form; force single row layout */
  #teamForm{
    display:flex; gap:12px; align-items:flex-end; flex-wrap:nowrap;
    flex: 1 1 auto;
  }
  /* Half-width Team Name for fit */
  #teamForm input#team, #teamForm input#teamName {
    flex: 1 1 40%;
    min-width: 280px;
  }
  /* Flags group sits inline after team name */
  #wh-team-flags-inline {
    display:inline-flex; gap:12px; align-items:center;
    flex: 0 0 auto;
  }
  #wh-team-flags-inline label {
    display:inline-flex; gap:6px; align-items:center; font-size:14px; color:#333;
  }
  /* Site block next */
  #wh-site-wrap {
    display:flex; flex-direction:column; font-size:12px; color:#555;
    flex: 0 0 140px;
  }
  #wh-site-wrap input {
    padding:8px 10px; border:1px solid #ddd; border-radius:10px;
  }
  /* Chip before button, same row */
  #wh-chip-wrap {
    display:flex; flex-direction:column; font-size:12px; color:#555;
    flex: 0 0 170px;
  }
  #wh-chip-wrap input {
    padding:8px 10px; border:1px solid #ddd; border-radius:10px;
    text-transform:uppercase;
  }
  /* Ensure Add Team button stays inline */
  #teamForm button, #teamForm input[type=submit] {
    display:inline-flex; align-items:center;
    flex: 0 0 auto;
    white-space:nowrap;
  }
  /* If the screen is very narrow, allow wrapping gracefully */
  @media (max-width: 920px) {
    #teamForm{ flex-wrap:wrap; }
    #teamForm input#team, #teamForm input#teamName { flex-basis: 100%; min-width: 240px; }
  }
</style>
'@
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"wh-team-one-row-style"[^>]*>[\s\S]*?</style>','')
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$style + "`r`n</head>",1)
} else {
  $html = $style + "`r`n" + $html
}

# 1) Remove any previous wrappers/styles we added in earlier attempts that force extra rows
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"(?:wh-team-inline-style|wh-team-flags-style)"[^>]*>[\s\S]*?</style>','')
# Drop wrappers but keep their inner content
$html = $html -replace '(?is)<div\b[^>]*id\s*=\s*"wh-chip-inline-row"[^>]*>',''
$html = $html -replace '(?is)</div>\s*<!--\s*end-wh-chip-inline-row\s*-->',''
$html = $html -replace '(?is)</div>\s*(?=</form>)','</form>'  # tidy if we left a dangling div

# 2) Remove the UNWANTED Site # input that shows arrows (type="number") — keep the other one
$html = [regex]::Replace($html,'(?is)<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*\btype\s*=\s*["'']number["''][^>]*>[\s\S]*?</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*\btype\s*=\s*["'']number["''][^>]*>','')

# 3) Shorten checkbox labels exactly to “Legion” and “Sons”
$html = $html -replace '(?i)>(\s*)Legion\s*Team(\s*)<','>$1Legion$2<'
$html = $html -replace '(?i)>(\s*)Sons\s*Team(\s*)<','>$1Sons$2<'

# 4) Ensure flags are grouped inline AFTER the Team Name input; remove any older flag blocks to avoid duplicates
$html = [regex]::Replace($html,'(?is)<div[^>]*\bid\s*=\s*"wh-team-flags"[^>]*>[\s\S]*?</div>','')   # old vertical block
$html = [regex]::Replace($html,'(?is)<span[^>]*\bid\s*=\s*"wh-team-flags-inline"[^>]*>[\s\S]*?</span>','') # rebuild cleanly

$flagsInline = @'
<span id="wh-team-flags-inline">
  <label><input type="checkbox" id="legionFlag"> <span>Legion</span></label>
  <label><input type="checkbox" id="sonsFlag"> <span>Sons</span></label>
</span>
'@

# 5) Capture the remaining Site # (whatever is left) and rebuild as a tidy block
#    Prefer a labeled block; if only a bare input remains, wrap it.
$siteBlock = $null
$rxSiteLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>[\s\S]*?</label>)
'@
$rxSiteInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>)
'@
$m = [regex]::Match($html,$rxSiteLabel)
if ($m.Success) {
  $siteBlock = $m.Groups[1].Value
  $html = $html.Replace($siteBlock,'') # remove original spot
} else {
  $m = [regex]::Match($html,$rxSiteInput)
  if ($m.Success) {
    $siteBlock = '<label>Site # ' + $m.Groups[1].Value + '</label>'
    $html = $html.Replace($m.Groups[1].Value,'') # remove original spot
  } else {
    # if none found, create a standard one
    $siteBlock = '<label>Site # <input id="site" class="input" placeholder="e.g., 7" /></label>'
  }
}
$siteBlock = '<span id="wh-site-wrap">' + $siteBlock + '</span>'

# 6) Insert flags + site AFTER Team Name input (same row)
$inlineRow = $flagsInline + $siteBlock
$rxTeamInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
if ([regex]::IsMatch($html,$rxTeamInput)) {
  $html = [regex]::Replace($html,$rxTeamInput,"`$1`r`n$inlineRow",1)
} else {
  # Fallback: after a Team Name label+input block
  $rxTeamLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Team\s*Name[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
  if ([regex]::IsMatch($html,$rxTeamLabel)) {
    $html = [regex]::Replace($html,$rxTeamLabel,"`$1`r`n$inlineRow",1)
  }
}

# 7) Ensure a single Chip # just BEFORE the “Add Team” button and on same row (remove any old wrappers)
#    Remove duplicates first
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
  # If no button found, append chip near end of form
  $rxFormEnd = '(?is)</form>'
  if ([regex]::IsMatch($html,$rxFormEnd)) {
    $html = [regex]::Replace($html,$rxFormEnd,$chipLabel + "`r`n</form>",1)
  } else {
    $html = $html + "`r`n" + $chipLabel
  }
}

# 8) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Team row fixed: one Site #, Team=half width, flags inline (Legion/Sons), Chip before Add Team — all on one row. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $file
