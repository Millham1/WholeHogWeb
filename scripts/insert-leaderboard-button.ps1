[CmdletBinding()]
param([string]$Root = ".")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Utf8 = [Text.UTF8Encoding]::new($false)

function New-Backup([Parameter(Mandatory)][string]$Path){
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
    Write-Host "Backup created: $Path.bak-$stamp"
  }
}

# --- Load index.html
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$index    = Join-Path $rootPath "index.html"
if (!(Test-Path -LiteralPath $index)) { throw "index.html not found at: $index" }

$html = Get-Content -LiteralPath $index -Raw

# --- Grab all <a ...>...</a> and <button ...>...</button>
$reAnchor  = '(?is)<a\b[^>]*>.*?<\/a>'
$reButton  = '(?is)<button\b[^>]*>.*?<\/button>'
$matches   = @()
$matches  += [regex]::Matches($html, $reAnchor)
$matches  += [regex]::Matches($html, $reButton)
$matches   = $matches | Sort-Object Index

if ($matches.Count -eq 0) { throw "No <a> or <button> elements found in index.html" }

function Strip-Tags([string]$s){
  if (-not $s) { return "" }
  $x = [regex]::Replace($s, '<[^>]+>', '')
  $x = $x.Replace('&nbsp;',' ').Replace('&amp;','&')
  return ([regex]::Replace($x, '\s+', ' ')).Trim()
}
function Get-Inner([string]$outer,[string]$tag){
  $gt = $outer.IndexOf('>')
  $endTag = "</$tag>"
  $end = $outer.ToLowerInvariant().LastIndexOf($endTag)
  if ($gt -ge 0 -and $end -gt $gt) { return $outer.Substring($gt+1, $end - ($gt+1)) }
  return ""
}
function Get-Href([string]$outer){
  $low = $outer.ToLowerInvariant()
  $i = $low.IndexOf('href=')
  if ($i -lt 0) { return "" }
  $q = $outer.Substring($i+5,1)
  if ($q -ne '"' -and $q -ne "'") { return "" }
  $start = $i + 6
  $end   = $outer.IndexOf($q, $start)
  if ($end -lt 0) { return "" }
  return $outer.Substring($start, $end - $start)
}

# Build a list with previews
$items = @()
for ($i=0; $i -lt $matches.Count; $i++){
  $m = $matches[$i]
  $outer = $m.Value
  $isAnchor = $outer.TrimStart().StartsWith("<a", [System.StringComparison]::OrdinalIgnoreCase)
  $tag = $isAnchor ? "a" : "button"
  $inner = Get-Inner $outer $tag
  $text  = Strip-Tags $inner
  $href  = $isAnchor ? (Get-Href $outer) : ""
  $aroundStart = [Math]::Max(0, $m.Index - 60)
  $aroundEnd   = [Math]::Min($html.Length, $m.Index + $m.Length + 60)
  $around = $html.Substring($aroundStart, $aroundEnd - $aroundStart) -replace '\s+',' '
  if ($around.Length -gt 120) { $around = $around.Substring(0,120) + "…" }
  $items += [PSCustomObject]@{Idx=$i; Start=$m.Index; End=$m.Index+$m.Length; Tag=$tag; Href=$href; Text=$text; Outer=$outer; Around=$around}
}

# Show a menu of candidates
Write-Host "`n=== Found buttons/links on index.html ===" -ForegroundColor Cyan
$items | ForEach-Object {
  $hrefPart = ""
  if ($_.Href) { $hrefPart = " | href=$($_.Href)" }
  Write-Host ("[{0}] <{1}>{2} | text='{3}'" -f $_.Idx, $_.Tag, $hrefPart, $_.Text)
  Write-Host ("     {0}" -f $_.Around) -ForegroundColor DarkGray
}

Write-Host ""
$sel = Read-Host "Enter the number(s) of the buttons that sit together (e.g., 3,4). If only one is relevant, enter just that number"
if (-not $sel) { throw "No selection made." }
$nums = @()
foreach ($p in ($sel -split '[,; ]+')) {
  if ([string]::IsNullOrWhiteSpace($p)) { continue }
  $n = 0
  if ([int]::TryParse($p.Trim(), [ref]$n)) { $nums += $n }
}
$nums = $nums | Sort-Object -Unique
if ($nums.Count -lt 1) { throw "Invalid selection." }

# Validate selection indices
foreach ($n in $nums){ if ($n -lt 0 -or $n -ge $items.Count){ throw "Selection $n is out of range." } }

# Choose a template to clone (first selected)
$template = $items[$nums[0]]
$insertAfter = ($nums | ForEach-Object { $items[$_] } | Measure-Object End -Maximum).Maximum

# Build new Leaderboard element by cloning the template
$new = $template.Outer
if ($template.Tag -eq 'a') {
  # Ensure href="leaderboard.html"
  $low = $new.ToLowerInvariant()
  if ($low.Contains('href="')) {
    $s = $low.IndexOf('href="') + 6
    $e = $new.IndexOf('"', $s); if ($e -lt 0) { $e = $s }
    $new = $new.Substring(0,$s) + 'leaderboard.html' + $new.Substring($e)
  } elseif ($low.Contains("href='")) {
    $s = $low.IndexOf("href='") + 6
    $e = $new.IndexOf("'", $s); if ($e -lt 0) { $e = $s }
    $new = $new.Substring(0,$s) + 'leaderboard.html' + $new.Substring($e)
  } else {
    $gt = $new.IndexOf('>')
    if ($gt -gt 0) {
      $before = $new.Substring(0,$gt)
      $after  = $new.Substring($gt)
      $space  = ($before.EndsWith(' ') ? '' : ' ')
      $new    = $before + $space + 'href="leaderboard.html"' + $after
    }
  }
  # Replace inner text to "Go to Leaderboard"
  $gt2 = $new.IndexOf('>')
  $end = $new.ToLowerInvariant().LastIndexOf('</a>')
  if ($gt2 -ge 0 -and $end -gt $gt2) {
    $new = $new.Substring(0,$gt2+1) + 'Go to Leaderboard' + $new.Substring($end)
  }
} else {
  # <button> -> keep classes, add/replace onclick to navigate
  $low = $new.ToLowerInvariant()
  if ($low.Contains('onclick=')) {
    $q = $new.Substring($low.IndexOf('onclick=') + 8, 1)
    $start = $low.IndexOf('onclick=') + 9
    $endq  = $new.IndexOf($q, $start); if ($endq -lt 0) { $endq = $start }
    $new = $new.Substring(0,$start) + "location.href='leaderboard.html'" + $new.Substring($endq)
  } else {
    $gt = $new.IndexOf('>')
    if ($gt -gt 0) {
      $before = $new.Substring(0,$gt)
      $after  = $new.Substring($gt)
      $space  = ($before.EndsWith(' ') ? '' : ' ')
      $new    = $before + $space + "onclick=""location.href='leaderboard.html'""" + $after
    }
  }
  # Replace inner text
  $gt3 = $new.IndexOf('>')
  $endb= $new.ToLowerInvariant().LastIndexOf('</button>')
  if ($gt3 -ge 0 -and $endb -gt $gt3) {
    $new = $new.Substring(0,$gt3+1) + 'Go to Leaderboard' + $new.Substring($endb)
  }
}

# Insert after the last of the selected items
New-Backup -Path $index
$html = $html.Substring(0,$insertAfter) + "`r`n  " + $new + $html.Substring($insertAfter)
[IO.File]::WriteAllText($index, $html, $Utf8)

Write-Host "`n✅ Inserted 'Go to Leaderboard' next to the selected button(s). Refresh the landing page to see it."

