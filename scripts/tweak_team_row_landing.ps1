# tweak_team_row_landing.ps1
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

# 0) Insert/replace a tiny style block to make the row look clean (one row, aligned bottoms)
$styleBlock = @'
<style id="wh-team-inline-style">
  #wh-team-inline-row{
    display:flex; gap:12px; align-items:flex-end; flex-wrap:wrap;
    margin-top:8px;
  }
  #wh-team-flags-inline{
    display:flex; gap:12px; align-items:center;
  }
  #wh-team-inline-row label{
    display:flex; flex-direction:column; font-size:12px; color:#555;
  }
  #wh-team-inline-row input, #wh-team-inline-row select{
    padding:8px 10px; border:1px solid #ddd; border-radius:10px; min-width:130px;
  }
  #wh-chip-wrap{ min-width:180px; }
</style>
'@
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"wh-team-inline-style"[^>]*>[\s\S]*?</style>','')
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$styleBlock + "`r`n</head>",1)
} else {
  $html = $styleBlock + "`r`n" + $html
}

# 1) Remove any older flags block we might have inserted earlier
$html = [regex]::Replace($html,'(?is)<div[^>]*\bid\s*=\s*"wh-team-flags"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<span[^>]*\bid\s*=\s*"wh-team-flags-inline"[^>]*>[\s\S]*?</span>','')
$html = [regex]::Replace($html,'(?is)<span[^>]*\bid\s*=\s*"wh-team-inline-row"[^>]*>[\s\S]*?</span>','')

# 2) Capture and remove any existing Site # input (and its wrapping label if present), so we can re-insert in the new row
$siteLabelBlock = $null
$siteInputOnly  = $null

# Try a <label> ... Site ... <input id="site"> ... </label> block
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

# Build the Site # block we will insert (reuse captured input if we found it)
$siteBlock = if ($siteLabelBlock) {
  $siteLabelBlock
} elseif ($siteInputOnly) {
  '<label>Site # ' + $siteInputOnly + '</label>'
} else {
  # fallback if none existed
  '<label>Site # <input id="site" type="number" min="1" class="input" placeholder="e.g., 7" /></label>'
}

# 3) Build inline flags + site row
$inlineRow = @"
<span id="wh-team-inline-row">
  <span id="wh-team-flags-inline">
    <label style="flex-direction:row; gap:6px; align-items:center;"><input type="checkbox" id="legionFlag"> <span>Legion Team</span></label>
    <label style="flex-direction:row; gap:6px; align-items:center;"><input type="checkbox" id="sonsFlag"> <span>Sons Team</span></label>
  </span>
  $siteBlock
</span>
"@

# 4) Insert the inline row RIGHT AFTER the Team Name input
#   Match an <input ... id="team" ...> OR id="teamName"
$rxTeamInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
if ([regex]::IsMatch($html,$rxTeamInput)) {
  $html = [regex]::Replace($html,$rxTeamInput,"`$1`r`n$inlineRow",1)
} else {
  # Try to find a label containing Team Name and its input
  $rxTeamLabel = @'
(?is)(<label\b[^>]*>[\s\S]*?Team\s*Name[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
  if ([regex]::IsMatch($html,$rxTeamLabel)) {
    $html = [regex]::Replace($html,$rxTeamLabel,"`$1`r`n$inlineRow",1)
  } else {
    # As a last resort, inject near start of Teams card/form
    $rxCard = '(?is)(<form\b[^>]*\bid\s*=\s*["'']teamForm["''][^>]*>)'
    if ([regex]::IsMatch($html,$rxCard)) {
      $html = [regex]::Replace($html,$rxCard,"`$1`r`n$inlineRow",1)
    } else {
      $html = $inlineRow + "`r`n" + $html
    }
  }
}

# 5) Ensure a single Chip # field just BEFORE the "Add Team" button
#    Remove any existing chip input/label to avoid duplicates
$html = [regex]::Replace($html,'(?is)<label[^>]*>\s*Chip\s*#\s*<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>\s*</label>','')
$html = [regex]::Replace($html,'(?is)<input\b[^>]*\bid\s*=\s*["'']chip["''][^>]*>','')

# Find an Add Team button and insert before it
$rxAddBtn = @'
(?is)(<button\b[^>]*>(?:(?!</button>).)*?add\s*team(?:(?!</button>).)*?</button>)
'@
$chipBlock = '<label id="wh-chip-wrap">Chip # <input id="chip" type="text" class="input" placeholder="e.g., A12" /></label>'

if ([regex]::IsMatch($html,$rxAddBtn)) {
  $html = [regex]::Replace($html,$rxAddBtn,$chipBlock + "`r`n" + '`$1',1)
} else {
  # Try input[type=submit] with value Add Team
  $rxAddSubmit = @'
(?is)(<input\b[^>]*type\s*=\s*["']submit["'][^>]*\bvalue\s*=\s*["']\s*add\s*team\s*["'][^>]*>)
'@
  if ([regex]::IsMatch($html,$rxAddSubmit)) {
    $html = [regex]::Replace($html,$rxAddSubmit,$chipBlock + "`r`n" + '`$1',1)
  } else {
    # If we can't find it, append chip field at end of the form
    $rxFormEnd = '(?is)</form>'
    if ([regex]::IsMatch($html,$rxFormEnd)) {
      $html = [regex]::Replace($html,$rxFormEnd,$chipBlock + "`r`n</form>",1)
    } else {
      $html = $html + "`r`n" + $chipBlock
    }
  }
}

# 6) Patch the Supabase insert/upsert for teams to include chip_number + flags
#    Only if landing.html contains the insert/upsert. Otherwise we add a reminder note.
$rxPatch = @'
(?is)(\.from\(\s*["']teams["']\s*\)\s*\.\s*(?:upsert|insert)\s*\(\s*\[\s*\{\s*)
'@
$inject = 'chip_number: ((document.getElementById("chip") && document.getElementById("chip").value) ? document.getElementById("chip").value.trim().toUpperCase() : ""), is_legion: (!!document.getElementById("legionFlag") && document.getElementById("legionFlag").checked), is_sons: (!!document.getElementById("sonsFlag") && document.getElementById("sonsFlag").checked), '
$before = $html
if ($html -notmatch '(?i)\bchip_number\b') {
  $html = [regex]::Replace($html,$rxPatch,"`$1$inject")
}

# Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Moved flags inline after Team Name, then Site #, and added Chip # before Add Team. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $file
