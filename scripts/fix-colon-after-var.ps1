param(
  [string]$Path = "patch-landing-to-local.ps1"
)

$ErrorActionPreference = "Stop"
if (!(Test-Path $Path)) { Write-Error "File not found: $Path"; exit 1 }

$text = Get-Content -Path $Path -Raw

# Fix occurrences where $LandingFile is directly followed by a colon inside a double-quoted string
# e.g., Write-Host "✅ Patched $LandingFile:"
$text = $text -replace '(".*?\$)LandingFile(:)', '${1}{LandingFile}${2}'

# Backup then write
$backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $Path $backup -Force
$text | Set-Content -Path $Path -Encoding UTF8

Write-Host "✅ Fixed colon-after-variable issue in $Path"
Write-Host "Backup at: $backup"
