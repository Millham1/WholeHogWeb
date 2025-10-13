# add_flags_and_shrink_team.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

# 1) Backup
$bak = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bak -Force

# 2) Read
$html = Get-Content -LiteralPath $file -Raw -Encoding UTF8

# 3) If we already added flags before, skip re-insert
$hasFlags = $html -match '(?i)\bid\s*=\s*"wh-flags-mini"'

# 4) Find the Team input (id="team" or "teamName")
$rxTeamInput = @'
(?is)(<input\b[^>]*\bid\s*=\s*["'](?:team|teamName)["'][^>]*>)
'@
$m = [regex]::Match($html, $rxTeamInput)
if (-not $m.Success) {
  throw "Could not find the Team Name input (id=""team"" or id=""teamName"")."
}

# 5) Insert the two checkboxes immediately BEFORE the Team input (left side)
if (-not $hasFlags) {
  $flags = @'
<span id="wh-flags-mini" style="display:inline-flex;flex-direction:column;gap:4px;margin-right:8px;">
  <label style="display:inline-flex;align-items:center;gap:6px;"><input type="checkbox" id="legionFlag"> <span>Legion</span></label>
  <label style="display:inline-flex;align-items:center;gap:6px;"><input type="checkbox" id="sonsFlag"> <span>Sons</span></label>
</span>
'@
  $html = [regex]::Replace($html, $rxTeamInput, $flags + '`$1', 1)
  # re-match to get the (now) first team input tag after insertion
  $m = [regex]::Match($html, $rxTeamInput)
}

# 6) Shrink Team input width by half (append or add inline style)
$teamTag = $m.Groups[1].Value
$newTeamTag = $teamTag

# Handle double-quoted style
if ($newTeamTag -match '(?i)\bstyle\s*=\s*"([^"]*)"') {
  $cur = $Matches[1]
  if ($cur -notmatch '(?i)\bwidth\s*:') { $cur += ';width:50%' }
  else { $cur = [regex]::Replace($cur, '(?i)\bwidth\s*:\s*[^;"]*', 'width:50%') }
  $newTeamTag = [regex]::Replace($newTeamTag, '(?i)\bstyle\s*=\s*"[^"]*"', "style=""$cur""", 1)
}
# Handle single-quoted style
elseif ($newTeamTag -match "(?i)\bstyle\s*=\s*'([^']*)'") {
  $cur = $Matches[1]
  if ($cur -notmatch '(?i)\bwidth\s*:') { $cur += ';width:50%' }
  else { $cur = [regex]::Replace($cur, '(?i)\bwidth\s*:\s*[^;'']*', 'width:50%') }
  $newTeamTag = [regex]::Replace($newTeamTag, "(?i)\bstyle\s*=\s*'[^']*'", "style='$cur'", 1)
}
# No style attribute: add one
else {
  $newTeamTag = [regex]::Replace($newTeamTag, '(?i)^\s*<input', '<input style="width:50%"', 1)
}

# Replace the original team input with the resized one
if ($newTeamTag -ne $teamTag) {
  $html = $html.Replace($teamTag, $newTeamTag)
}

# 7) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Added Legion/Sons checkboxes to the left of Team Name and shrank Team field to 50%. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
