# apply_team_row_layout.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# --- Backup ---
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# --- Read file ---
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# --- Insert/replace the scoped CSS that forces the one-row layout ---
$styleBlock = @"
<style id="wh-team-row-style-final">
  /* Force a single tall row that can fit the vertical flags */
  #teamForm{
    display:flex; align-items:flex-end; gap:12px; flex-wrap:nowrap;
    min-height:96px; /* room for vertical checkboxes */
  }
  /* Left column: vertical stack of flags */
  #wh-team-flags-stack{
    display:flex; flex-direction:column; gap:4px; align-items:flex-start;
    flex:0 0 120px; /* fixed small column */
  }
  #wh-team-flags-stack label{ display:inline-flex; gap:6px; align-items:center; font-size:14px; color:#333; }

  /* Team name: about one-third of the row */
  #teamForm .wh-team-name{ flex:0 0 33%; min-width:220px; display:flex; flex-direction:column; }
  #teamForm .wh-team-name input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; }

  /* Site #: compact */
  #wh-site-wrap{ flex:0 0 150px; display:flex; flex-direction:column; }
  #wh-site-wrap input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; }

  /* Chip #: compact, fits left of button */
  #wh-chip-wrap{ flex:0 0 120px; display:flex; flex-direction:column; }
  #wh-chip-wrap input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; text-transform:uppercase; }

  /* Keep the Add Team button inline */
  #teamForm button, #teamForm input[type=submit]{ display:inline-flex; align-items:center; white-space:nowrap; flex:0 0 auto; }
</style>
"@

# Remove any prior attempts/styles we added before
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"(?:wh-team-row-style-final|wh-team-one-row-style|wh-team-inline-style|wh-team-flags-style)"[^>]*>[\s\S]*?</style>','')
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$styleBlock + "`r`n</head>",1)
} else {
  $html = $styleBlock + "`r`n" + $html
}

# --- Helpers ---
function rxMatch($text,$pattern){ [regex]::Match($text,$pattern,'IgnoreCase,Singleline') }
function removeByMatch([ref]$text,$m){ if($m.Success){ $text.Value = $text.Value.Remove($m.Index,$m.Length); $true } else { $false } }

# --- Clean out previously injected wrappers (to avoid duplicates) ---
$trash = @'
(?is)<(?:div|span)[^>]*\bid\s*=\s*"(?:wh-team-flags|wh-team-flags-inline|wh-team-inline-row|wh-team-flags-stack|wh-site-wrap|wh-chip-wrap)"[^>]*>[\s\S]*?<\/(?:div|span)>
'@
$html = [regex]::Replace($html,$trash,'')

# --- Find & extract: Team input, Site input/label, Chip input, Add Team button/submit ---
# TEAM input (id="team" or "teamName")
$rxTeamInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
$teamM = rxMatch $html $rxTeamInput
$teamInput = if($teamM.Success){ $teamM.Groups[1].Value } else { '<input id="team" type="text" class="input" placeholder="Team Name">' }
if($teamM.Success){
  # if wrapped by a label, remove the entire label; else remove just input
  $teamEsc = [regex]::Escape($teamM.Groups[1].Value)
  $rxLabelTeam = "(?is)(<label\b[^>]*>[\s\S]*?$teamEsc[\s\S]*?</label>)"
  $labelTeamM = rxMatch $html $rxLabelTeam
  if(!(removeByMatch ([ref]$html) $labelTeamM)){
    removeByMatch ([ref]$html) $teamM | Out-Null
  }
}

# SITE: remove any type="number" version (with spinners)
$rxSiteNumberLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*\btype\s*=\s*["']number["'][^>]*>[\s\S]*?</label>)
'@
$rxSiteNumberInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*\btype\s*=\s*["']number["'][^>]*>)
'@
# delete number versions
foreach($pat in @($rxSiteNumberLabel,$rxSiteNumberInput)){ $html = [regex]::Replace($html,$pat,'') }

# Prefer a labeled Site block; else bare input; else synthesize
$rxSiteLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>[\s\S]*?</label>)
'@
$rxSiteInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>)
'@
$siteM = rxMatch $html $rxSiteLabel
if($siteM.Success){
  $siteBlockInner = $siteM.Groups[1].Value
  removeByMatch ([ref]$html) $siteM | Out-Null
}else{
  $siteM2 = rxMatch $html $rxSiteInput
  if($siteM2.Success){
    $siteBlockInner = '<label>Site # ' + $siteM2.Groups[1].Value + '</label>'
    removeByMatch ([ref]$html) $siteM2 | Out-Null
  }else{
    $siteBlockInner = '<label>Site # <input id="site" class="input" placeholder="7" /></label>'
  }
}
$siteBlock = '<span id="wh-site-wrap">' + $siteBlockInner + '</span>'

# CHIP input (id="chip")
$rxChipLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Chip\s*#?[\s\S]*?<input\b[^>]*\bid\s*=\s*["']chip["'][^>]*>[\s\S]*?</label>)
'@
$rxChipInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["']chip["'][^>]*>)
'@
$chipM = rxMatch $html $rxChipLabel
if($chipM.Success){
  $chipInner = $chipM.Groups[1].Value
  removeByMatch ([ref]$html) $chipM | Out-Null
}else{
  $chipM2 = rxMatch $html $rxChipInput
  if($chipM2.Success){
    $chipInner = '<label>Chip # ' + $chipM2.Groups[1].Value + '</label>'
    removeByMatch ([ref]$html) $chipM2 | Out-Null
  }else{
    $chipInner = '<label>Chip # <input id="chip" type="text" class="input" placeholder="A12" /></label>'
  }
}
$chipBlock = $chipInner -replace '(?is)^<label','<label id="wh-chip-wrap"'

# ADD TEAM button
$rxAddBtn = @'
(?is)(<button\b[^>]*>(?:(?!</button>).)*?add\s*team(?:(?!</button>).)*?</button>)
'@
$rxAddSubmit = @'
(?is)(<input\b[^>]*type\s*=\s*["']submit["'][^>]*\bvalue\s*=\s*["']\s*add\s*team\s*["'][^>]*>)
'@
$addM = rxMatch $html $rxAddBtn
if($addM.Success){
  $addBtn = $addM.Groups[1].Value
  removeByMatch ([ref]$html) $addM | Out-Null
}else{
  $addM2 = rxMatch $html $rxAddSubmit
  if($addM2.Success){
    $addBtn = $addM2.Groups[1].Value
    removeByMatch ([ref]$html) $addM2 | Out-Null
  }else{
    $addBtn = '<button type="submit" class="btn">Add Team</button>'
  }
}

# --- Build the exact row you requested ---
$flagsStack = @"
<div id="wh-team-flags-stack">
  <label><input type="checkbox" id="legionFlag"> <span>Legion</span></label>
  <label><input type="checkbox" id="sonsFlag"> <span>Sons</span></label>
</div>
"@

$teamLabelWrap = '<label class="wh-team-name"><span>Team Name</span>' + $teamInput + '</label>'

$rowHtml = $flagsStack + $teamLabelWrap + $siteBlock + ($chipBlock -replace '\s+$','') + $addBtn

# --- Insert the row immediately after the opening <form id="teamForm"...> ---
$rxFormOpen = @'
(?is)(<form\b[^>]*\bid\s*=\s*["']teamForm["'][^>]*>)
'@
if([regex]::IsMatch($html,$rxFormOpen)){
  $html = [regex]::Replace($html,$rxFormOpen,"`$1`r`n$rowHtml",1)
}else{
  # Fallback: insert at first <form> or prepend
  $rxAnyForm = '(?is)(<form\b[^>]*>)'
  if([regex]::IsMatch($html,$rxAnyForm)){
    $html = [regex]::Replace($html,$rxAnyForm,"`$1`r`n$rowHtml",1)
  }else{
    $html = $rowHtml + "`r`n" + $html
  }
}

# --- Write back ---
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Updated landing.html team row (one line, flags left, Team ~1/3, Site #, compact Chip #, Add Team). Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
