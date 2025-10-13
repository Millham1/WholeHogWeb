param(
  [Parameter(Mandatory=$true)] [string]$Onsite,
  [Parameter(Mandatory=$true)] [string]$Leaderboard
)

function Read-Utf8([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-Utf8([string]$p,[string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p,$s,$enc)
}

if (!(Test-Path $Onsite))      { throw "Onsite file not found: $Onsite" }
if (!(Test-Path $Leaderboard)) { throw "Leaderboard file not found: $Leaderboard" }

# Backups
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$onsiteBak = "$Onsite.$stamp.bak"
$leaderBak = "$Leaderboard.$stamp.bak"
Copy-Item $Onsite $onsiteBak -Force
Copy-Item $Leaderboard $leaderBak -Force
Write-Host "🔒 Backed up:"
Write-Host "  - $onsiteBak"
Write-Host "  - $leaderBak"

# Read files
$onsiteHtml = Read-Utf8 $Onsite
$leaderHtml = Read-Utf8 $Leaderboard

# Pattern: the exact card we saw in onsite (card leader with <h2>Leaderboard</h2> and #leaderWrap)
$cardPat = '(?is)\s*<div\s+class\s*=\s*["'']card\s+leader["'']\s*>\s*<h2>\s*Leaderboard\s*</h2>\s*<div[^>]*\bid\s*=\s*["'']leaderWrap["''][^>]*>\s*</div>\s*</div>\s*'

$cardMatch = [regex]::Match($onsiteHtml, $cardPat)
if (-not $cardMatch.Success) {
  Write-Host "⚠️  No matching leader card found in onsite.html; nothing moved."
  Write-Host "    (Looking for <div class=""card leader""><h2>Leaderboard</h2><div id=""leaderWrap"">…)"
  exit 0
}

$cardBlock = $cardMatch.Value

# Prepare moved block: only change the H2 text to "onsite leaders"
$renamedBlock = [regex]::Replace($cardBlock, '(?is)(<h2>)(.*?)(</h2>)', '$1onsite leaders$3', 1)

# Remove the card from onsite
$onsiteNew = [regex]::Replace($onsiteHtml, $cardPat, '', 1)

# Insert the card into leaderboard.html:
# 1) Prefer placing right after the first <div class="container"> open tag
# 2) If not present, place right before </body>
$containerOpenPat = '(?is)(<div\s+class\s*=\s*["'']container["''][^>]*>)'
if ([regex]::IsMatch($leaderHtml, $containerOpenPat)) {
  $leaderNew = [regex]::Replace($leaderHtml, $containerOpenPat, { param($m) $m.Groups[1].Value + "`r`n" + $renamedBlock }, 1)
  $insertWhere = 'after first <div class="container">'
} elseif ([regex]::IsMatch($leaderHtml, '(?is)</body\s*>')) {
  $leaderNew = [regex]::Replace($leaderHtml, '(?is)</body\s*>', { param($m) $renamedBlock + "`r`n" + $m.Value }, 1)
  $insertWhere = 'before </body>'
} else {
  $leaderNew = $leaderHtml + "`r`n" + $renamedBlock
  $insertWhere = 'at end of file (no </body> found)'
}

# Write back
Write-Utf8 $Onsite $onsiteNew
Write-Utf8 $Leaderboard $leaderNew

Write-Host "✅ Moved leader card:"
Write-Host "  • Removed from: $Onsite"
Write-Host "  • Inserted into: $Leaderboard ($insertWhere)"
Write-Host "  • Renamed heading to: ""onsite leaders"""
