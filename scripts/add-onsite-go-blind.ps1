param(
  [string]$Root = ".",
  [string]$OnsiteFile = "onsite.html"  # change if your file has a different name
)

$ErrorActionPreference = "Stop"

$rootPath  = Resolve-Path $Root
$sitePath  = Join-Path $rootPath $OnsiteFile
if (!(Test-Path $sitePath)) {
  Write-Error "On-site page not found: $sitePath"
  exit 1
}

# Read file
$html = Get-Content -Path $sitePath -Raw

# If button already exists, exit quietly
if ($html -match 'id\s*=\s*"go-blind-top"') {
  Write-Host "Go to Blind Taste button already present. Nothing to do."
  exit 0
}

# Block to insert just BELOW </header>
$block = @"
<div id=""top-go-blind"" class=""container"" style=""display:flex;gap:10px;align-items:center;justify-content:flex-start;margin-top:10px;margin-bottom:0;"">
  <button type=""button"" class=""btn btn-ghost"" id=""go-blind-top"" onclick=""location.href='blind.html'"">Go to Blind Taste</button>
</div>
"@

# Prefer to insert right after the first closing </header>
$lower = $html.ToLowerInvariant()
$hdrIx = $lower.IndexOf("</header>")
if ($hdrIx -ge 0) {
  $insertPos = $hdrIx + 9  # length of "</header>"
  $updated = $html.Substring(0,$insertPos) + "`r`n" + $block + $html.Substring($insertPos)
}
else {
  # Fallback: insert at start of <body> (after <body ...>)
  $bodyOpen = [regex]::Match($html, '(?is)<body\b[^>]*>')
  if ($bodyOpen.Success) {
    $pos = $bodyOpen.Index + $bodyOpen.Length
    $updated = $html.Substring(0,$pos) + "`r`n" + $block + $html.Substring($pos)
  } else {
    # Last fallback: prepend at top
    $updated = $block + "`r`n" + $html
  }
}

# Backup and write back
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $sitePath (Join-Path $rootPath ("onsite.backup-" + $stamp + ".html")) -Force
$updated | Set-Content -Path $sitePath -Encoding UTF8

Write-Host "✅ Added 'Go to Blind Taste' button below the header in ${OnsiteFile}."
Write-Host ("Open: file:///" + ((Resolve-Path $sitePath).Path -replace '\\','/'))
