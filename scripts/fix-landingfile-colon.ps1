param(
  [string]$Path = "patch-landing-to-local.ps1"
)

$ErrorActionPreference = "Stop"
if (!(Test-Path $Path)) { Write-Error "File not found: $Path"; exit 1 }

# Read, patch ONLY `$LandingFile:` → `${LandingFile}:`
$text = Get-Content -Path $Path -Raw
$backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $Path $backup -Force

$text = $text -replace '\$LandingFile:', '${LandingFile}:'

$text | Set-Content -Path $Path -Encoding UTF8
Write-Host "✅ Fixed colon-after-variable issue. Backup saved to: $backup"
