param(
  [string]$File = "onsite.html"
)

# Read/Write helpers (UTF-8 no BOM)
function Read-All([string]$p){
  $enc = New-Object System.Text.UTF8Encoding($false)
  return [System.IO.File]::ReadAllText((Resolve-Path $p), $enc)
}
function Write-All([string]$p,[string]$s){
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($p, $s, $enc)
}

if (!(Test-Path $File)) { throw "File not found: $File" }

# Backup
$backupDir = "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
Copy-Item $File (Join-Path $backupDir ("{0}_{1}" -f (Split-Path $File -Leaf), $stamp)) -ErrorAction SilentlyContinue

$html = Read-All $File

# 1) If the malformed container exists (the obvious duplicate), drop that whole block.
$malformedBlock = '(?is)\s*<div id=""top-go-blind""[^>]*>.*?</div>\s*'
if ([regex]::IsMatch($html, $malformedBlock)) {
  $html = [regex]::Replace($html, $malformedBlock, "", 1)
} else {
  # 2) Otherwise, remove only the SECOND "Go to Blind Taste" button (id="go-blind-top")
  $btnPattern = '(?is)<button\b[^>]*id\s*=\s*["'']go-blind-top["''][^>]*>.*?Go to Blind Taste.*?</button>\s*'
  $matches = [regex]::Matches($html, $btnPattern)
  if ($matches.Count -gt 1) {
    $m = $matches[1]  # second occurrence
    $html = $html.Remove($m.Index, $m.Length)
  } else {
    Write-Host "No duplicate 'Go to Blind Taste' button found (nothing changed)."
  }
}

Write-All $File $html
Write-Host "✅ Removed the second 'Go to Blind Taste' button. Everything else left untouched."
