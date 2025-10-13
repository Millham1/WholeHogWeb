# fix-landing-team-dup-and-judge-input.ps1  (PS 5.1 / 7)
param(
  [string]$WebRoot = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Read-Text([string]$Path){
  if(-not (Test-Path $Path)){ throw "File not found: $Path" }
  [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}
function Write-Text([string]$Path,[string]$Content){
  $dir = Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText($Path, $Content, [Text.Encoding]::UTF8)
}

$landing = Join-Path $WebRoot 'landing.html'
$cssPath = Join-Path $WebRoot 'styles.css'
if(-not (Test-Path $landing)){ throw "landing.html not found at $landing" }
if(-not (Test-Path $cssPath)){ throw "styles.css not found at $cssPath" }

# Backups
$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$landingBak = Join-Path $WebRoot ("BACKUP_landing_" + $stamp + ".html")
$cssBak     = Join-Path $WebRoot ("BACKUP_styles_"  + $stamp + ".css")
Copy-Item $landing $landingBak -Force
Copy-Item $cssPath $cssBak -Force
Write-Host "Backups saved:`n $landingBak`n $cssBak" -ForegroundColor Yellow

# ---------- 1) Remove duplicate Teams card (keep first) ----------
$html = Read-Text $landing
# Card block that has an H2 exactly "Teams"
$patTeamsCard = '(?is)<div[^>]*\bclass[^>]*\bcard\b[^>]*>\s*<h2[^>]*>\s*Teams\s*</h2>.*?</div>'
$matches = [regex]::Matches($html, $patTeamsCard)

if($matches.Count -gt 1){
  $toRemove = @()
  for($i=1; $i -lt $matches.Count; $i++){
    $m = $matches[$i]
    $toRemove += [pscustomobject]@{ Start=$m.Index; Length=$m.Length }
  }
  foreach($r in ($toRemove | Sort-Object Start -Descending)){
    $html = $html.Remove($r.Start, $r.Length)
  }
  Write-Host ("Removed {0} duplicate Teams card(s)." -f ($matches.Count-1)) -ForegroundColor Cyan
} else {
  Write-Host "No duplicate Teams card found (or only one present)." -ForegroundColor DarkGray
}

# ---------- 2) Re-enable Judges input/button ----------
# Remove disabled/readonly from the judge name input and the add-judge button.
# Use single-quoted regex strings; double single-quotes inside literals for ' characters.

# judge input id="judgeName"
$patInputJudgeDq_disabled = '(?is)(<input[^>]*\bid\s*=\s*"judgeName"[^>]*?)\s+disabled(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'
$patInputJudgeSq_disabled = '(?is)(<input[^>]*\bid\s*=\s*''judgeName''[^>]*?)\s+disabled(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'
$patInputJudgeDq_readonly = '(?is)(<input[^>]*\bid\s*=\s*"judgeName"[^>]*?)\s+readonly(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'
$patInputJudgeSq_readonly = '(?is)(<input[^>]*\bid\s*=\s*''judgeName''[^>]*?)\s+readonly(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'

# add judge button id="btnAddJudge"
$patBtnJudgeDq_disabled   = '(?is)(<button[^>]*\bid\s*=\s*"btnAddJudge"[^>]*?)\s+disabled(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'
$patBtnJudgeSq_disabled   = '(?is)(<button[^>]*\bid\s*=\s*''btnAddJudge''[^>]*?)\s+disabled(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'
$patBtnJudgeDq_readonly   = '(?is)(<button[^>]*\bid\s*=\s*"btnAddJudge"[^>]*?)\s+readonly(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'
$patBtnJudgeSq_readonly   = '(?is)(<button[^>]*\bid\s*=\s*''btnAddJudge''[^>]*?)\s+readonly(?:\s*=\s*(?:"[^"]*"|''[^'']*''))?'

$html2 = $html
foreach($pat in @(
  $patInputJudgeDq_disabled, $patInputJudgeSq_disabled,
  $patInputJudgeDq_readonly, $patInputJudgeSq_readonly,
  $patBtnJudgeDq_disabled,   $patBtnJudgeSq_disabled,
  $patBtnJudgeDq_readonly,   $patBtnJudgeSq_readonly
)){
  $html2 = [regex]::Replace($html2, $pat, '$1')
}

if($html2 -ne $html){
  $html = $html2
  Write-Host "Stripped disabled/readonly from judge input/button." -ForegroundColor Cyan
}

# ---------- 3) Small CSS guard so inputs are clickable ----------
$css = Read-Text $cssPath
$marker = '/* WH: judge input enable + safe overlay */'
if($css -notmatch [regex]::Escape($marker)){
  $addon = @"
$marker
#navRow{ position:relative; z-index: 1; }
header, .header, .site-header{ position:relative; z-index: 0; }
.card input, .card select, .card button, .card textarea { pointer-events:auto; }
"@
  $css = $css + "`r`n" + $addon + "`r`n"
  Write-Text $cssPath $css
  Write-Host "Appended small CSS guard to styles.css" -ForegroundColor Cyan
} else {
  Write-Host "CSS guard already present." -ForegroundColor DarkGray
}

# Save landing.html
Write-Text $landing $html
Write-Host "`nDone. Refresh landing.html (Ctrl+F5). Duplicate Teams card should be gone; Judges fields should accept input." -ForegroundColor Green


