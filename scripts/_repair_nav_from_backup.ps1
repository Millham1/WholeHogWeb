# _repair_nav_from_backup.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = "C:\Users\millh_y3006x1\Desktop\WholeHogWeb"
$file = Join-Path $root "landing.html"
if (!(Test-Path $file)) { throw "landing.html not found at $file" }

function Read-Text([string]$p){ Get-Content -LiteralPath $p -Raw -Encoding UTF8 }
function Get-LatestBackup([string]$orig){
  $pattern = [IO.Path]::GetFileName($orig) + ".*.bak"
  $dir = [IO.Path]::GetDirectoryName($orig)
  Get-ChildItem -LiteralPath $dir -Filter $pattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
function FindAnchorByText([string]$html, [string[]]$labels){
  foreach($lbl in $labels){
    # build tolerant regex: allow extra spaces/dashes between words
    $safe = [regex]::Escape($lbl).Replace("\ ","\s+").Replace("\-","\s*-\s*")
    $rx = [regex]::new("(?is)<a\b[^>]*>(?:(?!</a>).)*?$safe(?:(?!</a>).)*?</a>")
    $m = $rx.Match($html)
    if($m.Success){ return $m.Value }
  }
  $null
}
function Get-Class([string]$a){
  if($a -match 'class\s*=\s*"([^"]+)"'){ return $Matches[1] }
  elseif($a -match "class\s*=\s*'([^']+)'"){ return $Matches[1] }
  $null
}
function Normalize-Anchor([string]$a){
  if(-not $a){ return $a }
  $m = [regex]::Match($a,'(?is)^<a\b([^>]*)>')
  if(-not $m.Success){ return $a }
  $attrs = $m.Groups[1].Value
  $styleMatch = [regex]::Match($attrs,'(?is)\bstyle\s*=\s*"([^"]*)"')
  if ($styleMatch.Success) {
    $style = $styleMatch.Groups[1].Value
    if ($style -notmatch '(?i)\bdisplay\s*:')      { $style += ';display:inline-flex' }
    if ($style -notmatch '(?i)\balign-items\s*:')  { $style += ';align-items:center' }
    if ($style -notmatch '(?i)\bwidth\s*:')        { $style += ';width:auto!important' }
    if ($style -notmatch '(?i)\bwhite-space\s*:')  { $style += ';white-space:nowrap' }
    $newAttrs = [regex]::Replace($attrs,'(?is)\bstyle\s*=\s*"[^"]*"', 'style="' + $style + '"', 1)
  } else {
    $newAttrs = $attrs.TrimEnd() + ' style="display:inline-flex;align-items:center;width:auto!important;white-space:nowrap"'
  }
  return '<a' + $newAttrs + '>' + $a.Substring($m.Length)
}

# 1) Read current landing and strip any prior injected containers/duplicates
$html = Read-Text $file
# Remove older injected containers / scripts / stray leaderboard anchors
$html = [regex]::Replace($html,'(?is)<div[^>]*id\s*=\s*"(?:wholehog-nav|wholehog-leaderboard-btn)"[^>]*>[\s\S]*?</div>','')
$html = [regex]::Replace($html,'(?is)<!--\s*WHOLEHOG:.*?-->(?:(?!<!--\s*/WHOLEHOG\s*-->).)*?<!--\s*/WHOLEHOG\s*-->','')
$html = [regex]::Replace($html,'(?is)<script[^>]*id\s*=\s*"wholehog-nav-fix"[^>]*>[\s\S]*?</script>','')
$html = [regex]::Replace($html,'(?is)<a\b[^>]*>(?:(?!</a>).)*?Go\s*to\s*Leader\s*[-\s]*board(?:(?!</a>).)*?</a>','')

# 2) Try to recover original anchors from the most recent .bak
$bak = Get-LatestBackup $file
$onA = $null; $btA = $null
if($bak){
  $bakHtml = Read-Text $bak.FullName
  $onA = FindAnchorByText $bakHtml @('Go to On-Site','Go to On Site')
  $btA = FindAnchorByText $bakHtml @('Go to Blind Taste','Go to BlindTaste','Blind Taste')
}

# 3) If backups didn’t have them, try to find in current HTML
if(-not $onA){ $onA = FindAnchorByText $html @('Go to On-Site','Go to On Site') }
if(-not $btA){ $btA = FindAnchorByText $html @('Go to Blind Taste','Go to BlindTaste','Blind Taste') }

# 4) Build Leaderboard anchor using same class as Blind Taste (or On-Site), normalized
$leaderClass = if($btA){ Get-Class $btA } elseif($onA){ Get-Class $onA } else { "btn" }
$lbA = '<a href="./leaderboard.html" class="' + $leaderClass + '">Go to Leaderboard</a>'

# 5) Normalize anchors so CSS can’t stack them
$onA = Normalize-Anchor $onA
$btA = Normalize-Anchor $btA
$lbA = Normalize-Anchor $lbA

# 6) If we still don’t have the two originals, create reasonable fallbacks
if(-not $onA){ $onA = Normalize-Anchor('<a href="./on-site.html" class="' + $leaderClass + '">Go to On-Site</a>') }
if(-not $btA){ $btA = Normalize-Anchor('<a href="./blind-taste.html" class="' + $leaderClass + '">Go to Blind Taste</a>') }

# 7) Build one centered row in the correct order
$row = '<div id="wholehog-nav" style="width:100%;margin:12px auto;display:flex;justify-content:center;align-items:center;gap:12px;flex-wrap:wrap;text-align:center;">' +
       ($onA + " " + $btA + " " + $lbA) +
       '</div>'

# 8) Insert the row under the banner: after </header>, else after <body>, else prepend
$inserted = $false
$mh = [regex]::Match($html,'(?is)</header\s*>')
if ($mh.Success) {
  $idx = $mh.Index + $mh.Length
  $html = $html.Substring(0,$idx) + "`r`n" + $row + "`r`n" + $html.Substring($idx)
  $inserted = $true
} else {
  $mb = [regex]::Match($html,'(?is)<body\b[^>]*>')
  if ($mb.Success) {
    $idx = $mb.Index + $mb.Length
    $html = $html.Substring(0,$idx) + "`r`n" + $row + "`r`n" + $html.Substring($idx)
    $inserted = $true
  }
}
if (-not $inserted) { $html = $row + "`r`n" + $html }

# 9) Backup current + write
$bakOut = "$file.$((Get-Date).ToString('yyyyMMdd_HHmmss')).bak"
Copy-Item -LiteralPath $file -Destination $bakOut -Force
Set-Content -LiteralPath $file -Encoding UTF8 -Value $html

Write-Host "✅ Rebuilt centered 3-button row from backup/current, removed duplicates. Backup created: $([IO.Path]::GetFileName($bakOut))" -ForegroundColor Green
