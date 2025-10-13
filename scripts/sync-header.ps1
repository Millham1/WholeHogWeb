[CmdletBinding()]
param(
  [string]$Root = ".",
  [string]$Source = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

function New-Backup([Parameter(Mandatory)][string]$Path){
  if (Test-Path -LiteralPath $Path) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp" -Force
    Write-Host "Backup created: $Path.bak-$stamp"
  }
}

function Get-HeaderHtml([string]$Html){
  $m = [Regex]::Match($Html, '<header\b[^>]*>.*?</header>', 'IgnoreCase,Singleline')
  if ($m.Success) { $m.Value } else { $null }
}

function Set-Header([string]$Html, [string]$HeaderHtml){
  if ([string]::IsNullOrWhiteSpace($HeaderHtml)) { return $Html }
  # remove any existing header
  $html2 = [Regex]::Replace($Html, '<header\b[^>]*>.*?</header>', '', 'IgnoreCase,Singleline')
  # insert after <body ...>
  if ([Regex]::IsMatch($html2, '(<body[^>]*>)', 'IgnoreCase')) {
    return [Regex]::Replace($html2, '(<body[^>]*>)', '$1' + "`r`n" + $HeaderHtml, 'IgnoreCase')
  }
  return $HeaderHtml + "`r`n" + $html2
}

function Ensure-HeadIncludes([string]$DstHtml, [string]$SrcHtml){
  $srcHead = [Regex]::Match($SrcHtml, '<head\b[^>]*>.*?</head>', 'IgnoreCase,Singleline').Value
  if (-not $srcHead) { return $DstHtml }
  if (-not [Regex]::IsMatch($DstHtml, '</head\s*>', 'IgnoreCase')) { return $DstHtml }

  $toAdd = @()

  # Stylesheets
  $styleMatches = [Regex]::Matches($srcHead, '<link[^>]*rel\s*=\s*["'']stylesheet["''][^>]*href\s*=\s*["'']([^"''>]+)["''][^>]*>', 'IgnoreCase')
  foreach ($m in $styleMatches) {
    $url = $m.Groups[1].Value
    if ($url -and ($DstHtml -notmatch [Regex]::Escape($url))) {
      $toAdd += "<link rel=""stylesheet"" href=""$url"">"
    }
  }

  # Scripts
  $scriptMatches = [Regex]::Matches($srcHead, '<script[^>]*src\s*=\s*["'']([^"''>]+)["''][^>]*>\s*</script>', 'IgnoreCase')
  foreach ($m in $scriptMatches) {
    $url = $m.Groups[1].Value
    if ($url -and ($DstHtml -notmatch [Regex]::Escape($url))) {
      $toAdd += "<script defer src=""$url""></script>"
    }
  }

  if ($toAdd.Count -gt 0) {
    $insertion = '  ' + ($toAdd -join "`r`n  ") + "`r`n"
    return [Regex]::Replace($DstHtml, '</head\s*>', $insertion + '</head>', 'IgnoreCase')
  }
  return $DstHtml
}

# --- Normalize and find files
$Root = (Resolve-Path -LiteralPath $Root).Path
Set-Location -LiteralPath $Root
Write-Host "Working in: $Root"

$candidates = @()
if ($Source) {
  $candidates += (Join-Path $Root $Source)
} else {
  $candidates += @(
    "onsite.html","on-site.html","on_site.html",
    "onsitetasting.html","onsite-tasting.html","on-site-tasting.html",
    "OnSite.html","On-Site.html","index.html"
  ) | ForEach-Object { Join-Path $Root $_ }
}
$sourcePath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $sourcePath) { throw "No source page found. Use -Source 'onsite.html' (or correct filename)." }

$targetPath = Join-Path $Root "leaderboard.html"
if (-not (Test-Path -LiteralPath $targetPath)) { throw "leaderboard.html not found." }

# --- Read / extract / apply
$srcHtml = Get-Content -LiteralPath $sourcePath -Raw
$hdr = Get-HeaderHtml $srcHtml
if (-not $hdr) { throw "No <header>...</header> block found in $([IO.Path]::GetFileName($sourcePath))." }

$dstHtml = Get-Content -LiteralPath $targetPath -Raw
New-Backup -Path $targetPath
$dstHtml = Set-Header -Html $dstHtml -HeaderHtml $hdr
$dstHtml = Ensure-HeadIncludes -DstHtml $dstHtml -SrcHtml $srcHtml
[IO.File]::WriteAllText($targetPath, $dstHtml, $Utf8NoBom)

# --- Preview (safe, no parser issues)
$flat = [Regex]::Replace($hdr, '\s+', ' ')
$preview = if ($flat.Length -gt 120) { $flat.Substring(0,120) + '…' } else { $flat }
Write-Host "`n✅ Header synced to leaderboard.html"
Write-Host ("Source:  {0}" -f [IO.Path]::GetFileName($sourcePath))
Write-Host ("Target:  {0}" -f [IO.Path]::GetFileName($targetPath))
Write-Host ("Preview: {0}" -f $preview)

