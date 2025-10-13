# add_flags_and_shrink_team_v2.ps1
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

function RX([string]$p){ return [regex]::new($p,[System.Text.RegularExpressions.RegexOptions] 'IgnoreCase, Singleline') }

# Remove any existing flags block we might have added before
$html = RX('(?is)<(?:div|span)[^>]*\bid\s*=\s*"wh-flags-mini"[^>]*>[\s\S]*?</(?:div|span)>').Replace($html,'')

# Flags snippet to insert
$flags = @'
<span id="wh-flags-mini" style="display:inline-flex;flex-direction:column;gap:4px;margin-right:8px;">
  <label style="display:inline-flex;align-items:center;gap:6px;"><input type="checkbox" id="legionFlag"> <span>Legion</span></label>
  <label style="display:inline-flex;align-items:center;gap:6px;"><input type="checkbox" id="sonsFlag"> <span>Sons</span></label>
</span>
'@

# --- Find Team input robustly ---
$teamInputHtml = $null
$teamInputIdx  = -1
$teamLabelHtml = $null
$teamLabelIdx  = -1

# 1) id="team" or id="teamName"
$rxTeamId = RX('(?is)(<input\b[^>]*\bid\s*=\s*["''](?:team|teamName)["''][^>]*>)')
$m = $rxTeamId.Match($html)
if ($m.Success) {
  $teamInputHtml = $m.Groups[1].Value; $teamInputIdx = $m.Index
  # If wrapped by a <label>, prefer to insert flags before the LABEL
  $esc = [regex]::Escape($teamInputHtml)
  $rxLbl = RX("(?is)(<label\b[^>]*>[\s\S]*?$esc[\s\S]*?</label>)")
  $lm = $rxLbl.Match($html)
  if ($lm.Success -and ($lm.Index -le $teamInputIdx) -and (($lm.Index+$lm.Length) -ge ($teamInputIdx+$m.Length))) {
    $teamLabelHtml = $lm.Groups[1].Value; $teamLabelIdx = $lm.Index
  }
}

# 2) Label containing “Team Name” / “Team” + an input
if (-not $teamInputHtml) {
  $rxLabelTeam = RX('(?is)(<label\b[^>]*>[\s\S]*?(?:Team\s*Name|Team)[\s\S]*?<input\b[^>]*>[\s\S]*?</label>)')
  $lm = $rxLabelTeam.Match($html)
  if ($lm.Success) {
    $teamLabelHtml = $lm.Groups[1].Value; $teamLabelIdx = $lm.Index
    # Grab the input inside it
    $im = RX('(?is)(<input\b[^>]*>)').Match($teamLabelHtml)
    if ($im.Success) { $teamInputHtml = $im.Groups[1].Value }
  }
}

# 3) Input with placeholder mentioning Team
if (-not $teamInputHtml) {
  $rxPH = RX('(?is)(<input\b[^>]*\bplaceholder\s*=\s*["''][^"'']*Team[^"'']*["''][^>]*>)')
  $pm = $rxPH.Match($html)
  if ($pm.Success) { $teamInputHtml = $pm.Groups[1].Value; $teamInputIdx = $pm.Index }
}

# 4) First reasonable text input in #teamForm that is not site/chip
if (-not $teamInputHtml) {
  $rxForm = RX('(?is)<form\b[^>]*\bid\s*=\s*["'']teamForm["''][^>]*>([\s\S]*?)</form>')
  $fm = $rxForm.Match($html)
  if ($fm.Success) {
    $formInner = $fm.Groups[1].Value
    $rxAnyTextInput = RX('(?is)(<input\b[^>]*type\s*=\s*["'']?(?:text|search|email|tel)?["'']?[^>]*>)')
    $inputs = @()
    $im = $rxAnyTextInput.Match($formInner)
    while ($im.Success) { $inputs += $im; $im = $im.NextMatch() }
    foreach($one in $inputs){
      $tag = $one.Groups[1].Value
      if ($tag -match '(?i)\bid\s*=\s*["''](?:site|site_number|siteNo|siteNum|chip)["'']') { continue }
      if ($tag -match '(?i)\bname\s*=\s*["''](?:site|chip)["'']') { continue }
      $teamInputHtml = $tag
      # compute absolute index inside $html
      $teamInputIdx = $fm.Index + $fm.Groups[1].Index + $one.Index
      break
    }
  }
}

if (-not $teamInputHtml) {
  throw "Could not reliably locate the Team Name input. (No id='team'/'teamName', no label/placeholder with 'Team', and no suitable text input found in #teamForm.)"
}

# --- Insert flags BEFORE the label (if found) or before the input tag ---
if ($teamLabelHtml) {
  $pre  = $html.Substring(0, $teamLabelIdx)
  $post = $html.Substring($teamLabelIdx)
  $html = $pre + $flags + $post
} else {
  $pre  = $html.Substring(0, $teamInputIdx)
  $post = $html.Substring($teamInputIdx)
  $html = $pre + $flags + $post
}

# After insertion, re-find the first occurrence of the same input to shrink it
$m2 = RX([regex]::Escape($teamInputHtml)).Match($html)
if ($m2.Success) {
  $teamTag = $m2.Groups[0].Value
  $newTeamTag = $teamTag
  # style="..."
  if ($newTeamTag -match '(?i)\bstyle\s*=\s*"([^"]*)"') {
    $cur = $Matches[1]
    if ($cur -match '(?i)\bwidth\s*:') {
      $cur = [regex]::Replace($cur,'(?i)\bwidth\s*:\s*[^;"]*','width:50%')
    } else { $cur = ($cur.TrimEnd(';') + ';width:50%') }
    $newTeamTag = [regex]::Replace($newTeamTag,'(?i)\bstyle\s*=\s*"[^"]*"',"style=""$cur""",1)
  }
  elseif ($newTeamTag -match "(?i)\bstyle\s*=\s*'([^']*)'") {
    $cur = $Matches[1]
    if ($cur -match '(?i)\bwidth\s*:') {
      $cur = [regex]::Replace($cur,'(?i)\bwidth\s*:\s*[^;'']*','width:50%')
    } else { $cur = ($cur.TrimEnd(';') + ';width:50%') }
    $newTeamTag = [regex]::Replace($newTeamTag,"(?i)\bstyle\s*=\s*'[^']*'","style='$cur'",1)
  }
  else {
    $newTeamTag = [regex]::Replace($newTeamTag,'(?i)^<input','<input style="width:50%"',1)
  }
  if ($newTeamTag -ne $teamTag) {
    $html = $html.Substring(0,$m2.Index) + $newTeamTag + $html.Substring($m2.Index + $m2.Length)
  }
}

# Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Added Legion/Sons checkboxes before Team field and set Team width to 50%. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
