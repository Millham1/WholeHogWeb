# add_flags_and_shrink_team_v3.ps1
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

# 3) Remove any prior flags we may have added (to avoid duplicates)
$html = [regex]::Replace($html,'(?is)<(?:div|span)[^>]*\bid\s*=\s*"wh-flags-mini"[^>]*>[\s\S]*?</(?:div|span)>','')

# 4) Build flags block
$flags = @'
<span id="wh-flags-mini" style="display:inline-flex;flex-direction:column;gap:4px;margin-right:8px;">
  <label style="display:inline-flex;align-items:center;gap:6px;"><input type="checkbox" id="legionFlag"> <span>Legion</span></label>
  <label style="display:inline-flex;align-items:center;gap:6px;"><input type="checkbox" id="sonsFlag"> <span>Sons</span></label>
</span>
'@

# 5) Find the first reasonable "Team Name" candidate input anywhere in the page
#    (text-like input; NOT site/chip/judge/score/email/phone/search/filter)
$inputPattern = '(?is)<input\b[^>]*>'
$matches = [regex]::Matches($html, $inputPattern)

function Get-Attr([string]$tag,[string]$name){
  $m = [regex]::Match($tag, '(?i)\b' + [regex]::Escape($name) + '\s*=\s*"([^"]*)"')
  if($m.Success){ return $m.Groups[1].Value }
  $m = [regex]::Match($tag, "(?i)\b" + [regex]::Escape($name) + "\s*=\s*'([^']*)'")
  if($m.Success){ return $m.Groups[1].Value }
  return $null
}

$exclude = 'site|chip|judge|score|email|phone|search|filter'
$candidate = $null
foreach($m in $matches){
  $tag = $m.Value
  # type
  $type = (Get-Attr $tag 'type')
  if ([string]::IsNullOrWhiteSpace($type)) { $type = 'text' } # default is text-like
  if ($type -match '^(hidden|submit|button|reset|file|checkbox|radio|date|datetime|datetime-local|month|week|time|color|password|number)$') { continue }
  # id/name/placeholder check
  $id  = (Get-Attr $tag 'id')
  $nm  = (Get-Attr $tag 'name')
  $ph  = (Get-Attr $tag 'placeholder')
  $combo = (($id,$nm,$ph) -join ' ').ToLower()
  if ($combo -match $exclude) { continue }
  # Looks good — treat as Team Name input
  $candidate = [pscustomobject]@{ Index = $m.Index; Length = $m.Length; Tag = $tag }
  break
}

if (-not $candidate) {
  throw "Could not find a safe text-like Team Name input (skipping site/chip/judge/score/email/phone/search/filter)."
}

# 6) Insert flags BEFORE the candidate input
$html = $html.Substring(0, $candidate.Index) + $flags + $html.Substring($candidate.Index)

# 7) Re-find the candidate input tag (exact text) after insertion, then set width:50%
$teamTag = $candidate.Tag
$escaped = [regex]::Escape($teamTag)
$m2 = [regex]::Match($html, $escaped, 'IgnoreCase,Singleline')
if ($m2.Success) {
  $newTag = $teamTag

  # Add or edit style="...width:50%..."
  $mStyle = [regex]::Match($newTag,'(?i)\bstyle\s*=\s*"([^"]*)"')
  if ($mStyle.Success) {
    $cur = $mStyle.Groups[1].Value
    if ($cur -match '(?i)\bwidth\s*:') {
      $cur = [regex]::Replace($cur,'(?i)\bwidth\s*:\s*[^;"]*','width:50%')
    } else {
      if ($cur.TrimEnd() -notmatch ';$') { $cur += ';' }
      $cur += 'width:50%'
    }
    $newTag = [regex]::Replace($newTag,'(?i)\bstyle\s*=\s*"[^"]*"',"style=""$cur""",1)
  } else {
    $mStyle2 = [regex]::Match($newTag,"(?i)\bstyle\s*=\s*'([^']*)'")
    if ($mStyle2.Success) {
      $cur = $mStyle2.Groups[1].Value
      if ($cur -match '(?i)\bwidth\s*:') {
        $cur = [regex]::Replace($cur,'(?i)\bwidth\s*:\s*[^;'']*','width:50%')
      } else {
        if ($cur.TrimEnd() -notmatch ';$') { $cur += ';' }
        $cur += 'width:50%'
      }
      $newTag = [regex]::Replace($newTag,"(?i)\bstyle\s*=\s*'[^']*'","style='$cur'",1)
    } else {
      # no style at all -> add one
      $newTag = [regex]::Replace($newTag,'(?i)^<input','<input style="width:50%"',1)
    }
  }

  # Replace only this occurrence
  $html = $html.Substring(0,$m2.Index) + $newTag + $html.Substring($m2.Index + $m2.Length)
} else {
  # Should not happen; continue without width change
  Write-Host "⚠️ Inserted flags, but couldn't re-find the team input to set width." -ForegroundColor Yellow
}

# 8) Write back
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html
Write-Host "✅ Added Legion/Sons checkboxes to the left of Team Name and set Team width to 50%. Backup: $([IO.Path]::GetFileName($bak))"
Start-Process $file
