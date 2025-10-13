# tune_team_row_exact_fix.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# Read file
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# 0) Scoped CSS to pin everything to ONE row and size fields
$style = @"
<style id="wh-team-one-row-style">
  /* Force team form to one row and tall enough to fit vertical flags */
  #teamForm{
    display:flex; gap:12px; align-items:flex-end; flex-wrap:nowrap;
    min-height:96px;
  }
  /* Left-side vertical flags stack */
  #wh-team-flags-stack{
    display:flex; flex-direction:column; gap:4px; align-items:flex-start;
    flex:0 0 120px;
  }
  #wh-team-flags-stack label{ display:inline-flex; gap:6px; align-items:center; font-size:14px; color:#333; }
  /* Team Name ~ one-third width */
  #teamForm input#team, #teamForm input#teamName{
    flex:0 0 33%;
    min-width:220px;
  }
  /* Site # compact block */
  #wh-site-wrap{ display:flex; flex-direction:column; font-size:12px; color:#555; flex:0 0 150px; }
  #wh-site-wrap input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; }
  /* Chip # small so it fits left of the Add Team button */
  #wh-chip-wrap{ display:flex; flex-direction:column; font-size:12px; color:#555; flex:0 0 120px; }
  #wh-chip-wrap input{ padding:8px 10px; border:1px solid #ddd; border-radius:10px; text-transform:uppercase; }
  /* Keep the Add Team button inline */
  #teamForm button, #teamForm input[type=submit]{ display:inline-flex; align-items:center; flex:0 0 auto; white-space:nowrap; }
</style>
"@
# Replace previous version (if any), then insert
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"wh-team-one-row-style"[^>]*>[\s\S]*?</style>','')
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$style + "`r`n</head>",1)
} else {
  $html = $style + "`r`n" + $html
}

# 1) Remove any older flag wrappers/duplicates we might have created before
$html = [regex]::Replace($html,'(?is)<div[^>]*\bid\s*=\s*"(?:wh-team-flags|wh-team-flags-inline|wh-team-inline-row)"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<span[^>]*\bid\s*=\s*"(?:wh-team-flags-inline|wh-team-inline-row)"[^>]*>[\s\S]*?</span>','')
# Remove old legion/sons inputs if they exist
$html = [regex]::Replace($html,'(?is)<label\b[^>]*>[\s\S]*?<input\b[^>]*\bid\s*=\s*"legionFlag"[\s\S]*?</label>','')
$html = [regex]::Replace($html,'(?is)<label\b[^>]*>[\s\S]*?<input\b[^>]*\bid\s*=\s*"sonsFlag"[\s\S]*?</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*"(?:legionFlag|sonsFlag)"[^>]*>','')

# 2) Remove the UNWANTED Site # input with spinners (type="number")
$html = [regex]::Replace($html,'(?is)<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*\btype\s*=\s*["'']number["''][^>]*>[\s\S]*?</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum)["''][^>]*\btype\s*=\s*["'']number["''][^>]*>','')

# 3) Build Site # block using any remaining site input/label (or fallback)
$siteBlock = $null
$rxSiteLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>[\s\S]*?</label>)
'@
$rxSiteInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:site|site_number|siteNo|siteNum)["'][^>]*>)
'@
$mSite = [regex]::Match($html,$rxSiteLabel)
if ($mSite.Success) {
  $siteBlock = '<span id="wh-site-wrap">' + $mSite.Groups[1].Value + '</span>'
  # Remove original
  $html = $html.Remove($mSite.Index, $mSite.Length)
} else {
  $mSite = [regex]::Match($html,$rxSiteInput)
  if ($mSite.Success) {
    $siteBlock = '<span id="wh-site-wrap"><label>Site # ' + $mSite.Groups[1].Value + '</label></span>'
    $html = $html.Remove($mSite.Index, $mSite.Length)
  } else {
    $siteBlock = '<span id="wh-site-wrap"><label>Site # <input id="site" class="input" placeholder="e.g., 7" /></label></span>'
  }
}

# 4) Insert FLAGS STACK to the LEFT of Team Name, then keep Team Name, then Site # (all one row)
$flagsStack = @"
<div id="wh-team-flags-stack">
  <label class="wh-flag"><input type="checkbox" id="legionFlag"> <span>Legion</span></label>
  <label class="wh-flag"><input type="checkbox" id="sonsFlag"> <span>Sons</span></label>
</div>
"@

# Find Team input (id="team" or "teamName")
$rxTeamInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
$mTeam = [regex]::Match($html,$rxTeamInput)
if ($mTeam.Success) {
  $pre  = $html.Substring(0, $mTeam.Index)
  $post = $html.Substring($mTeam.Index + $mTeam.Length)
  $newSeg = $flagsStack + $mTeam.Value + $siteBlock
  $html = $pre + $newSeg + $post
} else {
  # Fallback: before a Team Name label+input block
  $rxTeamLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Team\s*Name[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
  $mTeam = [regex]::Match($html,$rxTeamLabel)
  if ($mTeam.Success) {
    $pre  = $html.Substring(0, $mTeam.Index)
    $post = $html.Substring($mTeam.Index + $mTeam.Length)
    $newSeg = $flagsStack + $mTeam.Value + $siteBlock
    $html = $pre + $newSeg + $post
  } else {
    # If not found at all, put the row at the start of #teamForm
    $rxFormOpen = '(?is)(<form\b[^>]*\bid\s*=\s*["'']teamForm["''][^>]*>)'
    $mForm = [regex]::Match($html,$rxFormOpen)
    if ($mForm.Success) {
      $pre  = $html.Substring(0, $mForm.Index + $mForm.Length)
      $post = $html.Substring($mForm.Index + $mForm.Length)
      $html = $pre + "`r`n" + $flagsStack + $siteBlock + $post
    } else {
      # Last resort: prepend
      $html = $flagsStack + $siteBlock + $html
    }
  }
}

# 5) Ensure a compact Chip # just before the Add Team button (same row)
# Remove duplicates
$html = [regex]::Replace($html,'(?is)<label[^>]*>\s*Chip\s*#\s*<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>\s*</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>','')

$chipLabel = '<label id="wh-chip-wrap">Chip # <input id="chip" type="text" class="input" placeholder="A12" /></label>'

# Insert Chip before Add Team button or submit
$rxAddBtn = @'
(?is)(<button\b[^>]*>(?:(?!</button>).)*?add\s*team(?:(?!</button>).)*?</button>)
'@
$rxAddSubmit = @'
(?is)(<input\b[^>]*type\s*=\s*["']submit["'][^>]*\bvalue\s*=\s*["']\s*add\s*team\s*["'][^>]*>)
'@
$mAdd = [regex]::Match($html,$rxAddBtn)
if (-not $mAdd.Success) { $mAdd = [regex]::Match($html,$rxAddSubmit) }

if ($mAdd.Success) {
  $pre  = $html.Substring(0, $mAdd.Index)
  $post = $html.Substring($mAdd.Index)
  $html = $pre + $chipLabel + $post
} else {
  # If no button found, append chip at end of form
  $rxFormEnd = '(?is)</form>'
  if ($html -match $rxFormEnd) {
    $html = [regex]::Replace($html,$rxFormEnd,$chipLabel + "`r`n</form>",1)
  } else {
    $html += "`r`n" + $chipLabel
  }
}

# 6) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Team row updated: flags vertical at far left, Team ~1/3 width, Site #, compact Chip # before Add Team — all on one row. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
