param(
  [string]$Root = ".",
  [string]$BlindFile = "blind.html",
  # Change this if your on-site page has a different filename:
  [string]$OnsiteHref = "onsite.html"
)

$ErrorActionPreference = "Stop"

$rootPath  = Resolve-Path $Root
$blindPath = Join-Path $rootPath $BlindFile

if (!(Test-Path $blindPath)) {
  Write-Error "blind file not found: $blindPath"
  exit 1
}

# Read file
$html = Get-Content -Path $blindPath -Raw

# If the On-site button already exists, exit quietly
if ($html -match 'id\s*=\s*"go-onsite-top"') {
  Write-Host "On-site button already present. Nothing to do."
  exit 0
}

# The button we want to add
$onsiteBtn = "  <button type=""button"" class=""btn btn-ghost"" id=""go-onsite-top"" onclick=""location.href='$OnsiteHref'"">Go to On-site</button>"

# 1) Try to add inside existing top-go-buttons block before its closing </div>
$blockRegex = [regex]'(?is)<div\b[^>]*id\s*=\s*"(?:top-go-buttons)"[^>]*>(.*?)</div>'
$match = $blockRegex.Match($html)
if ($match.Success) {
  $fullBlock = $match.Value
  $inner     = $match.Groups[1].Value
  # If inner already contains the onsite button, do nothing
  if ($inner -match 'id\s*=\s*"go-onsite-top"') {
    Write-Host "On-site button already present inside top-go-buttons. Nothing to do."
    exit 0
  }

  # Insert our button just before the closing </div>
  $injectedInner = $inner.TrimEnd() + "`r`n$onsiteBtn`r`n"
  $newBlock = ($fullBlock -replace [regex]::Escape($inner), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $injectedInner })

  # Replace the old block with the new one at the same location
  $updated = $html.Remove($match.Index, $match.Length).Insert($match.Index, $newBlock)

  # Backup and write
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  Copy-Item $blindPath (Join-Path $rootPath ("blind.backup-" + $stamp + ".html")) -Force
  $updated | Set-Content -Path $blindPath -Encoding UTF8

  Write-Host "✅ Added On-site button inside existing top-go-buttons."
  Write-Host ("Open: file:///" + ((Resolve-Path $blindPath).Path -replace '\\','/'))
  exit 0
}

# 2) If block not present, create the full block right below </header>
$block = @"
<div id=""top-go-buttons"" class=""container"" style=""display:flex;gap:10px;align-items:center;justify-content:flex-start;margin-top:10px;margin-bottom:0;"">
  <button type=""button"" class=""btn btn-ghost"" id=""go-landing-top"" onclick=""location.href='landing.html'"">Go to Landing</button>
  <button type=""button"" class=""btn btn-ghost"" id=""go-leaderboard-top"" onclick=""location.href='leaderboard.html'"">Go to Leaderboard</button>
$onsiteBtn
</div>
"@

$afterHeaderRegex = '(?is)(</header\s*>)'
if ($html -match $afterHeaderRegex) {
  $updated = [regex]::Replace($html, $afterHeaderRegex, '$1' + "`r`n" + $block, 1)

  # Backup and write
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  Copy-Item $blindPath (Join-Path $rootPath ("blind.backup-" + $stamp + ".html")) -Force
  $updated | Set-Content -Path $blindPath -Encoding UTF8

  Write-Host "✅ Created top-go-buttons and added all three buttons below the header."
  Write-Host ("Open: file:///" + ((Resolve-Path $blindPath).Path -replace '\\','/'))
} else {
  Write-Error "Couldn't find </header> in blind.html to place the buttons under."
}
