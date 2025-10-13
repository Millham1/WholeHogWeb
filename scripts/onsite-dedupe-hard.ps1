param(
  [string]$Root = ".",
  [string]$OnsiteFile = "onsite.html"
)

$ErrorActionPreference = "Stop"

function Find-CI([string]$hay, [string]$needle, [int]$start = 0) {
  [System.Globalization.CultureInfo]::InvariantCulture.CompareInfo.IndexOf(
    $hay, $needle, $start, [System.Globalization.CompareOptions]::IgnoreCase
  )
}

# 0) Resolve path & load
$rootPath = Resolve-Path $Root
$sitePath = Join-Path $rootPath $OnsiteFile
if (!(Test-Path $sitePath)) { Write-Error "On-site page not found: $sitePath"; exit 1 }

Write-Host "Target page:" ([IO.Path]::GetFullPath($sitePath))
$html = Get-Content -Path $sitePath -Raw

# quick counters (case-insensitive)
function Count-Occur([string]$text, [string]$needle) {
  $low = $text.ToLowerInvariant(); $nd = $needle.ToLowerInvariant()
  $cnt=0; $i=0; while (($i = $low.IndexOf($nd, $i)) -ge 0) { $cnt++; $i++ }; return $cnt
}

# BEFORE stats
$beforeLanding = Count-Occur $html 'Go to Landing'
$beforeBoard   = Count-Occur $html 'Go to Leaderboard'
$beforeBlind   = Count-Occur $html 'Go to Blind Taste'
$beforeBars    = Count-Occur $html 'id="top-go-buttons'
Write-Host ("Before → Bars:{0}  Landing:{1}  Leaderboard:{2}  Blind:{3}" -f $beforeBars,$beforeLanding,$beforeBoard,$beforeBlind)

# 1) Remove ALL existing top-go-buttons containers
$low = $html.ToLowerInvariant()
while ($true) {
  $idIx = Find-CI $low 'id="top-go-buttons'
  if ($idIx -lt 0) { break }
  $divStart = $low.LastIndexOf('<div', $idIx)
  if ($divStart -lt 0) { break }
  $seek = $divStart
  # find matching </div> after this div (simple forward scan; adequate for this case)
  $endIx = Find-CI $low '</div>' $seek
  if ($endIx -lt 0) { break }
  $html = $html.Remove($divStart, ($endIx - $divStart) + 6)
  $low  = $html.ToLowerInvariant()
}

# 2) Remove ANY stray buttons whose inner text matches our three labels, anywhere on page
$labels = @('Go to Landing','Go to Leaderboard','Go to Blind Taste')
foreach ($label in $labels) {
  while ($true) {
    $low = $html.ToLowerInvariant()
    $ixLabel = Find-CI $low $label
    if ($ixLabel -lt 0) { break }
    # expand to enclosing <button ...> ... </button>
    $open = $low.LastIndexOf('<button', $ixLabel)
    $close = Find-CI $low '</button>' $ixLabel
    if ($open -ge 0 -and $close -ge 0) {
      $html = $html.Remove($open, ($close - $open) + 9)
    } else {
      # if not a button, try removing an <a ...> ... </a> with same label
      $openA = $low.LastIndexOf('<a', $ixLabel)
      $closeA = Find-CI $low '</a>' $ixLabel
      if ($openA -ge 0 -and $closeA -ge 0) {
        $html = $html.Remove($openA, ($closeA - $openA) + 4)
      } else {
        break
      }
    }
  }
}

# 3) Insert one canonical bar under </header> (or after <body>, else prepend)
$bar = @"
<div id="top-go-buttons" class="container" style="display:flex;gap:10px;align-items:center;justify-content:flex-start;margin-top:10px;margin-bottom:0;">
  <button type="button" class="btn btn-ghost" id="go-landing-top" onclick="location.href='landing.html'">Go to Landing</button>
  <button type="button" class="btn btn-ghost" id="go-leaderboard-top" onclick="location.href='leaderboard.html'">Go to Leaderboard</button>
  <button type="button" class="btn btn-ghost" id="go-blind-top" onclick="location.href='blind.html'">Go to Blind Taste</button>
</div>
"@

$low = $html.ToLowerInvariant()
$hdrIx = $low.IndexOf('</header>')
if ($hdrIx -ge 0) {
  $insertPos = $hdrIx + 9
  $html = $html.Substring(0,$insertPos) + "`r`n" + $bar + $html.Substring($insertPos)
} else {
  $bodyIx = Find-CI $html '<body'
  if ($bodyIx -ge 0) {
    $gtIx = $html.IndexOf('>', $bodyIx)
    if ($gtIx -ge 0) {
      $pos = $gtIx + 1
      $html = $html.Substring(0,$pos) + "`r`n" + $bar + $html.Substring($pos)
    } else {
      $html = $bar + "`r`n" + $html
    }
  } else {
    $html = $bar + "`r`n" + $html
  }
}

# 4) Backup + write, then AFTER stats
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = Join-Path $rootPath ("onsite.backup-" + $stamp + ".html")
Copy-Item $sitePath $backup -Force
$html | Set-Content -Path $sitePath -Encoding UTF8

$after = Get-Content -Path $sitePath -Raw
$afterLanding = Count-Occur $after 'Go to Landing'
$afterBoard   = Count-Occur $after 'Go to Leaderboard'
$afterBlind   = Count-Occur $after 'Go to Blind Taste'
$afterBars    = Count-Occur $after 'id="top-go-buttons'
Write-Host ("After  → Bars:{0}  Landing:{1}  Leaderboard:{2}  Blind:{3}" -f $afterBars,$afterLanding,$afterBoard,$afterBlind)
Write-Host "Backup saved to: $backup"
Write-Host ("Open: file:///" + ((Resolve-Path $sitePath).Path -replace '\\','/'))
