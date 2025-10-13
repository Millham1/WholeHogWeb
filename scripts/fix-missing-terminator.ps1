param(
  [string]$Path = "build-landing-and-blind.ps1"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

# Read whole file and split into lines (handles CRLF/LF/CR)
$text  = Get-Content -Path $Path -Raw
$lines = $text -split "`r`n|`n|`r"

# Find the start of the here-string: $blindHtml = @'
$startIdx = $null
for ($i=0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*\$blindHtml\s*=\s*@''\s*$') { $startIdx = $i; break }
}
if ($null -eq $startIdx) {
  Write-Host "No `$blindHtml = @' block found. Nothing to fix."
  exit 0
}

# Check if a closing line '@ already exists after the start
$closeIdx = $null
for ($j=$startIdx+1; $j -lt $lines.Count; $j++) {
  if ($lines[$j] -match "^\s*'@\s*$") { $closeIdx = $j; break }
}

if ($null -ne $closeIdx) {
  Write-Host "Here-string already closed at line $($closeIdx+1). Nothing to do."
  exit 0
}

# Insert the missing "'@" right after the closing </html> that belongs to the block
$insertAt = $lines.Count - 1
for ($k=$lines.Count-1; $k -gt $startIdx; $k--) {
  if ($lines[$k] -match '</html>\s*$') { $insertAt = $k; break }
}

# Backup
$backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item $Path $backup -Force

# Build fixed content
$before = if ($insertAt -ge 0) { $lines[0..$insertAt] } else { @() }
$after  = if ($insertAt -lt ($lines.Count-1)) { $lines[($insertAt+1)..($lines.Count-1)] } else { @() }

$fixed = @()
$fixed += $before
$fixed += "'@"
$fixed += $after

# Write back with CRLF
($fixed -join "`r`n") | Set-Content -Path $Path -Encoding UTF8

Write-Host "✅ Fixed: inserted missing here-string terminator after </html>."
Write-Host "Backup saved to: $backup"

