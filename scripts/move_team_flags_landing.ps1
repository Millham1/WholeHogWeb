# move_team_flags_landing.ps1
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

# 0) Add (or replace) a tiny style block so the flags are vertical and nicely sized
$styleBlock = @'
<style id="wh-team-flags-style">
  #wh-team-flags{
    margin:10px 0;
    display:flex;
    flex-direction:column;
    gap:6px;
    max-width:260px;     /* sized for looks */
  }
  #wh-team-flags label{
    display:flex; gap:8px; align-items:center;
    font-size:14px; color:#333;
  }
  #wh-team-flags input[type=checkbox]{ width:16px; height:16px; }
</style>
'@
$html = [regex]::Replace($html,'(?is)<style[^>]*\bid\s*=\s*"wh-team-flags-style"[^>]*>[\s\S]*?</style>','')
if ($html -match '(?is)</head>') {
  $html = [regex]::Replace($html,'(?is)</head>',$styleBlock + "`r`n</head>",1)
} else {
  $html = $styleBlock + "`r`n" + $html
}

# 1) Define the flags block (vertical)
$flagsBlock = @'
<div id="wh-team-flags">
  <label><input type="checkbox" id="legionFlag"> <span>Legion Team</span></label>
  <label><input type="checkbox" id="sonsFlag"> <span>Sons Team</span></label>
</div>
'@

# 2) Remove any existing flags block (we’ll re-insert in the correct spot)
$html = [regex]::Replace($html,'(?is)<div[^>]*\bid\s*=\s*"wh-team-flags"[^>]*>[\s\S]*?</div>','')

# 3) Insert flags immediately AFTER Team Name input and BEFORE Site #.
# Try several robust patterns (in order): id="team" input, a label containing "Team Name", or "Team".
$inserted = $false

# 3a) Insert after an <input ... id="team" ...>
$patternTeamId = @'
(?is)(<input\b[^>]*\bid\s*=\s*["']team["'][^>]*>)
'@
if (-not $inserted -and [regex]::IsMatch($html,$patternTeamId)) {
  $html = [regex]::Replace($html,$patternTeamId,"`$1`r`n$flagsBlock",1)
  $inserted = $true
}

# 3b) Insert after a label block that contains Team Name and its input
$patternLabelTeamName = @'
(?is)(<label\b[^>]*>[\s\S]*?Team\s*Name[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
if (-not $inserted -and [regex]::IsMatch($html,$patternLabelTeamName)) {
  $html = [regex]::Replace($html,$patternLabelTeamName,"`$1`r`n$flagsBlock",1)
  $inserted = $true
}

# 3c) Insert after a label containing "Team" and an input (generic)
$patternLabelTeam = @'
(?is)(<label\b[^>]*>[\s\S]*?Team[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
if (-not $inserted -and [regex]::IsMatch($html,$patternLabelTeam)) {
  $html = [regex]::Replace($html,$patternLabelTeam,"`$1`r`n$flagsBlock",1)
  $inserted = $true
}

# 3d) Fallback: if a Site # input exists, place flags right BEFORE it
$patternSite = @'
(?is)(<label\b[^>]*>[\s\S]*?(?:Site\s*#|Site\s*Number)[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)
'@
if (-not $inserted -and [regex]::IsMatch($html,$patternSite)) {
  $html = [regex]::Replace($html,$patternSite,"$flagsBlock`r`n`$1",1)
  $inserted = $true
}

# 3e) Last resort: insert near the top of the Teams card/form
if (-not $inserted) {
  $patternCard = @'
(?is)(<div\b[^>]*\bclass\s*=\s*"[^"]*\bcard\b[^"]*"[^>]*>)
'@
  if ([regex]::IsMatch($html,$patternCard)) {
    $html = [regex]::Replace($html,$patternCard,"`$1`r`n$flagsBlock",1)
  } else {
    $html = $flagsBlock + "`r`n" + $html
  }
}

# 4) Ensure the Supabase save includes the two flags (if not already patched earlier)
if ($html -notmatch '(?i)\bis_legion\b' -and $html -notmatch '(?i)\bis_sons\b') {
  $rxPatch = @'
(?is)(\.from\(\s*["']teams["']\s*\)\s*\.\s*(?:upsert|insert)\s*\(\s*\[\s*\{\s*)
'@
  $inject = 'is_legion: (!!document.getElementById("legionFlag") && document.getElementById("legionFlag").checked), is_sons: (!!document.getElementById("sonsFlag") && document.getElementById("sonsFlag").checked), '
  $html = [regex]::Replace($html, $rxPatch, "`$1$inject")
}

# 5) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Checkboxes moved: after Team Name, before Site #, stacked vertically, sized. Backup: $([IO.Path]::GetFileName($bak))" -ForegroundColor Green
Start-Process $file
