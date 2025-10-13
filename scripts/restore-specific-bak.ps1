param(
  [string]$Root = ".",
  [string]$TargetFile = "blind.html",
  # Exact backup file name you provided:
  [string]$BakFileName = "blind-taste.html.20251010_222912.bak"
)

$ErrorActionPreference = "Stop"

# Resolve paths
$RootPath  = Resolve-Path $Root
$Target    = Join-Path $RootPath $TargetFile
$BakPath   = Join-Path $RootPath $BakFileName

# If not in the root, try to find it anywhere under Root
if (!(Test-Path $BakPath)) {
  $match = Get-ChildItem -Path $RootPath -Recurse -Filter $BakFileName -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($match) { $BakPath = $match.FullName }
}

if (!(Test-Path $BakPath)) {
  Write-Error "Backup file not found: $BakFileName under $RootPath"
  exit 1
}

# Sanity checks
$bakInfo = Get-Item $BakPath
if ($bakInfo.Length -le 0) { Write-Error "Backup file is empty: $BakPath"; exit 1 }

# Backup current target if present
if (Test-Path $Target) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $preBackup = Join-Path $RootPath ("restore-preflight-" + $TargetFile + "." + $stamp + ".bak")
  Copy-Item $Target $preBackup -Force
  Write-Host "Backed up current $TargetFile to: $preBackup"
}

# Restore
Copy-Item $BakPath $Target -Force
Write-Host "✅ Restored $TargetFile from: $BakPath"

# Print a direct file URL for your browser
$winPath = (Resolve-Path $Target).Path
$uri = "file:///" + $winPath.Replace('\','/').Replace(' ','%20')
Write-Host "Open this URL in your browser, then hard-refresh (Ctrl+F5):"
Write-Host $uri
